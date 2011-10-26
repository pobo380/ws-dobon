# -*- coding: utf-8 -*-
require 'rubygems'
require 'sequel'
require 'sinatra'
require 'haml'
require 'sass'
require 'digest/sha2'
require 'time'
require 'enumerator'
require 'json'
require 'pusher'

$:.unshift(File.expand_path(File.dirname(__FILE__)))
require 'lib/dobon'

###
### Configs
###

def app_root
  "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{env['SCRIPT_NAME']}"
end

use Rack::Session::Cookie,
  :expire_after => 2592000,
  :secret => ENV['SESSION_COOKIE_SECRET'] || 'CHANGE ME!!'

Pusher.app_id = ENV['PUSHER_APP_ID'] || 'CHANGE ME!!'
Pusher.key    = ENV['PUSHER_KEY']    || 'CHANGE ME!!'
Pusher.secret = ENV['PUSHER_SECRET'] || 'CHANGE ME!!'

###
### Models
###

require 'models'


###
### Helpers
###

require 'helpers'


###
### Routes
###

include Models

### APIs

## ログイン状態であるかのフィルタ
before '/*' do
  @player = Player.find(:sessionkey => session[:sessionkey])

  ## sessionkeyが有効でない or 既に部屋が閉じている
  if session[:sessionkey].nil? or @player.nil? or @player.room.is_closed
    @player = nil
    session[:sessionkey] = ''
  else
    @room = @player.room
  end 
end

## 部屋の作成
get '/room/create' do
  player_not_registered
  halt_ng "部屋の名前を入力して下さい。" if params[:name].nil? or params[:name].empty?

  DB.transaction do
    room = Room.create(:name => params[:name], :is_closed => false)
  end

  return_ok "部屋を作成しました"
end

## 部屋への参加
get '/player/join' do
  player_not_registered
  halt_ng "プレイヤーの名前を入力して下さい。" if params[:name].nil? or params[:name].empty?
  halt_ng "部屋を指定して下さい。" unless params[:room_id]

  @room = Room.find(:id => params[:room_id])

  halt_ng "存在しない部屋IDです" if @room.nil?
  halt_ng "部屋が既に閉じています" if @room.is_closed
  game_not_started

  puts "#{@room.players.size}"
  halt_ng "部屋が満員です" if @room.players.size == 4

  player = Player.find(:sessionkey => session[:sessionkey])

  DB.transaction do
    player = Player.create(
      :room_id => params[:room_id],
      :name => params[:name],
      :hand => ""
    )
    PlayerState.find(:label => 'not-ready').add_player(player)
    player.update(:sessionkey => Digest::SHA256.hexdigest(Time.now.to_s + player.id.to_s))

    session[:sessionkey] = player.sessionkey
  end

  #return_ok "#{@room.name}に参加しました。"
  {:room_id => @room.id}.to_json
end

## 部屋からの退出
get '/player/quit' do
  player_registered
  ### 工大祭用 コメントアウト
  #game_not_started

  ### プレイヤーをinactiveに
  DB.transaction do
    PlayerState.find(:label => 'inactive').add_player(@player)
  end
  session[:sessionkey] = ''

  ### プレイヤー数が0であれば部屋を閉じる
  if @room.players.all?{|player| player.player_state.label == 'inactive'}
    DB.transaction do
      @room.update(:is_closed => true)
    end
  end

  return_ok ""
end

## 準備完了
get '/player/ready' do
  player_registered
  game_not_started

  DB.transaction do
    PlayerState.find(:label => 'ready').add_player(@player)
  end

  if @room.players.size > 1 and # 4人以上で
     @room.players.all?{|player| player.player_state.label == 'ready' }

    ## ゲーム開始
    table = nil
    DB.transaction do
      ## ゲームをテーブルに追加
      game = @room.add_game({})

      ## プレイ順の決定
      players = @room.players.sort_by{rand}
      orders = players.map.with_index do |player, idx|
        order = PlayingOrder.create(:order => idx)
        player.add_playing_order(order)
        @room.games.last.add_playing_order(order)
        order
      end

      current_player_id = orders.sort_by{|e|e.order}.first.player.id

      ### ラウンド, テーブルの生成
      table = start_new_round(game, players, current_player_id)
    end

    ## ゲーム開始をpush
    Pusher[@room.id].trigger('deal', deal_response(table).to_json)

    return_ok "all-players-ready"
  else
    return_ok "#{@player.player_state.label}"
  end
end

### 準備未完了
get '/player/not-ready' do
  player_registered
  game_not_started

  DB.transaction do
    PlayerState.find(:label => 'not-ready').add_player(@player)
  end

  return_ok "#{@player.player_state.label}"
end

### Action API フィルタ
before '/player/action/*' do
  player_registered
  game_started

  @game  = @room.games.last
  @round = @game.rounds.last
  @table = @round.tables.first
  @current_player = @table.current_player
  @hand = Playingcard::Deck.new(@player.hand)
end

### カードを場に出す
get '/player/action/play' do
  ## エラーチェック
  your_turn
  not_agari(@table.last_played) unless @table.last_played.nil?
  phase_not_wait_to_dobon

  halt_ng 'カードを指定して下さい。' unless params[:card]

  card = Playingcard::Card.new(params[:card])
  halt_ng '不正なカードの値です。' unless card.valid?
  unless @hand.include?(card)
    halt_ng '指定されたカードが手札にありません。'
  end
  @hand.delete(card)

  table = table_model_to_logic(@table)
  res = table.put(card, params[:specify])
  if res.nil?
    halt_ng 'このカードは場に出すことが出来ません。'
  end

  DB.transaction do
    @player.update(:hand => @hand.to_s)
    @table.update(
      :deck => table.deck.to_s,
      :discards => table.discards.to_s,
      :specify => table.specify,
      :restriction => table.restriction,
      :reverse => table.reverse,
      :passed => table.passed,
      :attack => table.attack.to_s,
      :current_player_id => next_player(res ? 2 : 1).id,
      :last_played_id => @player.id,
      :last_played_time => Time.now.to_s
    )
    #RoundState.find(:label => 'wait-to-dobon')
    # .add_round(@round)
  end

  ## カード出した
  Pusher[@room.id].trigger('play', deal_response(@table).to_json)

  return_ok ''
end

### パスする
get '/player/action/pass' do
  your_turn
  not_agari(@table.last_played) unless @table.last_played.nil?
  phase_not_wait_to_dobon

  table = table_model_to_logic(@table)

  draw, next_turn = table.pass
  draw.times{ @hand.push(table.draw) }

  DB.transaction do
    @player.update(:hand => @hand.to_s)
    @table.update(
      :deck => table.deck.to_s,
      :discards => table.discards.to_s,
      :specify => table.specify,
      :restriction => table.restriction,
      :reverse => table.reverse,
      :passed => table.passed,
      :attack => table.attack.to_s,
      :last_played_time => Time.now.to_s
    )
    if next_turn
      @table.update(:current_player_id =>
                      next_player(1).id)
    end
  end

  ## パスした
  Pusher[@room.id].trigger('pass', deal_response(@table).to_json)

  return_ok ''
end

### ドボンする
get '/player/action/dobon' do
  not_passed
  halt_ng '自分の出したカードに対してドボンは出来ません。' if @player.id == @table.last_played.id

  table = table_model_to_logic(@table)
  res = table.dobon(@hand)
  winner_label = ''
  loser_label  = ''
  point = Playingcard::Deck.new(@table.last_played.hand).sum
  winner_id = ''
  loser_id  = ''

  case res
  when 'dobon'
    rate         =  1
    winner_label = 'dobon'
    loser_label  = 'make'
    winner_id    = @player.id
    loser_id     = @table.last_played.id
  when 'joker'
    rate         =  14
    winner_label = 'dobon'
    loser_label  = 'make'
    winner_id    = @player.id
    loser_id     = @table.last_played.id
  when 'miss-dobon'
    ## 工大祭用:ミスドボンは認めないことに！！
    halt_ng "手札の合計と等しくありません"
    rate = 1
    winner_label = 'make'
    loser_label  = 'miss-dobon'
    winner_id    = @table.last_played.id
    loser_id     = @player.id
  end

  table = nil
  DB.transaction do
    ### 勝ちプレイヤー
    r = RoundResult.create(:round_id  => @round.id,
                       :player_id => winner_id,
                       :point => point * rate)
    FinishType.find(:label => winner_label).add_round_result(r)

    ### 負けプレイヤー
    rr = RoundResult.create(:round_id  => @round.id,
                       :player_id => loser_id,
                       :point => point * rate * -1)
    FinishType.find(:label => loser_label).add_round_result(rr)

    Round.update(:winner_id => winner_id, :loser_id => loser_id)

    ### ラウンド, テーブルの生成
    table = start_new_round(@game, @room.players, loser_id)
  end

  Pusher[@room.id].trigger('dobon',{ 
    :table => deal_response(table),
    :winner_id => winner_id,
    :loser_id => loser_id
  }.to_json)

  return_ok ''
end

### 上がり
get '/player/action/agari' do
  halt_ng '上がり状態ではありません。' if @table.last_played.nil? or not agari?(@table.last_played)
  halt_ng 'ドボン待ち時間です。' if Time.now - @table.last_played_time <= 5

  ### 点数計算
  points = @room.players.map{ |player|
    if player.id != @table.last_played.id
      [
        player,
        (Playingcard::Deck.new(player.hand).sum / 2.0).ceil
      ]
    end
  }.compact

  ### 上がり処理
  table = nil
  loser_id = nil
  DB.transaction do
    points.each do |player, point|
      rr = RoundResult.create(:round_id  => @round.id,
                              :player_id => player.id,
                              :point => -1 * point)
      FinishType.find(:label => 'make').add_round_result(rr)
    end
    
    r = RoundResult.create(:round_id  => @round.id,
                       :player_id => @table.last_played.id,
                       :point => points.map{|player, point| point}.inject(0){|sum, point| sum += point})
    FinishType.find(:label => 'agari').add_round_result(r)

    loser_id = points.sort_by{|player, point| point}.last[0].id
    Round.update(:winner_id => @table.last_played.id, :loser_id => loser_id)

    table = start_new_round(@game, @room.players, loser_id)
  end

  Pusher[@room.id].trigger('agari',{ 
    :table => deal_response(table),
    :winner_id => @table.last_played.id,
    :loser_id => loser_id
  }.to_json)

  return_ok ''
end

### プレイデータ取得用API
get '/player/self' do
  player_response().to_json
end

get '/player/action/hand' do
  Playingcard::Deck.new(@player.hand).to_a.map{|c|
    "#{c.to_s}"
  }.to_s ## !TODO to_json
end

### Views

## index.haml
get '/' do
  @rooms = Room.filter(:is_closed => false).reject{|room|
    not room.games.nil? and not room.games.empty?
  }
  haml :index
end

## stylesheets
get '/styles/*.css' do |filename|
  content_type 'text/css', :charset => 'utf-8'
  sass filename.to_sym
end


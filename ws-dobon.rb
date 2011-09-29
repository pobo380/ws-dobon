# -*- coding: utf-8 -*-
require 'rubygems'
require 'sequel'
require 'sinatra'
require 'digest/sha2'
require 'time'
require 'enumerator'

$:.unshift(File.expand_path(File.dirname(__FILE__)))
require 'lib/dobon'

### Configs

use Rack::Session::Cookie,
  :expire_after => 2592000,
  :secret => ENV['SESSION_COOKIE_SECRET'] || 'CHANGE ME!!'

### Models
module Models

  ## Connect to the database.
  Sequel::Model.plugin(:schema)
  DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://db/database.sqlite3')

  ## Helper module
  module AutoTimestamp
    def before_create
      self.created_at ||= Time.now
      super
    end
  end

  class Room < Sequel::Model
    one_to_many :players
    one_to_many :games

    include AutoTimestamp
  end

  class Game < Sequel::Model
    one_to_many :rounds
    one_to_many :game_results
    one_to_many :playing_orders

    many_to_one :room

    include AutoTimestamp
  end

  class GameResult < Sequel::Model
    many_to_one :game
    many_to_one :player

    include AutoTimestamp
  end

  class Round < Sequel::Model
    one_to_many :round_results

    many_to_one :game
    many_to_one :winner, :class => :Player
    many_to_one :loser,  :class => :Player
    many_to_one :round_state

    one_to_many :tables

    include AutoTimestamp
  end

  class Table < Sequel::Model
    many_to_one :round
    many_to_one :current_player, :class => :Player
    one_to_many :last_played, :class => :Player

    include AutoTimestamp
  end

  class RoundResult < Sequel::Model
    many_to_one :round
    many_to_one :player
    many_to_one :finish_types

    include AutoTimestamp
  end

  class Player < Sequel::Model
    one_to_many :round_results
    one_to_many :winner_rounds, :class => :Round, :key => :winner_id
    one_to_many :loser_rounds,  :class => :Round, :key => :loser_id
    one_to_many :current_player_tables, :class => :Table, :key => :current_player_id
    one_to_many :last_played_tables, :class => :Table, :key => :last_played_id
    one_to_many :game_results
    one_to_many :playing_orders

    many_to_one :room
    many_to_one :player_state

    include AutoTimestamp
  end

  class FinishType < Sequel::Model
    one_to_many :round_results

    include AutoTimestamp
  end

  class PlayerState < Sequel::Model
    one_to_many :players

    include AutoTimestamp
  end

  class RoundState < Sequel::Model
    one_to_many :rounds
    
    include AutoTimestamp
  end

  class PlayingOrder < Sequel::Model
    many_to_one :player
    many_to_one :game

    include AutoTimestamp
  end
end

### Helpers
helpers do
  def halt_ng(message)
    halt ['NG', message].to_s
  end

  def return_ok(message)
    ['OK', message].to_s
  end

  def table_model_to_logic(table)
      Dobon::Table.new(
        Playingcard::Deck.new(table.deck),
        Playingcard::Deck.new(table.discards),
        table.restriction,
        table.reverse,
        table.passed,
        table.specify,
        table.attack
      )
  end

  ### 各種制約条件
  
  def phase_wait_to_dobon
    last_played_time = @table.last_played_time
    if not @table.passed and not last_played_time.nil? and Time.now - last_played_time <= 2.0
      halt_ng "ドボン待ち時間です。"
    end
  end

  def your_turn
    if @current_player.id != @player.id or
       @round.round_state.label != 'wait-to-play'
      halt_ng "貴方の手番ではありません。"
    end
  end

  def player_registered
    halt_ng "プレイヤー登録が行われていません。" if @player.nil?
  end

  def player_not_registered
    halt_ng "既にプレイヤー登録している部屋があります。" unless @player.nil?
  end

  def game_started
    halt_ng "ゲームが開始されていません。" unless game_started?
  end

  def game_not_started
    halt_ng "既にゲームが開始しています。" if game_started?
  end

  def not_passed
    halt_ng "前回のプレイヤーがパスをしています。" if @table.passed
  end

  ### ゲームが開始されているかどうか。
  def game_started?
    return (not @room.games.empty? and @room.games.last.game_results.empty?)
  end

  ### 次のプレイヤーを取得
  def next_player(times = 1)
    orders = @game.playing_orders_dataset.order(:order)
    current_idx = orders[:player_id => @table.current_player.id].order
    @table.reverse ? idc = @room.players.size - times : idc = times
    next_idx = (current_idx + idc) % @room.players.size
    orders[:order => next_idx].player
  end
end

### Routes
include Models

## APIs

get '/room/create' do
  halt '["NG", "部屋の名前を入力して下さい。"]' unless params[:name]

  DB.transaction do
    room = Room.create(:name => params[:name], :is_closed => false)
  end

  return_ok "部屋を作成しました"
end

## ログイン状態であるかのフィルタ
before '/player/*' do
  @player = Player.find(:sessionkey => session[:sessionkey])

  ## sessionkeyが有効でない or 既に部屋が閉じている
  if session[:sessionkey].nil? or @player.nil? or @player.room.is_closed
    @player = nil
    session[:sessionkey] = ''
  else
    @room = @player.room
  end 

end

## 部屋への参加
get '/player/join' do
  player_not_registered
  halt_ng "プレイヤーの名前を入力して下さい。" unless params[:name]
  halt_ng "部屋を指定して下さい。" unless params[:room_id]

  @room = Room.find(:id => params[:room_id])

  halt_ng "存在しない部屋IDです" if @room.nil?
  halt_ng "部屋が既に閉じています" if @room.is_closed
  game_not_started

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

  return_ok ""
end

## 部屋からの退出
get '/player/quit' do
  player_registered
  game_not_started

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

  if @room.players.size > 0 and # N人以上で
     @room.players.all?{|player| player.player_state.label == 'ready' }

    ## ゲーム開始
    DB.transaction do
      ## ゲームをテーブルに追加
      game  = @room.add_game({})

      ## テーブルの生成
      table = Dobon::Table.new(Playingcard::Deck.new_1set)
      skip = table.reset

      ## プレイ順の決定
      players = @room.players.sort_by{rand}
      orders = players.map.with_index do |player, idx|
        order = PlayingOrder.create(:order => idx)
        player.add_playing_order(order)
        @room.games.last.add_playing_order(order)
        order
      end

      ## 手札を配る
      players.map do |player|
        hand = Playingcard::Deck.new(Array.new(5){ table.draw.to_s }).to_s
        player.update(:hand => hand)
      end

      ## ラウンドをテーブルに追加
      round = game.add_round({})
      table = round.add_table(
        :deck => table.deck.to_s,
        :discards => table.discards.to_s,
        :specify => table.specify,
        :restriction => table.restriction,
        :reverse => table.reverse,
        :passed => true,
        :attack => table.attack.to_s,
        :current_player_id => orders.sort_by{|e|e.order}.first.player.id
      )
      RoundState.find(:label => 'wait-to-play').add_round(round)
      table.update(:current_player_id => next_player.id) if skip
    end

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
  phase_wait_to_dobon

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
    halt_ng 'プレイすることのできないカードであるか、スートが指定されていません。'
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

  return_ok ''
end

### パスする
get '/player/action/pass' do
  your_turn
  phase_wait_to_dobon

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

    #RoundState.find(:label => 'wait-to-dobon')
    # .add_round(@round)
  end

  return_ok ''
end

### ドボンする
get '/player/action/dobon' do
  not_passed
end

## Views
get '/' do
  r = Room.filter(:is_closed => false).map{|e| e.name }
  r.join("\n")
end

get '/test' do
end


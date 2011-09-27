# -*- coding: utf-8 -*-
require 'rubygems'
require 'sequel'
require 'sinatra'
require 'digest/sha2'
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
  def response_code(message)
  end

  def table_model_to_logic(table)
      Dobon::Table.new(
        Playingcard::Deck.new(table.deck),
        Playingcard::Deck.new(table.discards),
        table.restriction,
        table.specify,
        table.attack
      )
  end

  def game_started?(room)
    return (not room.games.empty? and room.games.last.game_results.empty?)
  end
end

### Routes
include Models

## APIs

get '/room/create' do
  return '["NG", "部屋の名前を入力して下さい。"]' unless params[:name]

  DB.transaction do
    room = Room.create(:name => params[:name], :is_closed => false)
  end

  '["OK", "部屋を作成しました"]'
end

## ログイン状態であるかのフィルタ
before '/player/*' do
  @player = Player.find(:sessionkey => session[:sessionkey])

  ## sessionkeyが有効でない or 既に部屋が閉じている
  if session[:sessionkey].nil? or @player.nil? or @player.room.is_closed
    @player = nil
    session[:sessionkey] = ''
  end 
end

## 部屋への参加
get '/player/join' do
  return '["NG", "既にプレイヤー登録している部屋があります。"]' unless @player.nil?
  return '["NG", "プレイヤーの名前を入力して下さい。"]' unless params[:name]
  return '["NG", "部屋を指定して下さい。"]' unless params[:room_id]

  room = Room.find(:id => params[:room_id])

  return '["NG", "存在しない部屋IDです"]' if room.nil?
  return '["NG", "部屋が既に閉じています"]' if room.is_closed
  return '["NG", "既にゲームが開始しています。"]' if game_started?(room)

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

  '["OK"]'
end

## 部屋からの退出
get '/player/quit' do
  return '["NG", "ゲーム中は退出出来ません。"]' if game_started?(@player.room)

  ### プレイヤーをinactiveに
  DB.transaction do
    PlayerState.find(:label => 'inactive').add_player(@player)
  end
  session[:sessionkey] = ''

  ### プレイヤー数が0であれば部屋を閉じる
  if @player.room.players.all?{|player| player.player_state.label == 'inactive'}
    DB.transaction do
      @player.room.update(:is_closed => true)
    end
  end
end

## 準備完了
get '/player/ready' do
  return '["NG", "プレイヤー登録を行なって下さい。"]' if @player.nil?
  return '["NG", "既にゲームが開始しています。"]' if game_started?(@player.room)

  DB.transaction do
    PlayerState.find(:label => 'ready').add_player(@player)
  end

  if @player.room.players.size > 0 and # N人以上で
     @player.room.players.all?{|player| player.player_state.label == 'ready' }

    ## ゲーム開始
    DB.transaction do
      ## ゲームをテーブルに追加
      game  = @player.room.add_game({})

      ## テーブルの生成
      table = Dobon::Table.new(Playingcard::Deck.new_1set)
      table.reset

      ## プレイ順の決定
      players = @player.room.players.sort_by{rand}
      orders = players.map.with_index do |player, idx|
        order = PlayingOrder.create(:order => idx)
        player.add_playing_order(order)
        player.room.games.last.add_playing_order(order)
        order
      end

      ## 手札を配る
      players.map do |player|
        hand = Playingcard::Deck.new(Array.new(5){ table.draw.to_s }).to_s
        player.update(:hand => hand)
      end

      ## ラウンドをテーブルに追加
      round = game.add_round({})
      round.add_table(
        :deck => table.deck.to_s,
        :discards => table.discards.to_s,
        :specify => table.specify,
        :reverse => table.reverse,
        :restriction => table.restriction,
        :attack => table.attack.to_s,
        :current_player_id => orders.sort_by{|e|e.order}.first.player.id
      )
      RoundState.find(:label => 'wait-to-play').add_round(round)
    end

    "[OK, #{@player.room.games.empty?}, all-players-ready]"
  else
    "[OK, #{@player.player_state.label}]"
  end
end

### 準備未完了
get '/player/not-ready' do
  return '["NG", "プレイヤー登録を行なって下さい。"]' if @player.nil?
  return '["NG", "既にゲームが開始しています。"]' if game_started?(@player.room)

  DB.transaction do
    PlayerState.find(:label => 'not-ready').add_player(@player)
  end

  "[OK, #{@player.player_state.label}]"
end

### Action API エラーチェックフィルタ
before '/player/action/*' do
  halt '["NG", "ゲームが開始されていません。"]' unless game_started?(@player.room)
  current_player = @player.room.games.last.rounds.last.tables.first.current_player
  unless current_player.id == @player.id
    halt '["NG", "貴方の手番ではありません。"]'
  end
end

### カードを場に出す
get '/player/action/play' do
  '["OK"]'
end

### パスする
get '/player/action/pass' do
  '["OK"]'
end

### ドボンする
get '/player/action/dobon' do
  '["OK"]'
end

## Views
get '/' do
  r = Room.filter(:is_closed => false).map{|e| e.name }
  r.join("\n")
end

get '/test' do
  session[:sessionkey]
end


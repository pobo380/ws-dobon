# -*- coding: utf-8 -*-
require 'rubygems'
require 'sequel'
require 'sinatra'
require 'digest/sha2'

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
    many_to_one :current_player,
                         :class => :Player
    many_to_one :round_state

    one_to_many :tables

    include AutoTimestamp
  end

  class Table < Sequel::Model
    many_to_one :round

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
    one_to_many :current_player_rounds,
                                :class => :Round,
                                :key => :current_player_id
    one_to_many :game_results

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

get '/room/quit' do
  ## ゲーム中でないか
  #
  ## プレイヤーの退出処理
  #
  ## 人数が0であれば部屋を閉じる
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

get '/player/ready' do
  return '["NG", "プレイヤー登録を行なって下さい。"]' if @player.nil?

  DB.transaction do
    PlayerState.find(:label => 'ready').add_player(@player)
  end

  if @player.room.players.size > 0 and # N人以上で
     @player.room.players.all?{|player| player.player_state.label == 'ready' } and
     (@player.room.games.empty? or not @player.room.games.last.game_results.empty?)

    ## ゲーム開始
    DB.transaction do
      game  = @player.room.add_game({})
      round = game.add_round({})
      table = round.add_table(
        :deck => Playingcard::Deck.new_1set.to_s,
        :discards => "",
        :specify => "",
        :reverse => false,
        :restriction => false,
        :attack => "0"
      )
    end

    "[OK, #{@player.room.games.empty?}, all-players-ready]"
  else
    "[OK, #{@player.player_state.label}]"
  end
end

get '/player/not-ready' do
  return '["NG", "プレイヤー登録を行なって下さい。"]' if @player.nil?

  DB.transaction do
    PlayerState.find(:label => 'not-ready').add_player(@player)
  end

  "[OK, #{@player.player_state.label}]"
end

get '/player/play' do
  'OK'
end

get '/player/dobon' do
  'OK'
end

get '/player/test' do
  "#{@player.is_ready}"
end

## Views
get '/' do
  r = Room.filter(:is_closed => false).map{|e| e.name }
  r.join("\n")
end

get '/test' do
  session[:sessionkey]
end


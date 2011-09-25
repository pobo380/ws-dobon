# -*- coding: utf-8 -*-
require 'rubygems'
require 'sequel'
require 'sinatra'

### Configs

use Rack::Session::Cookie,
  :expire_after => 2592000,
  :secret => 'change_me'

### Models
module Models

  ## Connect to the database.
  Sequel::Model.plugin(:schema)
  Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://db/database.sqlite3')

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
    one_to_many :game_results

    many_to_one :room

    include AutoTimestamp
  end

  class FinishType < Sequel::Model
    one_to_many :round_results

    include AutoTimestamp
  end
end

### Routes

## APIs

get 'room/create' do
  #room = Models::Room.create(
  #  :name => params[:name],
  #  :is_closed => false
  #)

  'OK'
end

get '/room/join' do
  'OK'
end

get '/room/quit' do
  'OK'
end

get '/player/ready' do
  'OK'
end

get '/player/play' do
  'OK'
end

get '/player/dobon' do
  'OK'
end

## Views
get '/' do
  #r = Models::Room.filter(:is_closed => false).map{|e| e.name }
  #r.join('<br>')
  'top'
end

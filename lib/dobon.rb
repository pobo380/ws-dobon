# -*- coding: utf-8 -*-
require 'lib/playingcard'

module Dobon
  class Game
    def run
      # set cmdset
      @players.each { |player| player.cmdset = @cmdset_game }

      # send order
      @players.shuffle_order
      order_ary = @players.collect{|player| player.id}
      @players.each do |player|
        player.send_order(order_ary)
      end
      
      # start round
      @rule['rounds'].times do |current_round|

        # deal
        @table.reset
        @players.each do |player|
          @rule['start_hand'].times{ player.draw(@table) }
          player.send_deal(current_round, @players.current.id, @table.top.to_s)
        end
        @players.current.send_turn(@table.top, @table.specify)

        # start game
        while true # to do
          @players.each do |player|
            if cmd = player.cmd_pop then
              case cmd.command
              # play cmd
              when 'play'
                if @players.current?(player) then
                  if player.play(@table, cmd.card, cmd.specify) then
                    if cmd.card.number == 13 then
                      @players.reverse
                    end
                    if cmd.card.number == 1 then
                      @players.next(true)
                      @players.next(false)
                    else
                      @players.next(true)
                    end
                    @players.each { |one| one.send_play(player.id, cmd.card) }
                    @players.current.send_turn(@table.top, @table.specify)
                  end
                else
                  player.send_error("others turn")
                end
              # pass cmd
              when 'pass'
                if player.pass(@table) then
                  @players.next(false)
                end
                @players.each { |one| one.send_pass(player.id) }
                @players.current.send_turn(@table.top, @table.specify)
              # dobon cmd
              when 'dobon'
                # to do
              end
            end
          end
          sleep(0.01)
        end
        # end game
      end
      # end round
    end

    # utility
    def get_ready?
      (@players.all? { |player| player.ready } && @players.size >= @rule['min_player'])
    end
  end
  
  class PlayerList
    include Enumerable
    def initialize
      @players = []
      @current = 0
      @last    = nil
      @reverse = false
    end

    def reverse
      @reverse ? @reverse = false : @reverse = true
    end

    def others(player)
      @players.select{ |plr| plr != player}
    end

    def last_played
      @last ? @players[@last] : nil
    end

    def current
      @players[@current]
    end

    def current?(player)
      (@players[@current] == player)
    end

    def next(played)
      @last = @current if played
      @reverse ? idc = 1 : idc = @players.size - 1
      @current = (@current+idc) % @players.size
    end

    def shuffle_order
      @players = @players.sort_by{rand}
      @current = 0
    end

    def remove_player
      @players.reject! { |player| player.quit } # remove player # to do
    end

    def push(player)
      @players.push(player)
    end

    def clear
      @players.clear
    end

    def each(&block)
      @players.each(&block)
    end

    def size
      @players.size
    end
  end

  class Table
    def initialize(deck, discards,
                   restriction = false,
                   specify = nil,
                   attack = 0)
      @deck = deck
      @discards = discards
      @restriction = restriction
      @specify = specify
      @attack = attack
    end
    attr_reader :attack, :specify, :restriction

    def top
      @discards.last
    end

    def draw
      if card = @deck.pop then
        card
      else
        reset
        @deck.pop
      end
    end

    def put(card, specify=nil)
      return nil if ( ! card.joker? && self.top.joker? && @restriction )
      p 'ok joker?' # debug print
      return nil if (   card.number != self.top.number && @restriction )
      p 'ok restrection' # debug print
      return nil if (   card.suit != @specify ) if ( @specify )
      p 'ok specify' # debug print
      return nil if ( ( card.number == 11 || card.number == 14 ) && ! specify )
      p 'ok specify arg check' # debug print

      if card.number == self.top.number || card.suit == self.top.suit || card.joker? || self.top.joker? || card.number == 11 || @specify then
        @discards.push(card)
        self.ruling(specify)
        true
      else
        nil
      end
    end

    def ruling(specify=nil)
      @specify = nil
      case self.top.number
      when 2
        @attack = @attack + 2
        @restriction = true
      when 8
        @attack = @attack + 1
        @restriction = true
      when 11
        @attack = 0
        @restriction = false
        @specify = specify
      when 14
        @attack = @attack + 4
        @restriction = true
        @specify = specify
      end
      # debug print
      p ['attack', @attack].join(' ')
      p ['restriction', @restriction].join(' ')
      p ['specify', @specify].join(' ')
    end

    def pass
      @attack == 0 ? attack = 1 : attack = @attack
      @restriction && self.top.number == 8 ? next_turn = false : next_turn = true

      @attack = 0
      @restriction = false

      [attack, next_turn]
    end

    def reset
      @deck.shuffle
      @deck.concat(@discards)
      @discards.clear
      @discards.push(@deck.pop)
      self.ruling
      @deck.shuffle
    end
  end

end

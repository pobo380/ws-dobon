# -*- coding: utf-8 -*-
require 'lib/playingcard'

module Dobon
  class Table
    def initialize(deck,
                   discards = Playingcard::Deck.new,
                   restriction = false,
                   reverse = false,
                   passed = true,
                   specify = nil,
                   attack = 0)
      @deck = deck
      @discards = discards
      @reverse = reverse
      @passed = passed
      @restriction = restriction
      @specify = specify
      @attack = attack
    end
    attr_reader :deck, :discards, :attack, :specify
    attr_reader :restriction, :reverse, :passed

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

    def dobon(hand)
      if self.top.joker? and hand.size == 1 and hand[0].joker?
        'joker'
      elsif self.top.number == hand.sum and not self.top.number == 8
        'dobon'
      else
        'miss-dobon'
      end
    end

    def put(card, specify=nil)
      return nil if ( ! card.joker? && self.top.joker? && @restriction )
      p 'ok joker?' # debug print
      return nil if (   card.number != self.top.number && @restriction )
      p 'ok restrection' # debug print
      return nil if ((not(card.number == 11 || card.number == 14)) and card.suit != @specify ) if ( @specify )
      p 'ok specify' # debug print
      return nil if ( ( card.number == 11 || card.number == 14 ) && ! specify )
      p 'ok specify arg check' # debug print

      if card.number == self.top.number ||
         card.suit == self.top.suit ||
         card.joker? || card.number == 11 ||
         self.top.joker? || self.top.number == 11 ||
         @specify then
        @discards.push(card)
        @passed = false
        self.ruling(specify)
      else
        nil
      end
    end

    def ruling(specify=nil)
      skip = false
      @specify = nil
      case self.top.number
      when 1
        skip = true
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
      when 13
        @reverse = !@reverse
      when 14
        @attack = @attack + 4
        @restriction = true
        @specify = specify
      end
      # debug print
      p ['attack:', @attack].join(' ')
      p ['restriction:', @restriction].join(' ')
      p ['specify:', @specify].join(' ')

      skip
    end

    def pass
      @attack == 0 ? attack = 1 : attack = @attack
      @restriction && self.top.number == 8 ? next_turn = false : next_turn = true

      @attack = 0
      @restriction = false
      @passed = true

      [attack, next_turn]
    end

    def reset
      @deck.shuffle
      @deck.concat(@discards)
      @discards.clear
      @discards.push(@deck.pop)
      skip = self.ruling
      @deck.shuffle
      skip
    end
  end
end

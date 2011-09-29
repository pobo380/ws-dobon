module Playingcard
  class Card
    def initialize(card)
      @card = card.to_s[0,2] if card.size > 1
    end

    def number
      case @card[1,1]
      when 'A'
        1
      when '2'
        2
      when '3'
        3
      when '4'
        4
      when '5'
        5
      when '6'
        6
      when '7'
        7
      when '8'
        8
      when '9'
        9
      when '0'
        10
      when 'J'
        11
      when 'Q'
        12
      when 'K'
        13
      when 'F'
        14
      else
        nil
      end
    end

    def suit
      case @card[0,1]
      when 'S'
        'S'
      when 'C'
        'C'
      when 'D'
        'D'
      when 'H'
        'H'
      when 'F'
        'F'
      else
        nil
      end
    end

    def joker?
      @card == 'FF'
    end

    def valid?
      (number && suit)
    end

    def to_a
      [self]
    end

    def to_s
      @card.to_s
    end

    def ==(other)
      self.to_s == other.to_s
    end
  end

  class Deck
    include Enumerable
    def initialize(str_or_array=nil)
      @cards = []
      if str_or_array.kind_of?(String) then
        str = str_or_array
        (str.size/2).times do |i|
          @cards.push(Card.new(str[i*2, 2]))
        end
      else
        @cards = str_or_array.to_a.collect { |elem| Card.new(elem) } # modified 18:53 03/10
      end
    end

    def [](idx)
      @cards[idx]
    end

    def []=(idx, v)
      @cards[idx] = v
    end

    def dup
      self.class.new(@cards)
    end

    def clear
      @cards.clear
    end

    def each(&block)
      @cards.each(&block)
    end

    def size
      @cards.size
    end

    def to_a
      @cards.dup
    end

    def to_s
      @cards.join
    end

    def first
      @cards.first
    end

    def last
      @cards.last
    end

    def concat(other)
      @cards.concat(other.to_a)
    end

    def push(card)
      @cards.push(card)
    end

    def pop
      @cards.pop
    end

    def shift
      @cards.shift
    end

    def delete(card)
      @cards.delete(card)
    end

    def delete_at(idx)
      @cards.delete_at(idx)
    end

    def empty?
      @cards.empty?
    end

    def include?(card)
      @cards.include?(card)
    end

    def shuffle
      @cards = @cards.sort_by{rand}
    end

    def sum
      @cards.inject(0){|sum, card|
        sum += card.number
      }
    end

    # class method
    def self.new_1set
      Deck.new([
               'CA', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9', 'C0', 'CJ', 'CQ', 'CK',
               'HA', 'H2', 'H3', 'H4', 'H5', 'H6', 'H7', 'H8', 'H9', 'H0', 'HJ', 'HQ', 'HK',
               'DA', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7', 'D8', 'D9', 'D0', 'DJ', 'DQ', 'DK',
               'SA', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S0', 'SJ', 'SQ', 'SK',
               'FF', 'FF'
      ].join)
    end
  end
end

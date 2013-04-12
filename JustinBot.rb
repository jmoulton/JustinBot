require 'thrift'
$:.unshift File.dirname(__FILE__) + '/lib'
require 'hearts'

socket = Thrift::Socket.new('127.0.0.1', 4001)
transport = Thrift::FramedTransport.new(socket)
protocol = Thrift::BinaryProtocol.new(transport)
client = AgentVsAgent::Hearts::Client.new(protocol)


class JustinBot

  @@shoot_the_moon = false
  @@hearts_been_broken = false

  def self.shoot_the_moon
    @@shoot_the_moon
  end

  def self.hearts_been_broken
    @@hearts_been_broken
  end

  def initialize game
    @game = game
  end

  def run
    request = AgentVsAgent::EntryRequest.new
    puts "Entering arena #{request.inspect}"
    response = @game.enter_arena request
    @ticket = response.ticket
    if @ticket
      puts "Got a ticket! #{@ticket.inspect}"
      play
    end
  end

  def play
    puts "playing"
    @game_info = @game.get_game_info @ticket
    puts "game info: #{@game_info.inspect}"

    loop.with_index(1) do |_, round_number|
      @round_number = round_number
      play_round

      round_result = @game.get_round_result @ticket
      puts "round result: #{round_result.inspect}"
      break if round_result.status != AgentVsAgent::GameStatus::NEXT_ROUND
    end

    game_result = @game.get_game_result @ticket
    puts "game_result: #{game_result.inspect}"
  end

  def play_round
    @hand = @game.get_hand @ticket
    puts "hand: #{@hand.inspect}"
    @@hearts_been_broken = false

    if @round_number % 4 != 0
      cards_to_pass = pass_cards
      puts "[#{@game_info.position}] passing cards #{cards_to_pass}"
      received_cards = @game.pass_cards @ticket, cards_to_pass
      puts "received cards: #{received_cards.inspect}"
      @hand = @hand + received_cards
    end

    13.times do |trick_number|
      @trick_number = trick_number
      play_trick
    end
  end

  def pass_cards
     cards_to_pass = []
     for i in 0..2 do
       cards_to_pass << highest_card
       @hand.delete(highest_card)
     end

     return cards_to_pass
  end

  def highest_club
     clubs = @hand.select { |card| card.suit == AgentVsAgent::Suit::CLUBS }
     return clubs.max
  end

  def highest_heart
    hearts = @hand.select { |card| card.suit == AgentVsAgent::Suit::HEARTS }
    return hearts.max
  end

  def highest_card
    ranks = []
    @hand.each { |card| ranks << card.rank }
    return @hand.detect{|card| card.rank == ranks.max }
  end

  def lowest_card
    ranks = []
    @hand.each { |card| ranks << card.rank }
    return @hand.detect{|card| card.rank == ranks.min }
  end

  def has_hearts?
     hearts = @hand.select { |card| card.suit == AgentVsAgent::Suit::HEARTS }
     return !hearts.empty?
  end

  def has_diamonds?
     diamonds = @hand.select { |card| card.suit == AgentVsAgent::Suit::DIAMONDS }
     return !diamonds.empty?
  end

  def has_spades?
     spades = @hand.select { |card| card.suit == AgentVsAgent::Suit::SPADES }
     return !spades.empty?
  end

  def has_clubs?
     clubs = @hand.select { |card| card.suit == AgentVsAgent::Suit::CLUBS }
     return !clubs.empty?
  end

  def have_the_queen?
    queen = @hand.detect{|card| card.suit == AgentVsAgent::Suit::SPADES && card.rank == AgentVsAgent::Rank::QUEEN }
    return !queen.nil?
  end

  def drop_queen
    return @hand.detect{|card| card.suit == AgentVsAgent::Suit::SPADES && card.rank == AgentVsAgent::Rank::QUEEN }
  end

  def play_matching_suit(suit)
    suitable_cards = @hand.select{|card| card.suit == suit }
    return suitable_cards.first
  end

  def play_trick
    puts "[#{@game_info.position}, round #{@round_number}, trick #{@trick_number}, playing trick"
    puts "#{@hand.inspect}"

    trick = @game.get_trick @ticket
    puts "Leading the trick #{@game_info.inspect}, #{trick.inspect}" if @game_info.position == trick.leader
    puts "current trick: #{trick.inspect}"

    unless JustinBot.shoot_the_moon
      if @trick_number == 0 && two_clubs = @hand.detect{|card| card.suit == AgentVsAgent::Suit::CLUBS && card.rank == AgentVsAgent::Rank::TWO }
        puts "playing two of clubs"
        card_to_play = two_clubs
      elsif @trick_number == 0 && has_clubs?
        puts "playing highest club"
        card_to_play = highest_club
      elsif trick.played[0] && @hand.detect{|card| card.suit == trick.played[0].suit}
        puts "playing matching suit"
        card_to_play = play_matching_suit(trick.played[0].suit)
      else
        if have_the_queen? && !trick.played[0].nil?
          puts "playing queen of spades"
          card_to_play = drop_queen
        elsif has_hearts? && !trick.played[0].nil?
          puts "playing highest heart"
          card_to_play = highest_heart
        elsif !trick.played[0].nil?
          puts "playing highest card"
          card_to_play = highest_card
        else
          puts "playing lowest card"
          card_to_play = lowest_card
        end
      end
    else
      puts "shooting the moon"
    end

    @hand.delete(card_to_play)
    puts "[#{@game_info.position}] playing card: #{card_to_play.inspect}"
    trick_result = @game.play_card @ticket, card_to_play
    unless @@hearts_been_broken
      trick_result.played.each { |card| @@hearts_been_broken = true if card.suit == AgentVsAgent::Suit::HEARTS }
    end
    puts "trick result: #{trick_result.inspect}"
  end
end


puts "Opening connection"
transport.open
bot = JustinBot.new(client)
bot.run
transport.close

puts "Finished"


require 'thrift'
$:.unshift File.dirname(__FILE__) + '/lib'
require 'hearts'

socket = Thrift::Socket.new('127.0.0.1', 4001)
transport = Thrift::FramedTransport.new(socket)
protocol = Thrift::BinaryProtocol.new(transport)
client = AgentVsAgent::Hearts::Client.new(protocol)


class JustinBot

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
    @hearts_been_broken = false
    puts "hand: #{@hand.inspect}"

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

  def break_hearts
    puts "************************"
    puts "****BREAKING HEARTS*****"
    puts "************************"
    @hearts_been_broken = true
  end

  def pass_cards
    cards_to_pass = []

    while cards_to_pass.count < 3
      card = determine_cards_to_pass
      cards_to_pass << card
      @hand.delete(card)
    end

    return cards_to_pass
  end

  def determine_cards_to_pass
    #clubs = @hand.select { |card| card.suit == AgentVsAgent::Suit::CLUBS }
    #hearts = @hand.select { |card| card.suit == AgentVsAgent::Suit::HEARTS }
    spades = @hand.select { |card| card.suit == AgentVsAgent::Suit::SPADES }
    #diamonds = @hand.select { |card| card.suit == AgentVsAgent::Suit::DIAMONDS }

    if have_the_queen? && spades.count < 5
      queen = @hand.detect{|card| card.suit == AgentVsAgent::Suit::SPADES && card.rank == AgentVsAgent::Rank::QUEEN }
      return queen
    end

    if ace_of_spades = @hand.detect{|card| card.suit == AgentVsAgent::Suit::SPADES && card.rank == AgentVsAgent::Rank::ACE }
      return ace_of_spades
    end

    if king_of_spades = @hand.detect{|card| card.suit == AgentVsAgent::Suit::SPADES && card.rank == AgentVsAgent::Rank::KING }
      return king_of_spades
    end

    if two_clubs = @hand.detect{|card| card.suit == AgentVsAgent::Suit::CLUBS && card.rank == AgentVsAgent::Rank::TWO }
      return two_clubs
    end

    return highest_card @hand

  end

  def highest_card suitable_cards
    ranks = []
    suitable_cards.each { |card| ranks << card.rank }
    highest_suitable_card =  suitable_cards.select{|card| card.rank == ranks.max }
    return highest_suitable_card.first
  end

  def lowest_card suitable_cards
    ranks = []
    suitable_cards.each { |card| ranks << card.rank }
    lowest_suitable_card = suitable_cards.select{|card| card.rank == ranks.min }
    return lowest_suitable_card.first
  end

  def have_the_queen?
    queen = @hand.detect{|card| card.suit == AgentVsAgent::Suit::SPADES && card.rank == AgentVsAgent::Rank::QUEEN }
    return !queen.nil?
  end

  def drop_queen
    return @hand.detect{|card| card.suit == AgentVsAgent::Suit::SPADES && card.rank == AgentVsAgent::Rank::QUEEN }
  end

  def play_matching_suit(suit, trick)
    suitable_cards = @hand.select{|card| card.suit == suit }

    if trick.played[2] && (!trick.played.detect {|card| card.suit == AgentVsAgent::Suit::SPADES && card.rank == AgentVsAgent::Rank::QUEEN } && !trick.played.detect {|card| card.suit == AgentVsAgent::Suit::HEARTS } )
      return highest_card suitable_cards
    end

    if trick.played.detect {|card| card.suit == AgentVsAgent::Suit::SPADES && card.rank == AgentVsAgent::Rank::QUEEN }
      return lowest_card suitable_cards
    end

    return lowest_card suitable_cards
  end

  def play_lead_card
    suitable_cards = @hand
    unless @hearts_been_broken
      suitable_cards = suitable_cards.reject{ |card| card.suit == AgentVsAgent::Suit::HEARTS }
      if suitable_cards.empty?
        puts "playing hearts anyways"
        suitable_cards = @hand
      end
    end

    return lowest_card suitable_cards
  end

  def play_trick
    puts "[#{@game_info.position}, round #{@round_number}, trick #{@trick_number}, playing trick"
    puts "#{@hand.inspect}"
    puts "#{@hand.size}"

    clubs = @hand.select { |card| card.suit == AgentVsAgent::Suit::CLUBS }
    hearts = @hand.select { |card| card.suit == AgentVsAgent::Suit::HEARTS }
    #spades = @hand.select { |card| card.suit == AgentVsAgent::Suit::SPADES }
    #diamonds = @hand.select { |card| card.suit == AgentVsAgent::Suit::DIAMONDS }

    trick = @game.get_trick @ticket
    puts "Leading the trick #{@game_info.inspect}, #{trick.inspect}" if @game_info.position == trick.leader
    puts "current trick: #{trick.inspect}"

    #initial round
    if @trick_number == 0 && two_clubs = @hand.detect{|card| card.suit == AgentVsAgent::Suit::CLUBS && card.rank == AgentVsAgent::Rank::TWO }
      puts "playing two of clubs"
      card_to_play = two_clubs
      #initial round but does not have 2
    elsif @trick_number == 0 && !clubs.empty?
      puts "playing highest club"
      card_to_play = clubs.max
      #matching suit
    elsif trick.played[0] && @hand.detect{|card| card.suit == trick.played[0].suit}
      puts "playing matching suit"
      card_to_play = play_matching_suit(trick.played[0].suit, trick)
    else
      if have_the_queen? && !trick.played[0].nil? && @trick_number != 0
        puts "playing queen of spades"
        card_to_play = drop_queen
      elsif !hearts.empty? && !trick.played[0].nil?
        puts "playing highest heart"
        card_to_play = hearts.max
      elsif !trick.played[0].nil?
        puts "playing highest card"
        card_to_play = highest_card @hand.reject{|card| card.suit == trick.played[0].suit}

      else
        puts "playing leading card"
        card_to_play = play_lead_card
      end
    end

    @hand.delete(card_to_play)
    puts "[#{@game_info.position}] playing card: #{card_to_play.inspect}"
    trick_result = @game.play_card @ticket, card_to_play
    unless @hearts_been_broken
      break_hearts if trick.played.detect{ |card| card.suit == AgentVsAgent::Suit::HEARTS }
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


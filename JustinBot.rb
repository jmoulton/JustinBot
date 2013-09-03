require 'thrift'
$:.unshift File.dirname(__FILE__) + '/lib'
require 'hearts'

# Kris Local
#socket = Thrift::Socket.new('kemper.local', 4001)
socket = Thrift::Socket.new('127.0.0.1', 4001)
transport = Thrift::FramedTransport.new(socket)
protocol = Thrift::BinaryProtocol.new(transport)
client = AgentVsAgent::Hearts::Client.new(protocol)


class JustinBot

  def initialize game
    @game = game

    #shothand ranks
    @ace = AgentVsAgent::Rank::ACE
    @king = AgentVsAgent::Rank::KING
    @queen = AgentVsAgent::Rank::QUEEN
    @jack = AgentVsAgent::Rank::JACK
    @ten = AgentVsAgent::Rank::TEN
    @nine = AgentVsAgent::Rank::NINE
    @eight = AgentVsAgent::Rank::EIGHT
    @seven = AgentVsAgent::Rank::SEVEN
    @six = AgentVsAgent::Rank::SIX
    @five = AgentVsAgent::Rank::FIVE
    @four = AgentVsAgent::Rank::FOUR
    @three = AgentVsAgent::Rank::THREE
    @two = AgentVsAgent::Rank::TWO

    #shorthand suits
    @heart = AgentVsAgent::Suit::HEARTS
    @diamond = AgentVsAgent::Suit::DIAMONDS
    @spade = AgentVsAgent::Suit::SPADES
    @club = AgentVsAgent::Suit::CLUBS

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
    puts "************BREAKING HEARTS***************"
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
    clubs = @hand.select { |card| card.suit == @club }
    hearts = @hand.select { |card| card.suit == @heart }
    spades = @hand.select { |card| card.suit == @spade }
    diamonds = @hand.select { |card| card.suit == @diamond }

    if have_the_queen? && spades.count < 4
      queen = @hand.detect{|card| card.suit == @spade && card.rank == @queen }
      return queen
    end

    if ace_of_spades = @hand.detect{|card| card.suit == @spade && card.rank == @ace }
      return ace_of_spades
    end

    if king_of_spades = @hand.detect{|card| card.suit == @spade && card.rank == @king }
      return king_of_spades
    end

    if two_clubs = @hand.detect{|card| card.suit == @club && card.rank == @two }
      return two_clubs
    end

    if hearts.any? && hearts.count < 4
      return highest_card hearts
    elsif clubs.any? && clubs.count < 3
      return highest_card clubs
    elsif diamonds.any? && diamonds.count < 3
      return highest_card diamonds
    else
      return highest_card @hand
    end

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
    queen = @hand.detect{|card| card.suit == @spade && card.rank == @queen }
    return !queen.nil?
  end

  def drop_queen
    return @hand.detect{|card| card.suit == @spade && card.rank == @queen }
  end

  def play_matching_suit(suit, trick)
    suitable_cards = @hand.select{|card| card.suit == suit }

    if trick.played[2] && (!trick.played.detect {|card| card.suit == @spade && card.rank == @queen } && 
                           !trick.played.detect {|card| card.suit == @heart})
      return highest_card suitable_cards
    end

    if trick.played.detect {|card| card.suit == @spade && card.rank == @queen }
      return lowest_card suitable_cards
    end

    return lowest_card suitable_cards
  end

  def play_lead_card
    clubs = @hand.select { |card| card.suit == @club }
    diamonds = @hand.select { |card| card.suit == @diamond }

    suitable_cards = @hand

    unless @hearts_been_broken
      suitable_cards = suitable_cards.reject{ |card| card.suit == @heart }
      if suitable_cards.empty?
        puts "playing hearts anyways"
        suitable_cards = @hand
      end
    end

    if @trick_number < 4
      if diamonds.any? && diamonds.count < 2
        return lowest_card diamonds
      end
      if clubs.any? && clubs.count < 2
        return lowest_card clubs
      end
    end

    return lowest_card suitable_cards
  end

  def play_trick
    puts "[#{@game_info.position}, round #{@round_number}, trick #{@trick_number}, playing trick"
    puts "#{@hand.inspect}"
    puts "#{@hand.size}"

    clubs = @hand.select { |card| card.suit == @club }
    hearts = @hand.select { |card| card.suit == @heart }
    #spades = @hand.select { |card| card.suit == @spade }
    #diamonds = @hand.select { |card| card.suit == @diamond }

    trick = @game.get_trick @ticket
    puts "Leading the trick #{@game_info.inspect}, #{trick.inspect}" if @game_info.position == trick.leader
    puts "current trick: #{trick.inspect}"

    #initial round
    if @trick_number == 0 && two_clubs = @hand.detect{|card| card.suit == @club && card.rank == @two }
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
      elsif !hearts.empty? && !trick.played[0].nil? && @trick_number != 0
        puts "playing highest heart"
        card_to_play = hearts.max
      elsif !trick.played[0].nil?
        puts "playing highest card"
        card_to_play = highest_card @hand.reject{|card| card.suit == @heart}

      else
        puts "playing leading card"
        card_to_play = play_lead_card
      end
    end

    @hand.delete(card_to_play)
    puts "[#{@game_info.position}] playing card: #{card_to_play.inspect}"
    trick_result = @game.play_card @ticket, card_to_play
    break_hearts if trick_result.played.detect{ |card| card.suit == @heart || card_to_play.suit == @heart }
    puts "trick result: #{trick_result.inspect}"
  end
end


puts "Opening connection"
transport.open
bot = JustinBot.new(client)
bot.run
transport.close

puts "Finished"
puts "#{@game_info.position}"



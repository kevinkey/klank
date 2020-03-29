module Klank
    require_relative "deck.rb"

    class Player

        attr_reader :name

        def initialize(client)
            @client = client

            @name = input("Name")
            output("Welcome to Klank, #{@name}!")
        end

        def input(msg)
            @client.write "\n#{msg }: "
            resp = @client.gets.strip

            resp
        end

        def input_num(msg, range)
            n = 0

            loop do 
                n = input("#{msg} [#{range.min}, #{range.max}]")
                break if n =~ /^\d+/ and range.include?(n.to_i)
                output("Oops!")
            end

            return n.to_i
        end

        def output(msg)
            @client.puts "\n#{msg}"
        end

        def menu(options)
            msg = []
            options.each do |o|
                msg << "#{o[0]}: #{o[1]}"
            end
            output(msg.join("\n"))

            choice = ""
            loop do
                choice = input("Choose an option").upcase
                break if options.any? { |o| o[0].to_s.upcase == choice }
                output("Oops!")
            end

            choice
        end

        def score()
            @coins
        end

        def start(game)
            @game = game
            @deck = Deck.new("player.yml")
            @coins = 0
        end

        def turn(reserve)
            output("Drawing cards...")
            @hand = @deck.draw(5)
            msg = []
            @hand.each_with_index do |c, i|
                msg << c.play_desc
            end
            output(msg.join("\n"))

            @played = []
            @skill = 0
            @move = 0
            @attack = 0
            @teleport = 0

            loop do 
                menu = []

                if @hand.count != 0
                    menu << ["E", "Equip card(s)"]
                end

                if (reserve[:x].remaining > 0) and (@skill >= reserve[:x].peek.cost)
                    menu << ["X", "Buy an explore card"]
                end

                if (reserve[:c].remaining > 0) and (@skill >= reserve[:c].peek.cost)
                    menu << ["C", "Buy a mercenary card"]
                end

                if (reserve[:t].remaining > 0) and (@skill >= reserve[:t].peek.cost)
                    menu << ["T", "Buy a tome card"]
                end

                if @skill > 0
                    menu << ["B", "Buy a card from the dungeon"]
                end

                if @move > 0 
                    menu << ["M", "Move"]
                end

                if @attack > 0
                    menu << ["A", "Attack a monster from the dungeon"]
                end

                if @attack > 1
                    menu << ["G", "Kill the goblin"]
                end

                if @hand.count == 0
                    menu << ["D", "End Turn"]
                end

                option = menu(menu)
                
                case option
                when "E"
                    equip()
                when "X"
                    x = reserve[:x].draw(1)
                    @deck.discard(x)
                    @skill -= x[0].cost
                when "C"
                    c = reserve[:c].draw(1)
                    @deck.discard(c)
                    @skill -= c[0].cost
                when "T"
                    t = reserve[:t].draw(1)
                    @deck.discard(t)
                    @skill -= t[0].cost
                when "B"

                when "M"

                when "A"

                when "G"
                    @coins += 1
                    @attack -= 2
                when "D"
                    @deck.discard(@played)
                    break
                else
                    output("Hmmm... something went wrong")
                end

                output_abilities()
            end
        end

        private 

        def output_abilities()
            string = []

            if @skill != 0
                string << "SKILL: #{@skill}"
            end 

            if @move != 0
                string << "MOVE: #{@move}"
            end 

            if @attack != 0
                string << "ATTACK: #{@attack}"
            end

            if @coins != 0
                string << "COINS: #{@coins}"
            end

            if @teleport != 0
                string << "TELEPORT: #{@teleport}"
            end

            output(string.join(" | "))
        end

        def equip()
            cards = []
            @hand.each_with_index do |c, i|
                cards << [i, c.play_desc]
            end
            cards << ["A", "All of the cards"]
            cards << ["N", "None of the cards"]
            c = menu(cards)

            play = []

            if c == "A"
                play = @hand 
                @hand = []
            elsif c == "N"

            else
                play = @hand[c.to_i]
                @hand.delete_at(c.to_i)
            end

            msg = []

            play.each do |card|
                @skill += card.skill
                @attack += card.attack 
                @move += card.move
                @coins += card.coins
                @teleport += card.teleport

                msg << "#{@name} played #{card.name}"
            end

            @game.broadcast(msg.join("\n"))

            @played += play
        end

    end
end
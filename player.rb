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
            @client.write "#{msg }: "
            resp = @client.gets.strip

            resp
        end

        def input_num(msg, range)
            loop do 

            end
        end

        def output(msg)
            @client.puts "#{msg}"
        end

        def menu(options)
            msg = []
            options.each do |o|
                msg << "#{o[0]}: #{o[1]}"
            end
            msg.join("\n")
            output(msg)

            loop do
                choice = input("Choose an option").upcase
                break if options.any? { |o| o.upcase == choice }
                output("Oops!")
            end

            choice
        end

        def score()
            0
        end

        def start()
            @deck = Deck.new("player.yml")
            @coins = 0
        end

        def turn(reserve)
            output("Drawing cards...")
            hand = @deck.draw(5)

            skill = 0
            move = 0
            attack = 0

            loop do 
                menu = []

                hand.each_with_index do |c, i|
                    menu << "#{i}: #{c.play_desc}"
                end

                if hand.count != 0
                    menu << "E: Equip all cards"
                end

                if (skill >= 3) and reserve[:explore].remaining > 0
                    menu << "X: Buy an explore card"
                end

                if (skill >= 2) and reserve[:mercenary].remaining > 0
                    menu << "C: Buy a mercenary card"
                end

                if (skill >= 7) and reserve[:tome].remaining > 0
                    menu << "T: Buy a tome card"
                end

                if skill > 0
                    menu << "D: Buy a card from the dungeon"
                end

                if move > 0 
                    menu << "M: Move"
                end

                if attack > 0
                    menu << "A: Attack a monster from the dungeon"
                end

                if attack > 1
                    menu << "G: Kill the goblin"
                end

                if hand.count == 0
                    menu << "D: End Turn"
                end

                output(menu.join("\n"))
                option = input("Choose an action").upcase 

                if menu.any? { |m| m.start_with?("#{option}:") }
                    case option
                    when "E"
                    else

                    end
                end
            end
        end

    end
end
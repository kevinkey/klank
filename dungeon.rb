module Klank
    require_relative "deck.rb"

    class Dungeon
        COUNT = 6

        def initialize(game)
            @game = game
            @deck = Deck.new(game, "dungeon.yml")
            @hand = []

            while @hand.count < COUNT
                if @deck.peek.dragon 
                    @deck.reshuffle!()
                else
                    @hand << @deck.draw(1)[0]
                end
            end
        end

        def danger()
            @hand.select { |c| c.danger }.count
        end

        def replenish()
            count = COUNT - @hand.count

            if count > 0
                msg = ["\nReplenishing the dungeon..."]
                attack = false

                cards = @deck.draw(count)
                
                string = []
                cards.each do |c|
                    string << c.name
                    if c.dragon
                        attack = true
                    end              
                end
                msg << string.join(" | ")
                @game.broadcast(msg.join("\n"))
                @hand += cards

                if attack 
                    @game.dragon.attack()
                end
            end

            msg = ["\nDUNGEON"]
            @hand.each_with_index do |c, i|
                msg << c.buy_desc
            end
            @game.broadcast(msg.join("\n"))
        end

        def buy(player)
            card = nil

            loop do 
                c = menu(player)
                break if c == "N"

                if @hand[c.to_i].acquire(player)
                    card = @hand.delete_at(c.to_i)
                    break
                end
            end

            card
        end

        def monster(player)
            card = nil

            loop do 
                c = menu(player)
                break if c == "N"

                if @hand[c.to_i].defeat(player)
                    card = @hand.delete_at(c.to_i)
                    break
                end
            end

            card
        end

        def replace_card(player)
            c = menu(player)
            if c != "N"
                removed = @hand.delete_at(c.to_i)
                added = @deck.draw(1)[0]
                @hand << added
                @game.broadcast("#{player.name} removed #{removed.name} and #{added.name} replaced it!")
            end
        end

        private 

        def menu(player)
            options = []
            @hand.each_with_index do |c, i|
                options << [i, c.buy_desc]
            end
            options << ["N", "None of the cards"]
            card = player.menu("DUNGEON", options)
        end
    end
end

module Klank
    require_relative "deck.rb"

    class Dungeon
        def initialize(game)
            @game = game
            @deck = Deck.new("dungeon.yml")
            @hand = []

            while @hand.count < 6
                if @deck.peek.dragon 
                    @deck.reshuffle!()
                else
                    @hand << @deck.draw(1)[0]
                end
            end
        end

        def danger()
            count = 0

            @hand.each do |c|
                count += 1 if c.danger
            end

            count
        end

        def replenish()
            count = 6 - @hand.count

            if count > 0
                msg = ["\nReplenishing the dungeon..."]
                attack = false

                cards = @deck.draw(count)
                
                cards.each do |c|
                    string = [c.name]
                    if c.dragon
                        string << "DRAGON ATTACK"
                        attack = true
                    end 
                    if c.arrive[:clank]
                        string << "All players +1 clank"
                        @game.player.each do |p|
                            p.clank()
                        end
                    end
                    if c.arrive[:dragon]
                        string << "Put 3 dragon cubes back"
                        @game.dragon.add_dragon_cubes()
                    end

                    msg << string.join(" | ")
                end
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
                temp = @hand[c.to_i]
                if temp.defeat != 0
                    player.output("Can't buy a monster!")
                elsif player.skill >= temp.cost
                    card = @hand.delete_at(c.to_i)
                    break
                else
                    player.output("Not enough skill!")
                end
            end

            card
        end

        def monster(player)
            card = nil
            loop do 
                c = menu(player)
                break if c == "N"
                temp = @hand[c.to_i]
                if temp.defeat == 0
                    player.output("That's not a monster!")
                elsif player.attack >= temp.defeat
                    card = @hand.delete_at(c.to_i)
                    break
                else
                    player.output("Not enough attack!")
                end
            end

            card
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

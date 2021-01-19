module Klank
    require_relative "deck.rb"
    require_relative "utils.rb"

    class Dungeon
        COUNT = 6

        def initialize(game)
            @game = game
            @deck = Deck.new(game, "dungeon.yml")
            @hand = []
            
            if @game.sunken_treasures
                @deck.add(game, "sunken_treasures/dungeon.yml")
            end

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
            count = [COUNT - @hand.count, @deck.stack.count].min

            if count > 0
                @game.broadcast("\nReplenishing the dungeon...")
                attack = false

                cards = @deck.draw(count)
                
                cards.each do |c|
                    c.arrive()
                    if c.dragon
                        attack = true
                    end              
                end
                @hand += cards

                if attack 
                    @game.dragon.attack()
                end
            end

            view
        end

        def acquire(player, card = nil)
            if @hand.include? card
                if card.type == :monster
                    if card.defeat(player)
                        card = @hand.delete_at(@hand.index(card))
                        @game.broadcast("#{player.name} killed #{card.name} in the dungeon!")
                    end
                elsif card.acquire(player)
                    card = @hand.delete_at(@hand.index(card))
                    @game.broadcast("#{player.name} bought #{card.name} from the dungeon!")
                    if card.type != :device
                        player.deck.discard([card])
                    end
                end
            else
                loop do                 
                    player.output("\n" + Klank.table([{"SKILL" => player.skill, "ATTACK" => player.attack, "CLANK" => player.clank_remove}]))

                    c = menu("BUY OR DEFEAT A CARD", player)
                    break if c == "N"

                    if @hand[c.to_i].type == :monster
                        if @hand[c.to_i].defeat(player)
                            card = @hand.delete_at(c.to_i)
                            @game.broadcast("#{player.name} killed #{card.name} in the dungeon!")
                        end
                    elsif @hand[c.to_i].acquire(player)
                        card = @hand.delete_at(c.to_i)
                        @game.broadcast("#{player.name} bought #{card.name} from the dungeon!")
                        if card.type != :device
                            player.deck.discard([card])
                        end
                    end

                    if @hand.count == 0
                        break
                    elsif !afford?(player)
                        break 
                    end
                end
            end
        end

        def afford?(player)
            result = @hand.count > 0
            if result
                result = ((player.skill >= @hand.map { |c| c.player_cost(player) }.min) or (player.attack >= @hand.map { |c| c.attack }.min))
            end
            result
        end

        def crystal_golem()
            @hand.find { |card| card.name == "Crystal Golem"}
        end

        def pickpocket(player, cost)
            if @hand.any? { |c| c.cost <= cost }
                c = menu("PICKPOCKET A CARD", player, cost)
                if c != "N"
                    card = @hand.select { |c| c.cost <= max_cost }.index(c.to_i)
                    @hand.delete(@hand.index(card))
                    player.deck.discard([card])
                    @game.broadcast("#{player.name} pickpocketed #{card.name} from the dungeon!")
                end
            end
        end

        def replace_card(player)
            c = menu("REPLACE A CARD", player)
            if c != "N"
                removed = @hand.delete_at(c.to_i)
                added = @deck.draw(1)[0]
                @hand << added
                @game.broadcast("#{player.name} removed #{removed.name} and #{added.name} replaced it!")
            end
        end

        def view(player = nil)
            dungeon = []
            @hand.each_with_index do |c, i|
                dungeon << c.buy_desc(false)
            end
            if (player != nil)
                player.output("\nDUNGEON\n#{Klank.table(dungeon)}")
            else
                @game.broadcast("\nDUNGEON\n#{Klank.table(dungeon)}")
            end
        end

        private 

        def menu(title, player, max_cost = 1000000)
            options = []
            @hand.select { |c| c.cost <= max_cost }.each_with_index do |c, i|
                options << [i, c.buy_desc(player.has_played?("Gem Collector"))]
            end
            card = player.menu(title, options, true)
        end
    end
end
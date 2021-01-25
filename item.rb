module Klank
    class Item

        attr_reader :name
        attr_reader :symbol
        
        def initialize(game, hash)
            @game = game
            @name = hash["name"] || ""
            @symbol = hash["symbol"] || ""
            @hash = hash
        end

        def playable()
            play = [
                "Potion of Greater Healing",
                "Greater Skill Boost",
                "Flash of Brilliance",
                "Potion of Heroism",
                "Potion of Healing",
                "Potion of Swiftness",
                "Potion of Strength",
                "Skill Boost",
                "Magic Spring"
            ]
            play.any? { |i| i == @name }
        end

        def play(player)
            played = true
            
            if @hash.key?("heal")
                player.heal(@hash["heal"])
            elsif @hash.key?("skill")
                player.skill += @hash["skill"]
            elsif @hash.key?("draw")
                player.draw(@hash["draw"])
            elsif @hash.key?("move")
                player.move += @hash["move"]
            elsif @hash.key?("attack")
                player.attack += @hash["attack"]
            elsif @name == "Magic Spring"
                played = player.trash_card()
            end

            if played 
                @game.broadcast("#{player.name} played #{name}!")
            end
            
            played
        end

        def points()
            amount = 0

            if @hash.key?("points") 
                amount = @hash["points"]
            end

            amount
        end

        def gain(player)
            player.item << self

            if @hash.key?("coins")
                @game.map.bank += @hash["coins"]    # <-- secrets don't count towards initial bank amount
                player.collect_coins(@hash["coins"])
            end

            if @name == "Dragon Egg"
                @game.dragon.anger()
            end
        end

        def desc()
            "#{@name} | #{@hash["description"]}"
        end
    end
end

module Klank
    class Card

        attr_reader :name
        attr_reader :type
        attr_reader :cost
        attr_reader :danger
        attr_reader :dragon

        def initialize(hash)
            @name = hash["name"]
            @type = hash["type"] || ""
            @cost = hash["cost"] || 0
            @attack = hash["attack"] || 0
            @special = hash["special"] || ""
            @danger = hash.key?("danger")
            @dragon = hash.key?("dragon")

            @hash = hash
        end 

        def arrive()
            case @name 
            when "Overlord", "Watcher"
                @game.player.each do |p|
                    p.clank()
                end
            when "Shrine"
                @game.dragon.add_dragon_cubes()
            end
        end

        def acquire(player)
            success = false 

            if @type == :monster
                player.output("Can't buy a monster!")
            elsif @hash.key?("depths") && !player.depths?()
                player.output("Must be in the depths to acquire!")
            elsif player.skill >= @cost
                success = true

                player.skill -= @cost

                if @hash.key?("acquire")
                    abilities(player, @hash["acquire"])
                end
            else
                player.output("Not enough skill!")
            end

            success
        end

        def defeat(player)
            success = false

            if @type != :monster
                player.output("That's not a monster!")
            elsif @hash.key?("depths") && !player.depths?()
                player.output("Must be in the depths to defeat!")
            elsif player.attack >= @attack
                success = true
                
                player.attack -= @attack

                if @hash.key?("defeat")
                  abilities(player, @hash["defeat"])
                end
            else
                player.output("Not enough attack!")
            end

            success
        end

        def equip(player)
            if @hash.key?("equip")
                abilities(player, @hash["equip"])
            end
        end

        def play_desc()
            string = [
                sprintf("%-25s", @name), 
                sprintf("%-10s", @type.to_s.upcase)
            ]

            if @hash.key?("equip")
                if @hash["equip"].key?("skill") 
                    string << "SKILL: #{@hash["equip"]["skill"]}"
                end
                if @hash["equip"].key?("move") 
                    string << "MOVE: #{@hash["equip"]["move"]}"
                end
                if @hash["equip"].key?("attack") 
                    string << "ATTACK: #{@hash["equip"]["attack"]}"
                end
                if @hash["equip"].key?("teleport") 
                    string << "TELEPORT"
                end
                if @hash["equip"].key?("coins") 
                    string << "COINS: #{@hash["equip"]["coins"]}"
                end
                if @hash["equip"].key?("draw") 
                    string << "DRAW: #{@hash["equip"]["draw"]}"
                end
                if @hash["equip"].key?("clank") 
                    string << "CLANK: #{@hash["equip"]["clank"]}"
                end
                if @hash["equip"].key?("heal") 
                    string << "HEAL: #{@hash["equip"]["heal"]}"
                end
            end

            if @hash.key?("special")
                string << @special
            end

            string.join(" | ")
        end

        def buy_desc()
            string = [play_desc]

            if @hash.key?("points")
                string << "POINTS: #{@hash["points"]}"
            end

            if @hash.key?("cost")
                string << "COST: #{@hash["cost"]}"
            end

            if @hash.key?("attack")
                string << "DEFEAT: #{@hash["attack"]}"
            end

            string.join(" | ")
        end

        def abilities(player, hash)
            if hash.key?("skill") 
                player.skill += hash["skill"]
            end
            if hash.key?("move") 
                player.move += hash["move"]
            end
            if hash.key?("attack") 
                player.attack += hash["attack"]
            end
            if hash.key?("teleport") 
                player.teleport += hash["teleport"]
            end
            if hash.key?("coins") 
                player.coins += hash["coins"]
            end
            if hash.key?("draw") 
                player.draw(hash["draw"])
            end
            if hash.key?("clank") 
                player.clank(hash["clank"])
            end
            if hash.key?("heal") 
                player.heal(hash["heal"])
            end
        end
    end
end
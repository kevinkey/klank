module Klank
    class Card

        attr_reader :name
        attr_reader :type
        attr_reader :cost 
        attr_reader :defeat
        attr_reader :points
        attr_reader :skill
        attr_reader :move 
        attr_reader :attack
        attr_reader :clank 
        attr_reader :coins
        attr_reader :teleport
        attr_reader :danger
        attr_reader :dragon
        attr_reader :arrive

        def initialize(hash)
            @name = hash["name"]
            @type = hash["type"] || :normal
            @cost = hash["cost"] || 0
            @defeat = hash["defeat"] || 0
            @points = hash["points"] || 0
            @skill = hash["skill"] || 0
            @move = hash["move"] || 0
            @attack = hash["attack"] || 0
            @clank = hash["clank"] || 0
            @coins = hash["coins"] || 0
            @teleport = hash.key?("teleport")
            @danger = hash.key?("danger")
            @dragon = hash.key?("dragon")
            if hash.key?("arrive")
                @arrive = {
                    clank: hash["arrive"].key?("clank"),
                    dragon: hash["arrive"].key?("dragon")
                }
            else
                @arrive = {clank: false, dragon: false}
            end
            @special = hash["special"] || ""
        end 

        def arrive()

        end

        def acquire(player)
            success = false 

            if @type == :monster
                player.output("Can't buy a monster!")
            elsif player.skill >= @cost
                success = true

                player.skill -= @cost
            else
                player.output("Not enough skill!")
            end

            success
        end

        def defeat(player)
            success = false

            if @type != :monster
                player.output("That's not a monster!")
            elsif player.attack >= @defeat
                success = true

                player.move += @move 
                player.coins += @coins
                player.clank(@clank)
                player.attack -= @defeat
            else
                player.output("Not enough attack!")
            end

            success
        end

        def equip(player)
            player.skill += @skill
            player.attack += @attack 
            player.move += @move
            player.coins += @coins
            player.teleport += 1 if @teleport
        end

        def play_desc()
            string = ["#{@name}"]

            if @type != :normal
                string << @type.to_s.upcase
            end

            if @skill != 0
                string << "SKILL: #{@skill}"
            end 

            if @move != 0
                string << "MOVE: #{@move}"
            end 

            if @attack != 0
                string << "ATTACK: #{@attack}"
            end 

            if @clank != 0
                string << "CLANK: #{@clank}"
            end

            if @coins != 0
                string << "COINS: #{@coins}"
            end

            if @teleport
                string << "TELEPORT"
            end

            if @special != ""
                string << @special
            end

            string.join(" | ")
        end

        def buy_desc()
            string = [play_desc]

            if @points != 0
                string << "POINTS: #{@points}"
            end

            if @cost != 0
                string << "COST: #{@cost}"
            end

            if @defeat != 0
                string << "DEFEAT: #{@defeat}"
            end

            string.join(" | ")
        end
    end
end
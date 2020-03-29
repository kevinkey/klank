module Klank
    class Card

        attr_reader :name
        attr_reader :cost 
        attr_reader :points
        attr_reader :skill
        attr_reader :move 
        attr_reader :attack
        attr_reader :clank 
        attr_reader :teleport

        def initialize(hash)
            @name = hash["name"]
            @cost = hash["cost"] || 0
            @points = hash["points"] || 0
            @skill = hash["skill"] || 0
            @move = hash["move"] || 0
            @attack = hash["attack"] || 0
            @clank = hash["clank"] || 0
            @teleport = hash.key?("teleport")
        end 

        def play_desc()
            string = ["#{@name}"]

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

            if @teleport
                string << "TELEPORT"
            end

            string.join(" | ")
        end

        def buy_desc()
            string = [play_desc]

            if @cost != 0
                string << "COST: #{@cost}"
            end

            if @points != 0
                string << "POINTS: #{@points}"
            end

            string.join(" | ")
        end

    end
end
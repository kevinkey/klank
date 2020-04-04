module Klank
    class Item

        attr_reader :name
        
        def initialize(hash)
            @name = hash["name"]

            @hash = hash
        end

        def playable()
            false
        end

        def play(player)

        end

        def play_desc()

        end
    end
end

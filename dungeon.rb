module Klank
    require_relative "deck.rb"

    class Dungeon
        def initialize()
            @deck = Deck.new("dungeon.yml")
        end

    end
end

require "yaml"

module Klank
    require_relative "card.rb"
    require_relative "utils.rb"

    class Deck
        def initialize(yml)
            @stack = []
            @pile = []

            YAML.load(File.read(yml)).each do |c|
                c["count"].times do 
                    @stack << Card.new(c)
                end
            end
            @stack = Klank.randomize(@stack)
        end

        def remaining()
            @stack.count
        end

        def draw(num)
            hand = []

            num.times do 
                if @stack.count == 0
                    @stack = Klank.randomize(@pile)
                    @pile = []
                end 
                hand << @stack.pop
            end

            hand
        end

        def discard(hand)
            @pile += hand
        end
    end
end

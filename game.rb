module Klank
    require_relative "deck.rb"
    require_relative "dragon.rb"
    require_relative "dungeon.rb"
    require_relative "utils.rb"

    class Game

        attr_reader :name
        attr_reader :num
        attr_reader :shutdown

        def initialize(name, num)
            @name = name
            @num = num
            @player = []

            @shutdown = false 
            @game_over = false
        end

        def status 
            "#{@name}, #{@player.count} / #{@num}"
        end

        def join(player)
            @player.each_with_index do |p, i|
                p.output("#{@player.count}: #{player.name}")
                player.output("#{i}: #{p.name}")
            end

            player.output("#{@player.count}: #{player.name}")
            @player << player

            if @player.count == @num 
                start()
            else 
                loop do 
                    break if @shutdown
                end
            end          
        end

        def broadcast(msg)
            @player.each do |p|
                p.output(msg)
            end
        end

        private 

        def start()
            @dragon = Dragon.new(self)
            @dungeon = Dungeon.new(self)
            @player = Klank.randomize(@player)
            @line = 0

            msg = "Randomizing play order...\n"
            @player.each_with_index do |p, i|
                msg += "#{i}: #{p.name}\n"
                p.start(self, i)
            end
            broadcast(msg)

            reserve = {
                x: Deck.new("explore.yml"),
                c: Deck.new("mercenary.yml"),
                t: Deck.new("tome.yml"),
            }

            loop do 
                @player.each do |p|
                    @dungeon.replenish()
                    broadcast("Starting #{p.name}'s turn...")
                    @game_over = p.turn(reserve)
                    break if @game_over
                end

                break if @game_over
            end

            broadcast("GAME OVER!")

            scores()

            @shutdown = true
        end

        def scores()
            msg = "Scores\n"
            player.sort_by { |p| p.score }.reverse.each_with_index do |p, i|
                msg += "#{p.name}: #{p.score}\n"
            end
            broadcast(msg)
        end
    end
end

    
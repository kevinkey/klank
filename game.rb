require_relative "utils.rb"

module Klank
    class Game

        attr_reader :name
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
            @player = Klank.randomize(@player)

            msg = "Randomizing play order...\n"
            @player.each_with_index do |p, i|
                msg += "#{i}: #{p.name}\n"
                p.start(self)
            end
            broadcast(msg)

            reserve = {
                x: Deck.new("explore.yml"),
                c: Deck.new("mercenary.yml"),
                t: Deck.new("tome.yml"),
            }

            loop do 
                @player.each do |p|
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

    
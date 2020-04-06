module Klank
    require_relative "deck.rb"
    require_relative "dragon.rb"
    require_relative "dungeon.rb"
    require_relative "map.rb"
    require_relative "utils.rb"

    class Game
        attr_reader :name
        attr_reader :num
        attr_reader :map
        attr_reader :shutdown
        attr_reader :reserve
        attr_reader :dungeon
        attr_reader :dragon
        attr_reader :player
        attr_reader :escalation

        def initialize(name, num, map)
            @name = name
            @num = num
            @map = Map.new(self, map)
            @player = []
            @trigger = -1

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
                    sleep(1.0)
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
            @escalation = 0

            msg = "\nGAME STARTING\nRandomizing play order...\n"
            @player.each_with_index do |p, i|
                msg += "#{i}: #{p.name}\n"
                p.start(self, i)
            end
            broadcast(msg)

            @reserve = {
                x: Deck.new(self, "explore.yml"),
                c: Deck.new(self, "mercenary.yml"),
                t: Deck.new(self, "tome.yml"),
            }

            loop do 
                all_dead = true

                @player.each do |p|
                    @dungeon.replenish()
                    if @trigger == player.index
                        broadcast("\n#{p.name} triggered end of game!")

                        @escalation += 1
                        if @escalation > 3 
                            @game_over = true 
                        else
                            @dragon.attack()
                        end
                    elsif p.dead?()
                        broadcast("\n#{p.name} is dead!")
                    elsif p.mastery
                        broadcast("\n#{p.name} has left with an artifact!")                        
                    else
                        all_dead = false
                        broadcast("\nStarting #{p.name}'s turn...")
                        p.turn()
                    end
                    break if @game_over
                end

                break if @game_over || all_dead
                sleep(0.1)
            end

            broadcast("GAME OVER!")

            scores()

            @shutdown = true
        end

        def trigger_end(player)
            if @trigger < 0
                @trigger = player.index
                broadcast("#{player.name} has triggered the end of game!")
            end
        end

        def scores()
            msg = "Scores\n"
            @player.sort_by { |p| p.score }.reverse.each_with_index do |p, i|
                msg += "#{p.name}: #{p.score}\n"
            end
            broadcast(msg)
        end
    end
end

    
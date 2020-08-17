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
        attr_reader :started
        attr_reader :shutdown
        attr_reader :game_over
        attr_reader :reserve
        attr_reader :dungeon
        attr_reader :dragon
        attr_reader :player
        attr_reader :escalation

        def initialize(name, num, map)
            @name = name
            @num = num
            @map_num = map
            @map = Map.new(self, map)
            @player = []
            @spectator = []

            @shutdown = false
            @game_over = false
            @started = false
        end

        def status
            {
                "Name" => @name,
                "Map" => @map_num,
                "Players" => "#{@player.count} / #{@num}"
            }
        end

        def spectate(player)
            @spectator << player

            loop do
                sleep(1.0)
                break if @shutdown
            end
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
            @spectator.each do |p|
                p.output(msg)
            end
        end

        def trigger_end(player)
            if @trigger < 0
                @trigger = player.index
                broadcast("#{player.name} has triggered the end of game!")
            end
        end

        def view_players(player = nil)
            status = []
            @player.each do |p|
                status << p.status
            end
            if player == nil
                broadcast("\nPLAYERS\n#{Klank.table(status)}")
            else
                player.output("\nPLAYERS\n#{Klank.table(status)}")
            end
        end

        private

        def start()
            @dragon = Dragon.new(self)
            @dungeon = Dungeon.new(self)
            @player = Klank.randomize(@player)
            @escalation = 0
            @trigger = -1
            @started = true

            msg = "\nGAME STARTING\nRandomizing play order...\n"
            @player.each_with_index do |p, i|
                msg += "#{i}: #{p.name}\n"
                p.start(self, i)
            end
            broadcast("#{msg}\n")

            @player.each_with_index do |p, i|
                p.clank(3 - i)
            end

            @reserve = {
                x: Deck.new(self, "explore.yml"),
                c: Deck.new(self, "mercenary.yml"),
                t: Deck.new(self, "tome.yml"),
            }

            loop do
                @player.each do |p|
                    begin
                        @dungeon.replenish()

                        break if game_over?()

                        view_players()

                        if @trigger == p.index
                            @escalation += 1

                            if @escalation > 3
                                @game_over = true
                            else
                                broadcast("\n#{p.name} moves to escalation level #{@escalation}!")
                                @dragon.attack()
                            end
                        elsif p.dead?()
                            broadcast("\n#{p.name} is dead!")
                        elsif p.mastery
                            broadcast("\n#{p.name} has left with an artifact!")
                        else
                            broadcast("\nStarting #{p.name}'s turn...")
                            p.turn()
                        end
                    rescue => exception
                        puts exception.full_message
                        broadcast("An error occurred so #{p.name}'s turn is ended prematurely, sorry!")
                    end

                    break if game_over?()
                end

                break if game_over?()
                sleep(0.1)
            end

            broadcast("GAME OVER!")

            scores()
            @dragon.view_bag

            @shutdown = true
        end

        def game_over?()
            all_done = true
            @player.each do |p|
                if !p.dead?() and !p.mastery
                    all_done = false
                    break
                end
            end

            @game_over or all_done
        end

        def scores()
            msg = "Scores\n"
            @player.sort_by { |p| p.score() }.reverse.each_with_index do |p, i|
                msg += "#{p.name}: #{p.score(true)} (Room ##{p.room_num})\n"
            end
            broadcast(msg)
        end
    end
end


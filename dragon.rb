module Klank
    require_relative "utils.rb"

    class Dragon
        DRAW = [2, 2, 3, 3, 4, 4, 5]

        attr_reader :bank

        def initialize(game)
            @game = game

            @level = 4 - @game.num
            @bag = []
            @bank = []
            @dragon_cubes = 0

            30.times do 
                @bag << "D"
            end
        end 

        def anger()
            move_marker(1)
        end

        def move_marker(count)
            @level = [0, [DRAW.count - 1, @level + count].min].max
            @game.broadcast("The dragon marker moves #{(count > 0) ? "up" : "down"} #{count.abs()} space(s) and now draws #{DRAW[@level]}!")
        end

        def add(cube, count = 1)
            count.times do 
                @bank << cube
            end
            @game.broadcast("#{@game.player[cube].name} adds #{count} clank to the bank!")
        end

        def remove(cube, count)
            removed = 0

            if count != 0
                count.times do 
                    if @bank.delete_at(@bank.index(cube) || @bank.length)
                        removed += 1
                    end
                end

                @game.broadcast("#{@game.player[cube].name} removed #{removed} clank from the bank!")
            end

            removed
        end

        def reveal(count)
            @bag = Klank.randomize(@bag)

            @bag[0..([count, @bag.count].min - 1)]
        end

        def attack()
            @bag += @bank 
            @bank = []
            @bag = Klank.randomize(@bag)

            draw = DRAW[@level] + @game.dungeon.danger() + @game.escalation

            view_bag(draw)
            @game.broadcast("The dragon attacks, drawing #{draw} cubes...")
            sleep(1)

            draw.times do
                if @bag.count > 0
                    c = @bag.pop
                    if c == "D"
                        @game.broadcast("The dragon's attack misses!")
                        @dragon_cubes += 1
                    else
                        @game.broadcast("+1 damage to #{@game.player[c].name}!")
                        @game.player[c].damage()
                    end
                    sleep(1)
                else 
                    @game.broadcast("The dragon bag is empty!")
                    break
                end
            end
        end

        def add_dragon_cubes()
            actual = [@dragon_cubes, 3].min 
            actual.times do 
                @bag << "D"
            end
            @dragon_cubes -= actual
            @game.broadcast("#{actual} dragon cube(s) were added back to the dragon bag!")
        end

        def view_bag(draw_count = 0)
            if @bag.length > 0
                cubes = []
                @game.player.each_with_index do |p, i|
                    if (draw_count > 0)
                        cubes << {"PLAYER" => p.name, "COUNT" => @bag.select { |c| c.to_s == i.to_s }.count, "EXPECTED DRAW COUNT" => calculate_expected_draw_count(i.to_s, draw_count)}
                    else
                        cubes << {"PLAYER" => p.name, "COUNT" => @bag.select { |c| c.to_s == i.to_s }.count}
                    end
                end
                if (draw_count > 0)
                    cubes << {"PLAYER" => "Dragon", "COUNT" => @bag.select { |c| c.to_s == "D" }.count, "EXPECTED DRAW COUNT" => calculate_expected_draw_count("D", draw_count)}
                else
                    cubes << {"PLAYER" => "Dragon", "COUNT" => @bag.select { |c| c.to_s == "D" }.count}
                end
                @game.broadcast("\nDRAGON BAG\n#{Klank.table(cubes)}")
            end
        end

        private

        def calculate_outcomes(player, num_draws, num_player_cubes_drawn)
            outcome_count = 0

            @bag.combination(num_draws).to_a.each do |outcome|
                player_count = 0

                outcome.each do |cube|
                    if (cube.to_s == player)
                        player_count += 1
                    end
                end
                
                if (player_count == num_player_cubes_drawn)
                    outcome_count += 1
                end
            end

            return outcome_count
        end

        def calculate_expected_draw_count(player, num_draws)
            result = 0
            num_draws = [num_draws, @bag.count].min

            @bag.select { |c| c.to_s == player }.count.times do |j|
                result += (calculate_outcomes(player, num_draws, j + 1).to_f / Klank.get_combination(@bag.count, num_draws) * (j + 1))
            end

            return result.round(2)
        end
    end
end

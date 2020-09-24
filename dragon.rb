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
            @level = [DRAW.count - 1, @level + 1].min
            @game.broadcast("The dragon is angered and now draws #{DRAW[@level]}!")
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

        def attack()
            @bag += @bank 
            @bank = []
            @bag = Klank.randomize(@bag)

            draw = DRAW[@level] + @game.dungeon.danger() + @game.escalation

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

        def view_bag()
            if @bag.length > 0
                cubes = []
                @game.player.each_with_index do |p, i|
                    cubes << {"PLAYER" => p.name, "COUNT" => @bag.select { |c| c.to_s == i.to_s }.count}
                end
                cubes << {"PLAYER" => "Dragon", "COUNT" => @bag.select { |c| c.to_s == "D" }.count}
                @game.broadcast("\nDRAGON BAG\n#{Klank.table(cubes)}")
            end
        end
    end
end

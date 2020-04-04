module Klank
    require_relative "utils.rb"

    class Dragon
        DRAW = [2, 2, 3, 3, 4, 4, 5]

        def initialize(game)
            @game = game

            @anger = 4 - @game.num
            @bag = []
            @bank = []
            @dragon_cubes = 0

            30.times do 
                @bag << "D"
            end
        end 

        def anger()
            @anger = [DRAW.count - 1, anger + 1].min
            @game.broadcast("The dragon is angered and now draws #{DRAW[@anger]}!")
        end

        def add(cube, count = 1)
            count.times do 
                @bank << cube
                @game.broadcast("#{@game.player[cube].name} adds a clank to the bank!")
            end
        end

        def remove(cube, count)
            removed = 0

            count.times do 
                if @bank.delete_at(@bank.index(cube) || @bank.length)
                    @game.broadcast("#{@game.player[cube].name} removes a clank from the bank!")
                end
            end
        end

        def attack()
            @bag += @bank 
            @bank = []
            @bag = Klank.randomize(@bag)

            draw = DRAW[@anger] + @game.dungeon.danger() + @game.escalation

            msg = ["The dragon attacks, drawing #{draw} cubes..."]
            draw.times do
                c = @bag.pop
                if c == "D"
                    msg << "The dragon's attack misses!"
                    @dragon_cubes += 1
                else
                    msg << "+1 damage to #{@game.player[c].name}!"
                    @game.player[c].damage()
                end
            end
            @game.broadcast(msg.join("\n"))
        end

        def add_dragon_cubes()
            actual = [@dragon_cubes, 3].min 
            actual.times do 
                @bag << "D"
            end
            @dragon_cubes -= actual
        end
    end
end

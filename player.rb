module Klank
    require_relative "deck.rb"

    class Player
        FULL_HEALTH = 10

        attr_reader :name
        attr_reader :index
        attr_reader :deck

        attr_accessor :played
        attr_accessor :item
        attr_accessor :mastery
        attr_accessor :room_num
        attr_accessor :skill
        attr_accessor :attack
        attr_accessor :move
        attr_accessor :coins
        attr_accessor :teleport
        attr_accessor :frozen
        attr_accessor :artifact

        def initialize(client)
            @client = client

            @name = input("Name")
            output("Welcome to Klank, #{@name}!")
        end

        def input(msg)
            @client.write "#{msg }: "
            resp = @client.gets.strip

            resp
        end

        def input_num(msg, range)
            n = 0

            loop do 
                n = input("#{msg} [#{range.min}, #{range.max}]")
                break if n =~ /^\d+/ and range.include?(n.to_i)
                output("Oops!")
            end

            return n.to_i
        end

        def output(msg)
            @client.puts "#{msg}"
        end

        def menu(title, options)
            choice = options[0][0]

            if options.count > 1
                msg = ["\n#{title}"]
                options.each do |o|
                    msg << "#{o[0]}: #{o[1]}"
                end
                output(msg.join("\n"))
                
                loop do
                    choice = input("Choose an option").upcase
                    break if options.any? { |o| o[0].to_s.upcase == choice }
                    output("Oops!")
                end
            end

            choice
        end

        def start(game, index)
            @game = game
            @deck = Deck.new(@game, "player.yml")
            @mastery = false
            @coins = 0
            @cubes = 30
            @health = FULL_HEALTH
            @index = index
            @artifact = []
            @item = []
            @played = []
            @room_num = 1
            @skill = 0
        end

        def score()
            msg = []

            total = @coins
            msg << sprintf("%-4s | %s", @coins.to_s, "Coins")

            @deck.all.each do |card|
                total += card.points(self)
                msg << sprintf("%-4s | %s", card.points(self).to_s, card.name)
            end

            @item.each do |i|
                total += i.points()
                if i.points() != 0
                    msg << sprintf("%-4s | %s", i.points().to_s, i.name)
                end
            end

            @artifact.each do |a|
                total += a
                msg << sprintf("%-4s | %s", a.to_s, "Artifact")
            end

            if @mastery 
                total += 20
                msg << sprintf("%-4s | %s", 20.to_s, "Mastery")
            end
            msg << "----"
            msg << sprintf("%-4s | %s", total.to_s, "Total")
            output(msg.join("\n"))

            total
        end

        def draw(count)
            output("\nDrawing cards...")
            cards = @deck.draw(count)
            @hand += cards
            @new_cards = true
        end

        def turn()
            @hand = []
            @played = []
            @skill = 0
            @move = 0
            @attack = 0
            @teleport = 0
            @clank_added = 0
            @clank_remove = 0
            @frozen = false

            @game.broadcast("HEALTH: #{@health} | CLANK: #{@cubes} | COINS: #{@coins} | ARTIFACT: #{@artifact.count} | ROOM: #{@room_num}")

            draw(5)

            loop do 
                if @new_cards
                    @new_cards = false 
                    equip()
                else 
                    output_abilities()

                    menu = []

                    if @hand.count != 0
                        menu << ["E", "Equip card(s)"]
                    end

                    if @item.select{ |i| i.playable }.count != 0
                        menu << ["I", "Play an item"]
                    end

                    if (@game.reserve[:x].remaining > 0) and (@skill >= @game.reserve[:x].peek.cost)
                        menu << ["X", "Buy an explore card"]
                    end

                    if (@game.reserve[:c].remaining > 0) and (@skill >= @game.reserve[:c].peek.cost)
                        menu << ["C", "Buy a mercenary card"]
                    end

                    if (@game.reserve[:t].remaining > 0) and (@skill >= @game.reserve[:t].peek.cost)
                        menu << ["T", "Buy a tome card"]
                    end

                    if @skill > 0
                        menu << ["B", "Buy a card from the dungeon"]
                    end

                    if (@move > 0) and !@frozen
                        menu << ["M", "Move"]
                    end

                    if @game.map.market?(self) and (@coins >= 7)
                        menu << ["S", "Shop in the market"]
                    end

                    if @teleport > 0 
                        menu << ["P", "Teleport"]
                    end

                    if @attack > 0
                        menu << ["A", "Attack a monster from the dungeon"]
                    end

                    if @attack > 1
                        menu << ["G", "Kill the goblin"]
                    end

                    if @hand.count == 0
                        menu << ["D", "End Turn"]
                    end

                    option = menu("ACTION LIST", menu)
                    
                    case option
                    when "E"
                        equip()
                    when "I"
                        play()
                    when "X"
                        x = @game.reserve[:x].draw(1)
                        @deck.discard(x)
                        @skill -= x[0].cost
                        @game.broadcast("#{@name} bought an Explore!")
                    when "C"
                        c = @game.reserve[:c].draw(1)
                        @deck.discard(c)
                        @skill -= c[0].cost
                        @game.broadcast("#{@name} bought a Mercenary!")
                    when "T"
                        t = @game.reserve[:t].draw(1)
                        @deck.discard(t)
                        @skill -= t[0].cost
                        @game.broadcast("#{@name} bought a Tome!")
                    when "B"
                        card = @game.dungeon.buy(self)
                        if card 
                            if card.type != :device
                                @deck.discard([card])
                            end
                            @game.broadcast("#{@name} bought #{card.name} from the dungeon!")
                        end
                    when "M"
                        @game.map.move(self)
                    when "S"
                        @game.map.shop(self)
                    when "P"
                        @game.map.teleport(self)
                    when "A"
                        card = @game.dungeon.monster(self)
                        if card 
                            @game.broadcast("#{@name} killed #{card.name} in the dungeon!")
                        end
                    when "G"
                        collect_coins(1)
                        @attack -= 2
                    when "D"
                        @deck.discard(@played)
                        @played = []
                        break
                    else
                        output("Hmmm... something went wrong")
                    end

                    break if dead?() or @mastery
                end
            end

            @game.dragon.remove(@index, -1 * @clank_remove)
        end

        def damage(direct = false)
            @health -= 1
            if direct 
                @cubes -= 1
            end
            if dead?()
                @game.broadcast("#{@name} has died!")
                trigger_end(player)
            end
        end

        def heal(count = 1)
            if count > 0
                actual = [FULL_HEALTH - @health, count].min

                @cubes += actual
                @health = [FULL_HEALTH, @health + count].min
                @game.broadcast("#{@name} healed #{actual}, their health is #{@health}!")
            end
        end

        def dead?()
            @health <= 0
        end

        def clank(count = 1)
            if count > 0
                actual = [@cubes, count].min 
                @cubes -= actual 
                @game.dragon.add(@index, actual)
                swagger = @played.select { |c| c.name == "Swagger" }.count
                if swagger != 0
                    @game.broadcast("#{@name} gained #{swagger} because of their Swagger!")
                    @skill += swagger 
                end
            else
                @clank_remove += count
            end
        end

        def has_artifact?()
            @artifact.count > 0
        end

        def trash_card(card = nil)
            if !card
                cards = []
                (@played + @deck.pile).each_with_index do |c, i|
                    cards << [i, c.name]
                end 
                cards << ["N", "Don't trash a card"]
                c = menu("TRASH A CARD", cards)
                card = (c != "N") ? cards[c.to_i][1] : ""
            end

            if card != ""
                if @played.delete_at(@played.index { |c| c.name == card } || @played.length)
                    @game.broadcast("#{@name} trashed #{card} from their play area!")
                elsif @deck.pile.delete_at(@deck.pile.index { |c| c.name == card } || @deck.pile.length)
                    @game.broadcast("#{@name} trashed #{card} from their discard pile!")
                else
                    output("Could not trash a #{card}!")
                end
            end 

            card != ""
        end

        def discard_card()
            cards = []
            @hand.each_with_index do |c, i|
                cards << [i, c.play_desc]
            end
            cards << ["N", "None of the cards"]
            c = menu("DISCARD", cards)

            if c != "N"
                @deck.discard([@hand.delete_at(c.to_i)])
            end

            c != "N"
        end

        def has_item?(item)
            @item.any? { |i| i.name == item }
        end

        def has_played?(card)
            @played.any? { |c| c.name == card }
        end

        def collect_coins(count)
            @coins += count 

            extra = @played.select { |c| c.name == "Search" }.count
            if extra != 0
                @coins += extra
                @game.broadcast("#{@name} collects #{count} coin(s) +#{extra} for Search!")
            else
                @game.broadcast("#{@name} collects #{count} coin(s)!")
            end
        end

        def hold_artifact?()
            hold = @item.select { |i| i.name == "Backpack" }.count + 1
            (@artifact.count < hold)
        end

        private 

        def output_abilities()
            string = []

            if @skill != 0
                string << "SKILL: #{@skill}"
            end 

            if @move != 0
                string << "MOVE: #{@move}"
            end 

            if @attack != 0
                string << "ATTACK: #{@attack}"
            end

            if @coins != 0
                string << "COINS: #{@coins}"
            end

            if @teleport != 0
                string << "TELEPORT: #{@teleport}"
            end

            if string.count > 0
                output("\n" + string.join(" | "))
            end
        end

        def equip()
            cards = []
            @hand.each_with_index do |c, i|
                cards << [i, c.play_desc]
            end
            cards << ["A", "All of the cards"]
            cards << ["N", "None of the cards"]
            c = menu("HAND", cards)

            play = []

            if c == "A"
                play = @hand 
                @hand = []
            elsif c == "N"
                # do nothing
            else
                play = [@hand.delete_at(c.to_i)]
            end

            @played += play

            msg = []

            play.each do |card|
                card.equip(self)
                msg << "#{card.name}"
            end

            @game.broadcast("#{@name} played #{msg.join(", ")}!")
        end

        def play()

            loop do 
                items = []
                lookup = []
                @item.each_with_index do |item, i|
                    if item.playable
                        items << [lookup.count, item.desc()]
                        lookup << i
                    end
                end
                items << ["N", "None of the items"]
                i = menu("ITEMS", items)

                if i != "N"
                    if @item[lookup[i.to_i]].play(self)
                        @item.delete_at(lookup[i.to_i])
                        break if (@item.count == 0)
                    else 
                        output("Item not played!")
                    end
                else 
                    break
                end
            end
        end
    end
end
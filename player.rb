module Klank
    require_relative "deck.rb"
    require_relative "utils.rb"

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
        attr_accessor :health

        def initialize(client)
            @client = client

            @name = input("Name")
            output("Welcome to Klank, #{@name}!")
        end

        def input(msg)
            @client.write "#{msg }: "
            resp = ""

            loop do
                char = @client.recv(1)

                if (char == "\n") or (char == "\r")
                    if resp.length > 0
                        break
                    end
                elsif char =~ /(\w|\s)/
                    resp += char
                end
            end

            puts resp.strip

            resp.strip || ""
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
            @client.puts "#{msg.gsub("\n", "\r\n")}\r"
        end

        def menu(title, options, none = false, all = false)
            choice = none ? "N" : options[0][0]

            if (options.count > 1) or ((options.count > 0) and none)
                table = []
                options.each do |o|
                    row = {"#" => o[0]}
                    if o[1].is_a?(Hash)
                        row.merge!(o[1])
                    else
                        row["DESC"] = o[1]
                    end
                    table << row
                end
                output("\n#{title}\n#{Klank.table(table)}")

                valid = options.map { |o| o[0] }
                valid << "N" if none
                valid << "A" if all

                loop do
                    choice = input("Choose an option#{none ? " (N: None)" : ""}#{all ? " (A: All)" : ""}").upcase
                    break if valid.any? { |v| v.to_s.upcase == choice }
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

        def score(disp_breakdown = false)
            table = []

            total = @coins
            table << {"POINTS" => @coins, "DESCRIPTION" => "Coins"}

            @deck.all.each do |card|
                points = card.points(self)

                if points != 0
                    total += points
                    table << {"POINTS" => points, "DESCRIPTION" => card.name}
                end
            end

            @item.each do |i|
                points = i.points()

                if points != 0
                    total += points
                    table << {"POINTS" => points, "DESCRIPTION" => i.name}
                end
            end

            @artifact.each do |a|
                total += a
                table << {"POINTS" => a, "DESCRIPTION" => "Artifact"}
            end

            if @mastery
                total += 20
                table << {"POINTS" => 20, "DESCRIPTION" => "Mastery"}
            end

            if !@game.game_over
                # keep the score for now
            elsif @artifact.count <= 0
                table << {"POINTS" => -1 * total, "DESCRIPTION" => "No artifact"}
                total = 0
            elsif @game.map.depths?(self)
                table << {"POINTS" => -1 * total, "DESCRIPTION" => "Depths"}
                total = 0
            end

            table << {"POINTS" => total, "DESCRIPTION" => "Total"}

            if disp_breakdown
                output(Klank.table(table))
            end

            total
        end

        def draw(count)
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

            output("\a")

            draw(5)

            loop do
                if @new_cards
                    @new_cards = false
                    equip()
                else
                    output_abilities()

                    menu = []

                    if @hand.count != 0
                        menu << ["E", {"DESC" => "Equip card(s)"}]
                    end

                    if @item.select{ |i| i.playable }.count != 0
                        menu << ["I", {"DESC" => "Play an item"}]
                    end

                    if (@game.reserve[:x].remaining > 0) and (@skill >= @game.reserve[:x].peek.cost)
                        menu << ["X", {"DESC" => "Buy an explore card", "COST" => 3, "BENEFIT" => "SKILL: 2 | MOVE: 1", "LEFT" => @game.reserve[:x].remaining}]
                    end

                    if (@game.reserve[:c].remaining > 0) and (@skill >= @game.reserve[:c].peek.cost)
                        menu << ["C", {"DESC" => "Buy a mercenary card", "COST" => 2, "BENEFIT" => "SKILL: 1 | ATTACK: 2", "LEFT" => @game.reserve[:c].remaining}]
                    end

                    if (@game.reserve[:t].remaining > 0) and (@skill >= @game.reserve[:t].peek.cost)
                        menu << ["T", {"DESC" => "Buy a tome card", "COST" => 7, "BENEFIT" => "POINTS: 7", "LEFT" => @game.reserve[:t].remaining}]
                    end

                    if @game.dungeon.afford?(self)
                        menu << ["D", {"DESC" => "Go to the dungeon"}]
                    end

                    if (@move > 0) and !@frozen
                        menu << ["M", {"DESC" => "Move"}]
                    end

                    if @game.map.market?(self)
                        menu << ["S", {"DESC" => "Shop in the market"}]
                    end

                    if @teleport > 0
                        menu << ["P", {"DESC" => "Teleport"}]
                    end

                    if @attack > 1
                        menu << ["G", {"DESC" => "Kill the goblin", "COST" => 2, "BENEFIT" => "COINS: 1"}]
                    end

                    if menu.length > 0
                        menu << ["V", {"DESC" => "View the map"}]
                    end

                    if @hand.count == 0
                        menu << ["N", {"DESC" => "End Turn"}]
                    end

                    option = menu("ACTION LIST", menu)

                    case option
                    when "E"
                        equip()
                    when "I"
                        play()
                    when "X"
                        @game.broadcast("#{@name} bought an Explore!")
                        x = @game.reserve[:x].draw(1)
                        @deck.discard(x)
                        @skill -= x[0].cost
                    when "C"
                        @game.broadcast("#{@name} bought a Mercenary!")
                        c = @game.reserve[:c].draw(1)
                        @deck.discard(c)
                        @skill -= c[0].cost
                    when "T"
                        @game.broadcast("#{@name} bought a Tome!")
                        t = @game.reserve[:t].draw(1)
                        @deck.discard(t)
                        @skill -= t[0].cost
                    when "D"
                        @game.dungeon.acquire(self)
                    when "M"
                        @game.map.move(self)
                    when "S"
                        @game.map.shop(self)
                    when "P"
                        @game.map.teleport(self)
                    when "V"
                        @game.map.view(self)
                    when "G"
                        @game.broadcast("#{@name} killed the Goblin!")
                        collect_coins(1)
                        @attack -= 2
                    when "N"
                        if (menu.count <= 1) or ("Y" == input("Are you sure? (Y: yes)").upcase)
                            break
                        end
                    else
                        output("Hmmm... something went wrong")
                    end

                    break if dead?() or @mastery
                end
            end

            @deck.discard(@played)
            @played = []

            reclaim_clank()
        end

        def damage(direct = false)
            if @mastery
                @game.broadcast("#{@name} can't take damage he has left!")
            elsif dead?()
                @game.broadcast("#{@name} can't take damage he is already dead!")
            else
                @health -= 1
                if direct
                    @cubes -= 1
                end
                if dead?()
                    @game.broadcast("#{@name} has died!")
                    @game.trigger_end(self)
                end
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
            if @mastery
                @game.broadcast("#{@name} can't add clank he has left!")
            elsif dead?()
                @game.broadcast("#{@name} can't add clank he is already dead!")
            elsif count > 0
                actual = [@cubes, count].min
                @cubes -= actual
                @game.dragon.add(@index, actual)
                swagger = @played.select { |c| c.name == "Swagger" }.count
                if swagger != 0
                    @game.broadcast("#{@name} gained #{swagger} skill because of their Swagger!")
                    @skill += swagger
                end
            elsif count < 0
                @clank_remove += count
            end
        end

        def reclaim_clank()
            actual = @game.dragon.remove(@index, -1 * @clank_remove)
            @clank_remove += actual
            @cubes += actual
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
                c = menu("TRASH A CARD", cards, true)
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
            c = menu("DISCARD", cards, true)

            if c != "N"
                card = @hand.delete_at(c.to_i)
                @deck.discard([card])
                @game.broadcast("#{@name} discarded #{card.name}!")
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

        def status()
            {
                "NAME" => @name,
                "HEALTH" => dead?() ? "DEAD" : @mastery ? "OUT" : @health,
                "CLANK" => @cubes,
                "BANK" => @game.dragon.bank.select { |c| c == @index }.count,
                "COINS" => @coins,
                "ARTIFACT" => @artifact.join(", "),
                "ITEM" => @item.map { |i| i.symbol }.join(""),
                "ROOM" => @room_num,
                "DECK" => "#{@deck.stack.count}/#{@deck.all.count}",
                "SCORE" => score()
            }
        end

        private

        def output_abilities()
            ability = {}

            if @skill != 0
                ability["SKILL"] = @skill
            end

            if @move != 0
                ability["MOVE"] = @move
            end

            if @attack != 0
                ability["ATTACK"] = @attack
            end

            if @coins != 0
                ability["COINS"] = @coins
            end

            if @teleport != 0
                ability["TELEPORT"] = @teleport
            end

            if @clank_remove < 0
                ability["CLANK"] = @clank_remove
            end

            if ability.keys.count > 0
                output("\n" + Klank.table([ability]))
            end
        end

        def equip()
            loop do
                cards = []
                @hand.each_with_index do |c, i|
                    cards << [i, c.play_desc]
                end
                c = menu("HAND", cards, true, true)

                play = []

                if c == "A"
                    play = @hand
                    @hand = []
                elsif c == "N"
                    break
                else
                    play = [@hand.delete_at(c.to_i)]
                end

                @played += play

                if play.count > 0
                    msg = []

                    play.each do |card|
                        card.equip(self)
                        msg << "#{card.name}"
                    end

                    @game.broadcast("#{@name} played #{msg.join(", ")}!")
                end

                if play.select { |c| c.name == "Stumble" }.count == 2
                    @game.broadcast("#{@name} stumbled twice and faceplanted!")
                end

                break if @hand.count == 0
            end
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
                i = menu("ITEMS", items, true)

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

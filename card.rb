module Klank
    class Card

        attr_reader :name
        attr_reader :type
        attr_reader :cost
        attr_reader :attack
        attr_reader :danger
        attr_reader :dragon
        attr_reader :play_count

        attr_accessor :num_times_discarded

        def initialize(game, hash)
            @game = game

            @name = hash["name"]
            @type = hash["type"] || ""
            @cost = hash["cost"] || 1000000
            @attack = hash["attack"] || 1000000
            @special = hash["special"] || ""
            @danger = hash.key?("danger")
            @dragon = hash.key?("dragon")
            @play_count = 0
            @num_times_discarded = 0

            @hash = hash
        end

        def player_cost(player, pickpocket = false)
            cost = 0

            if (@type == :gem) and player.has_played?("Gem Collector")
                cost = @cost - 2
            elsif !pickpocket
                cost = @cost
            end

            cost
        end

        def points(player)
            total = 0

            if @hash.key?("points")
                total += @hash["points"].to_i
            end

            case @name
            when "Dragon's Eye"
                if player.mastery
                    total += 10
                end
            when "Dwarven Peddler"
                things = 0
                if player.has_item?("Chalice")
                    things += 1
                end
                if player.has_item?("Dragon Egg")
                    things += 1
                end
                if player.has_item?("Monkey Idol")
                    things += 1
                end
                if things >= 2
                    total += 4
                end
            when "Grand Plan"
                things = 0
                
                things += player.item_count("Backpack")
                things += player.item_count("Crown (10)")
                things += player.item_count("Crown (9)")
                things += player.item_count("Crown (8)")
                things += player.item_count("Master Key")
                things += player.item_count("Scuba")

                if things >= 3
                    total += 7
                end
            when "The Duke"
                total += (player.coins / 5)
            when "Wizard"
                total += (player.deck.active_cards.select { |c| c.name == "Tome" }.count * 2)
            end

            total
        end

        def arrive()
            case @name
            when "Eye-in-the-Water", "Friendly Watcher", "Overlord", "Watcher"
                @game.player.each do |p|
                    p.clank(@name == "Eye-in-the-Water" ? 2 : 1)
                end
            when "Shrine"
                @game.dragon.add_dragon_cubes()
            end
        end

        def acquire(player, pickpocket = false)
            success = false
            cost = player_cost(player, pickpocket)

            if @type == :monster
                player.output("Can't buy a monster!")
            elsif @hash.key?("depths") and !@game.map.depths?(player)
                player.output("Must be in the depths to acquire!")
            elsif player.skill >= cost
                success = true

                case @name
                when "Door to Before"
                    player.door_before_teleport += 1
                when "Dragon Shrine"
                    menu = [
                        ["C", {"DESC" => "+2 coins", "COINS" => player.coins}],
                        ["T", {"DESC" => "Trash a card"}]
                    ]
                    loop do
                        case player.menu("DRAGON SHRINE", menu, true)

                        when "C"
                            player.collect_coins(2)
                            break
                        when "T"
                            break if player.trash_card()
                        else
                            success = false
                            break
                        end
                    end
                when "Pipe Organ"
                    menu = [["U", "Move the Dragon marker one space up"], ["D", "Move the Dragon marker one space down"]]
                    @game.dragon.move_marker(player.menu("PIPE ORGAN", menu) == "U" ? 1 : -1)
                when "Shrine"
                    menu = [
                        ["C", {"DESC" => "+1 coin", "CURRENT" => player.coins}],
                        ["H", {"DESC" => "+1 health", "CURRENT" => player.health}]
                    ]
                    case player.menu("SHRINE", menu, true)
                    when "C"
                        player.collect_coins(1)
                    when "H"
                        player.heal(1)
                    else
                        success = false
                    end
                when "Shrine of the Mermaid"
                    menu = [["C", "2 coins"], ["T", "Teleport to an adjacent room"]]
                    if player.menu("SHRINE OF THE MERMAID", menu) == "C"
                        player.collect_coins(2)
                    else
                        player.shrine_mermaid_teleport += 1
                    end
                when "Snack Table"
                    @game.player.select { |p| p.coins > 0 and p != player and !p.dead?() and !p.mastery}.each do |p|
                        if ("Y" == p.input("Do you want to pay #{player.name} 1 coin for +1 heal? (Y: yes)").upcase)
                            @game.broadcast("#{p.name} paid #{player.name} 1 coin for +1 heal")
                            p.coins -= 1
                            player.coins += 1
                            p.heal(1)
                        end
                    end
                when "Wishing Well"
                    actions = 0
                    menu = [
                        ["A", {"DESC" => "+2 attack", "CURRENT" => player.attack}],
                        ["H", {"DESC" => "+1 health", "CURRENT" => player.health}],
                        ["M", {"DESC" => "+2 move", "CURRENT" => player.move}],
                        ["T", {"DESC" => "Trash a card"}]
                    ]
                    loop do
                        case player.menu("WISHING WELL", menu, true)

                        when "A"
                            @game.broadcast("#{player.name} gained +2 attack!")
                            player.attack += 2
                            if (actions == 0)
                                menu.delete_at(0)
                            end
                            actions += 1
                        when "H"
                            player.heal(1)
                            if (actions == 0)
                                menu.delete_at(1)
                            end
                            actions += 1
                        when "M"
                            @game.broadcast("#{player.name} gained +2 move!")
                            player.move += 2
                            if (actions == 0)
                                menu.delete_at(2)
                            end
                            actions += 1
                        when "T"
                            player.trash_card()
                            if (actions == 0)
                                menu.delete_at(3)
                            end
                            actions += 1
                        when "N"
                            break
                        end

                        break if (actions == 2)
                    end
                end

                if success
                    player.skill -= cost

                    if @hash.key?("acquire")
                        abilities(player, @hash["acquire"])
                    end
                end
            else
                player.output("Not enough skill!")
            end

            success
        end

        def defeat(player)
            success = false

            if @type != :monster
                player.output("That's not a monster!")
            elsif @hash.key?("depths") && !@game.map.depths?(player)
                player.output("Must be in the depths to defeat!")
            elsif @hash.key?("crystal cave") && !@game.map.crystal_cave?(player)
                player.output("Must be in a crystal cave to defeat!")
            elsif @name == "Crystal Fish" && !@game.map.crystal_cave?(player) && !@game.map.flooded?(player)
                player.output("Must be in a crystal cave or flooded room to defeat!")
            elsif player.attack >= @attack
                success = true

                player.attack -= @attack
                player.num_monsters_killed += 1
                player.num_damage_dealt += @attack

                case @name
                when "Eye-in-the-Water"
                    menu = [["C", "-2 clank"], ["S", "+2 Coins"]]
                    if player.menu("EYE-IN-THE-WATER", menu) == "S"
                        player.collect_coins(2)
                    else
                        player.clank(-2)
                        @game.broadcast("#{player.name} gained -2 clank from defeating Eye-in-the-Water!")
                    end
                when "Watcher"
                    @game.broadcast("All other players +1 clank")
                    @game.player.each do |p|
                        if p.index != player.index
                            p.clank(1)
                        end
                    end
                end

                if @hash.key?("defeat")
                  abilities(player, @hash["defeat"])
                end
            else
                player.output("Not enough attack!")
            end

            success
        end

        def equip(player)
            case @name
            when "Alchemist"
                if player.has_played?("Tome") or player.deck.pile.any? { |c| c.name == "Tome" }
                    player.collect_coins(2)
                end
            when "Apothecary"
                if player.discard_card()
                    menu = [
                        ["A", {"DESC" => "+3 attack", "CURRENT" => player.attack}],
                        ["C", {"DESC" => "+2 coins", "CURRENT" => player.coins}],
                        ["H", {"DESC" => "+1 health", "CURRENT" => player.health}]
                    ]
                    case player.menu("APOTHECARY", menu)
                    when "A"
                        player.attack += 3
                        @game.broadcast("#{player.name} gained +3 attack from Apothecary!")
                    when "C"
                        player.collect_coins(2)
                    when "H"
                        player.heal(1)
                    end
                end
            when "Archaeologist"
                if player.has_item?("Monkey Idol")
                    player.skill += 2
                end
            when "Aspiration"
                if player.has_item?("Crown (10)") or player.has_item?("Crown (9)") or player.has_item?("Crown (8)")
                    player.draw(1)
                end
            when "Brawn vs Boots"
                menu = [["A", "+2 Attack"], ["M", "+2 Move"]]
                if player.menu("BRAWN VS BOOTS", menu) == "A"
                    player.attack += 2
                else
                    player.move += 2
                end
            when "Burglar's Boots"
                menu = [["C", "-2 clank"], ["M", "+1 Move"], ["S", "+1 Coin"]]
                case player.menu("BURGLAR'S BOOTS", menu)
                when "C"
                    player.clank(-2)
                when "M"
                    player.move += 1
                when "S"
                    player.collect_coins(1)
                end
            when "Climbing Gear"
                if player.discard_card()
                    player.move += 1
                end
            when "Deep Dive"
                if ((player.hand.length >= 3) and player.discard_card(3))
                    player.draw(5)
                end
            when "Dire Wolf"
                count = @game.dungeon.hand.select { |c| c.type == :monster }.count + 1 + (@game.sunken_treasures ? 1 : 0)  #+1 for Goblin and +1 for Goldfish
                player.clank(count)
                player.attack += count
            when "Enchanted Dice"
                @game.dragon.reveal(2).each do |c|
                    if c.to_s == "D"
                        @game.broadcast("A dragon cube was revealed.")
                        player.collect_coins(1)
                    else
                        @game.broadcast("#{@game.player[c.to_i].name}'s cube was revealed.")
                        if (@game.player[c.to_i] == player)
                            player.collect_coins(1)
                        end
                    end
                end
            when "Fishing Pole"
                player.draw(1)
                player.discard_card(1, true)
            when "Friendly Watcher", "Tattle"
                @game.broadcast("All other players +1 clank")
                @game.player.each do |p|
                    if p.index != player.index
                        p.clank(1)
                    end
                end
            when "Kobold Merchant"
                if player.has_artifact?()
                    player.skill += 2
                end
            when "Magic Spectacles"
                if player.deck.remaining() == 0
                    player.deck.reshuffle(player, @game)
                end

                player.output("\nTOP CARD OF DECK\n#{Klank.table([player.deck.peek.play_desc])}")

                menu = [["T", "Keep card at top of deck"], ["B", "Move card to bottom of deck"]]
                if player.menu("MAGIC SPECTACLES", menu) == "T"
                    @game.broadcast("#{player.name} kept the top card of their deck at the top!")
                else
                    @game.broadcast("#{player.name} moved the top card of their deck to the bottom!")
                    player.move_card_to_bottom
                end

                player.draw(1)
            when "Master Burglar"
                player.trash_card("Burgle")
            when "Medic"
                if player.discard_card()
                    player.heal(1)
                end
            when "Mister Whiskers"
                @game.broadcast("#{player.name} played Mister Whiskers!")
                menu = [["D", "Dragon Attack"], ["C", "-2 clank"]]
                if player.menu("MISTER WHISKERS", menu) == "D"
                    player.reclaim_clank()
                    @game.dragon.attack()
                else
                    player.clank(-2)
                    @game.broadcast("#{player.name} gained -2 clank from Mister Whiskers!")
                end
            when "Pickpocket"
                @game.dungeon.pickpocket(player, 3, false)
            when "Rebel Brawler", "Rebel Captain", "Rebel Miner", "Rebel Scholar", "Rebel Scout", "Rebel Soldier"
                if player.played.any? { |c| (c.type == :companion) and (c.name != @name) }
                    player.draw(1)
                end
            when "Siren"
                @game.dungeon.pickpocket(player, 1000000, true)
            when "Sleight of Hand", "Black Pearl", "Silver Pearl", "White Pearl"
                if player.discard_card()
                    player.draw(2)
                end
            when "The Mountain King"
                if player.has_item?("Crown (10)") or player.has_item?("Crown (9)") or player.has_item?("Crown (8)")
                    player.attack += 1
                    player.move += 1
                end
            when "The Queen of Hearts"
                if player.has_item?("Crown (10)") or player.has_item?("Crown (9)") or player.has_item?("Crown (8)")
                    player.heal(1)
                end
            when "Treasure Hunter"
                @game.dungeon.replace_card(player)
            when "Underworld Dealing"
                remaining = @game.reserve[:t].remaining
                if (player.coins < 7) or (remaining == 0)
                    player.collect_coins(1)
                else
                    menu = [["C", "1 coin"], ["T", "7 coins for #{[2, remaining].min} Tomes. There are #{@game.reserve[:t].remaining} Tome(s) left!"]]
                    if player.menu("UNDERWORLD DEALING", menu) == "C"
                        player.collect_coins(1)
                    else
                        player.coins -= 7
                        @game.map.bank += 7
                        player.tome(2)
                        @game.broadcast("Through some Underworld Dealing, #{player.name} gained +#{[2, remaining].min} Tome(s)! There are #{@game.reserve[:t].remaining} Tome(s) left!")
                    end
                end
            when "Wand of Recall"
                if player.has_artifact?()
                    player.teleport += 1
                end
            when "Wand of Time"
                if player.deck.pile.count == 0
                    player.draw(2)
                else
                    player.retrieve_card_from_discard()
                end
            when "Wand of Wind"
                loop do
                    menu = [["T", "Teleport to an adjacent room"], ["S", "Take a secret from an adjacent room"]]
                    if player.menu("WAND OF WIND", menu) == "T"
                        player.teleport += 1
                        break
                    elsif @game.map.take_adjacent_secret(player)
                        break
                    end
                end
            end

            if @hash.key?("equip")
                abilities(player, @hash["equip"])
            end

            @play_count += 1
        end

        def play_desc()
            desc = {"NAME" => @name, "TYPE" => @type.to_s.upcase}

            if @hash.key?("equip")
                if @hash["equip"].key?("skill")
                    desc["SKILL"] = @hash["equip"]["skill"]
                end
                if @hash["equip"].key?("move")
                    desc["MOVE"] = @hash["equip"]["move"]
                end
                if @hash["equip"].key?("attack")
                    desc["ATTACK"] = @hash["equip"]["attack"]
                end
                if @hash["equip"].key?("teleport")
                    desc["MISC"] = "TELEPORT"
                end
                if @hash["equip"].key?("coins")
                    desc["COINS"] = @hash["equip"]["coins"]
                end
                if @hash["equip"].key?("draw")
                    desc["DRAW"] = @hash["equip"]["draw"]
                end
                if @hash["equip"].key?("clank")
                    desc["CLANK"] = @hash["equip"]["clank"]
                end
                if @hash["equip"].key?("heal")
                    desc["HEAL"] = @hash["equip"]["heal"]
                end
            end

            if @hash.key?("special")
                desc["SPECIAL"] = @special
            end

            desc
        end

        def buy_desc(gem_collector)
            desc = {"NAME" => @name, "TYPE" => @type.to_s.upcase}

            if @hash.key?("cost")
                cost = 0

                if (@type == :gem) and gem_collector
                    cost = @cost - 2
                else
                    cost = @cost
                end

                desc["COST"] = cost
            end

            if @hash.key?("attack")
                desc["COST"] = @hash["attack"]
            end

            if @hash.key?("points")
                desc["POINTS"] = @hash["points"]
            end

            if @hash.key?("acquire")
                acquire = []

                if @hash["acquire"].key?("skill")
                    acquire << "SKILL: #{@hash["acquire"]["skill"]}"
                end
                if @hash["acquire"].key?("move")
                    acquire << "MOVE: #{@hash["acquire"]["move"]}"
                end
                if @hash["acquire"].key?("attack")
                    acquire << "ATTACK: #{@hash["acquire"]["attack"]}"
                end
                if @hash["acquire"].key?("teleport")
                    acquire << "TELEPORT"
                end
                if @hash["acquire"].key?("coins")
                    acquire << "COINS: #{@hash["acquire"]["coins"]}"
                end
                if @hash["acquire"].key?("clank")
                    acquire << "CLANK: #{@hash["acquire"]["clank"]}"
                end
                if @hash["acquire"].key?("heal")
                    acquire << "HEAL: #{@hash["acquire"]["heal"]}"
                end

                desc["ACQUIRE"] = "#{acquire.join(", ")}"
            end

            if @hash.key?("defeat")
                if @hash["defeat"].key?("skill")
                    desc["SKILL"] = @hash["defeat"]["skill"]
                end
                if @hash["defeat"].key?("move")
                    desc["MOVE"] = @hash["defeat"]["move"]
                end
                if @hash["defeat"].key?("coins")
                    desc["COINS"] = @hash["defeat"]["coins"]
                end
                if @hash["defeat"].key?("draw")
                    desc["DRAW"] = @hash["defeat"]["draw"]
                end
                if @hash["defeat"].key?("clank")
                    desc["CLANK"] = @hash["defeat"]["clank"]
                end
                if @hash["defeat"].key?("heal")
                    desc["HEAL"] = @hash["defeat"]["heal"]
                end
                if @hash["defeat"].key?("tomes")
                    desc["TOMES"] = @hash["defeat"]["tomes"]
                end
            end

            if @danger
                desc["MISC"] = "DANGER"
            end

            if @hash.key?("depths")
                desc["MISC"] = "DEPTHS"
            end

            if @hash.key?("crystal cave")
                desc["MISC"] = "CRYSTAL CAVE"
            end

            if @name == "Crystal Fish"
                desc["MISC"] = "CRYSTAL CAVE OR FLOODED ROOM"
            end

            desc.merge(play_desc())
        end

        def abilities(player, hash)
            if hash.key?("skill")
                player.skill += hash["skill"]
            end
            if hash.key?("move")
                player.move += hash["move"]
            end
            if hash.key?("attack")
                player.attack += hash["attack"]
            end
            if hash.key?("teleport")
                player.teleport += hash["teleport"]
            end
            if hash.key?("coins")
                player.collect_coins(hash["coins"])
            end
            if hash.key?("draw")
                player.draw(hash["draw"])
            end
            if hash.key?("clank")
                player.clank(hash["clank"])
            end
            if hash.key?("heal")
                player.heal(hash["heal"])
            end
            if hash.key?("tomes")
                remaining = @game.reserve[:t].remaining
                player.tome(hash["tomes"])
                @game.broadcast("#{player.name} gained +#{[hash["tomes"], remaining].min} Tome(s)! There are #{@game.reserve[:t].remaining} Tome(s) left!")
            end
        end
    end
end

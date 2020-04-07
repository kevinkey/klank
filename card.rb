module Klank
    class Card

        attr_reader :name
        attr_reader :type
        attr_reader :cost
        attr_reader :attack
        attr_reader :danger
        attr_reader :dragon

        def initialize(game, hash)
            @game = game 

            @name = hash["name"]
            @type = hash["type"] || ""
            @cost = hash["cost"] || 1000000
            @attack = hash["attack"] || 1000000
            @special = hash["special"] || ""
            @danger = hash.key?("danger")
            @dragon = hash.key?("dragon")

            @hash = hash
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
            when "The Duke"
                total += (player.coins / 5)
            when "Wizard"
                total += (player.deck.all.select { |c| c.name == "Tome" }.count * 3)
            end

            total
        end

        def arrive()
            case @name 
            when "Overlord", "Watcher"
                @game.player.each do |p|
                    p.clank()
                end
            when "Shrine"
                @game.dragon.add_dragon_cubes()
            end
        end

        def acquire(player)
            success = false
            cost = 0

            if (@type == :gem) and player.has_played?("Gem Collector")
                cost = @cost - 2 
            else 
                cost = @cost 
            end

            if @type == :monster
                player.output("Can't buy a monster!")
            elsif @hash.key?("depths") and !@game.map.depths?(player)
                player.output("Must be in the depths to acquire!")
            elsif player.skill >= cost
                success = true

                player.skill -= cost

                case @name 
                when "Dragon Shrine"
                    menu = [["C", "2 coins"], ["T", "Trash a card"]]
                    if player.menu("DRAGON SHRINE", menu) == "C"
                        player.collect_coins(2)
                    else 
                        player.trash_card()
                    end
                when "Shrine"
                    menu = [["C", "1 coin"], ["H", "1 heal"]]
                    if player.menu("SHRINE", menu) == "C"
                        player.collect_coins(1)
                    else 
                        player.heal(1)
                    end
                end

                if @hash.key?("acquire")
                    abilities(player, @hash["acquire"])
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
            elsif player.attack >= @attack
                success = true
                
                player.attack -= @attack

                if @name == "Watcher"
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
            when "Apothecary"
                if player.discard_card()
                    menu = [["A", "3 attack"], ["C", "2 coins"], ["H", "1 heal"]]
                    case player.menu("APOTHECARY", menu)
                    when "A"
                        player.attack += 3
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
            when "Kobold Merchant"
                if player.has_artifact?()
                    player.skill += 2
                end
            when "Master Burglar"
                player.trash_card("Burgle")
            when "Mister Whiskers"
                @game.broadcast("#{player.name} played Mister Whiskers!")
                @game.dragon.bank_status()
                menu = [["D", "Dragon Attack"], ["C", "-2 clank"]]
                if player.menu("MISTER WHISKERS", menu) == "D"
                    @game.dragon.attack()
                else 
                    player.clank(-2)
                end
            when "Rebel Captain", "Rebel Miner", "Rebel Scout", "Rebel Soldier"
                if player.played.any? { |c| (c.type == :companion) and (c.name != @name) }
                    player.draw(1)
                end 
            when "Sleight of Hands"
                if player.discard_card()
                    player.draw(2)
                end
            when "Tattle"
                @game.broadcast("All other players +1 clank")
                @game.player.each do |p|
                    if p.index != player.index 
                        p.clank(1)
                    end
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
                    menu = [["C", "1 coin"], ["T", "7 coins for #{[2, remaining].min} Tomes"]]
                    if player.menu("UNDERWORLD DEALING", menu) == "C"
                        player.collect_coins(1)
                    else 
                        player.coins -= 7
                        player.deck.discard(@game.reserve[:t].draw([2, remaining].min))
                    end
                end
            when "Wand of Recall"
                if player.has_artifact?()
                    player.teleport += 1
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
        end

        def play_desc()
            string = [
                sprintf("%-25s", @name), 
                sprintf("%-10s", @type.to_s.upcase)
            ]

            if @hash.key?("equip")
                if @hash["equip"].key?("skill") 
                    string << "SKILL: #{@hash["equip"]["skill"]}"
                end
                if @hash["equip"].key?("move") 
                    string << "MOVE: #{@hash["equip"]["move"]}"
                end
                if @hash["equip"].key?("attack") 
                    string << "ATTACK: #{@hash["equip"]["attack"]}"
                end
                if @hash["equip"].key?("teleport") 
                    string << "TELEPORT"
                end
                if @hash["equip"].key?("coins") 
                    string << "COINS: #{@hash["equip"]["coins"]}"
                end
                if @hash["equip"].key?("draw") 
                    string << "DRAW: #{@hash["equip"]["draw"]}"
                end
                if @hash["equip"].key?("clank") 
                    string << "CLANK: #{@hash["equip"]["clank"]}"
                end
                if @hash["equip"].key?("heal") 
                    string << "HEAL: #{@hash["equip"]["heal"]}"
                end
            end

            if @hash.key?("special")
                string << @special
            end

            string.join(" | ")
        end

        def buy_desc(gem_collector)
            string = play_desc.split(" | ")

            if @hash.key?("points")
                string.insert(2, "POINTS: #{@hash["points"]}")
            end

            if @hash.key?("cost")
                cost = 0
    
                if (@type == :gem) and gem_collector
                    cost = @cost - 2 
                else 
                    cost = @cost 
                end

                string.insert(2, "COST: #{cost}")
            end

            if @hash.key?("attack")
                string.insert(2, "DEFEAT: #{@hash["attack"]}")
            end

            if @hash.key?("acquire")
                if @hash["acquire"].key?("skill") 
                    string << "ACQUIRE SKILL: #{@hash["acquire"]["skill"]}"
                end
                if @hash["acquire"].key?("move") 
                    string << "ACQUIRE MOVE: #{@hash["acquire"]["move"]}"
                end
                if @hash["acquire"].key?("attack") 
                    string << "ACQUIRE ATTACK: #{@hash["acquire"]["attack"]}"
                end
                if @hash["acquire"].key?("teleport") 
                    string << "ACQUIRE TELEPORT"
                end
                if @hash["acquire"].key?("coins") 
                    string << "ACQUIRE COINS: #{@hash["acquire"]["coins"]}"
                end
                if @hash["acquire"].key?("clank") 
                    string << "ACQUIRE CLANK: #{@hash["acquire"]["clank"]}"
                end
                if @hash["acquire"].key?("heal") 
                    string << "ACQUIRE HEAL: #{@hash["acquire"]["heal"]}"
                end
            end

            if @hash.key?("defeat")
                if @hash["defeat"].key?("skill") 
                    string << "SKILL: #{@hash["defeat"]["skill"]}"
                end
                if @hash["defeat"].key?("move") 
                    string << "MOVE: #{@hash["defeat"]["move"]}"
                end
                if @hash["defeat"].key?("coins") 
                    string << "COINS: #{@hash["defeat"]["coins"]}"
                end
                if @hash["defeat"].key?("draw") 
                    string << "DRAW: #{@hash["defeat"]["draw"]}"
                end
                if @hash["defeat"].key?("clank") 
                    string << "CLANK: #{@hash["defeat"]["clank"]}"
                end
                if @hash["defeat"].key?("heal") 
                    string << "HEAL: #{@hash["defeat"]["heal"]}"
                end
            end

            if @danger
                string << "DANGER"
            end

            string.join(" | ")
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
        end
    end
end
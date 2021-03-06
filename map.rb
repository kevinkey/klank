require "yaml"

module Klank
    require_relative "item.rb"
    require_relative "utils.rb"

    class Map

        attr_reader :map_num
        attr_reader :market

        attr_accessor :bank

        def initialize(game, map)
            @game = game
            @map_num = map
            @map = YAML.load(File.read("#{@game.sunken_treasures ? "sunken_treasures/" : ""}map#{@map_num}.yml"))

            # make sure every room has a hash, "secrets" defined (default 0)
            @map["rooms"].each_key do |room_num|
                @map["rooms"][room_num] = {
                    "major-secrets" => 0,
                    "minor-secrets" => 0,
                    "monkey-idols" => 0,
                    "coins" => 0,
                    "heal" => 0,
                    "artifact" => 0,
                    "crystal-cave" => false,
                    "flooded" => false,
                    "store" => false,
                }.merge(@map["rooms"][room_num] || {})
            end

            # make sure every path has a hash, "move", "attack" and "clank" defined (default 1, 0 and 0)
            @map["paths"].each_key do |key|
                @map["paths"][key] = {
                    "move" => 1,
                    "attack" => 0,
                    "clank" => 0,
                    "locked" => false
                }.merge(@map["paths"][key] || {})
            end

            @major = []
            @minor = []
            @market = []

            for i in 0..1 do
                file_path_prefix = ((i == 1) and @game.sunken_treasures) ? "sunken_treasures/" : ""
                if (i == 0) or @game.sunken_treasures
                    YAML.load(File.read("#{file_path_prefix}major.yml")).each do |i|
                        (i["count"] || 1).times do
                            @major << Item.new(game, i)
                        end
                    end

                    YAML.load(File.read("#{file_path_prefix}minor.yml")).each do |i|
                        (i["count"] || 1).times do
                            @minor << Item.new(game, i)
                        end
                    end

                    YAML.load(File.read("#{file_path_prefix}market.yml")).each do |i|
                        (i["count"] || 1).times do
                            @market << Item.new(game, i)
                        end
                    end
                end
            end

            @bank = 81  # <-- 12 5-coin tokens and 21 1-coin tokens
        end

        def move(player)
            loop do
                player.output("\n#{Klank.table([{"MOVE" => player.move, "ATTACK" => player.attack}])}")

                paths_out = get_paths_out(player)
                option = player.menu("MOVE FROM ROOM #{player.room_num}", paths_out, true)
                if option != "N"
                    room_num = option.to_i
                    path = paths_out.find { |p| p[0] == option }[1]["NAME"]

                    rooms = path.split(/-/, 2)
                    move_between_flooded_rooms = flooded_room?(rooms[0]) && flooded_room?(rooms[1]) && !player.has_item?("Scuba")
                    
                    move = move_between_flooded_rooms ? 2 : @map["paths"][path]["move"]
                    attack = @map["paths"][path]["attack"]
                    clank = @map["paths"][path]["clank"]
                    locked = @map["paths"][path]["locked"]

                    if player.move < move
                        player.output("Not enough move!")
                    elsif locked and !player.has_item?("Master Key")
                        player.output("That path is locked!")
                    elsif (room_num <= 1) and !player.has_artifact?()
                        player.output("No leaving without an artifact!")
                    else
                        if crystal_cave?(player)
                            crystal_golem_card = @game.dungeon.crystal_golem
                            if crystal_golem_card != nil
                                if player.attack >= crystal_golem_card.attack
                                    if ("Y" == player.input("Do you want to kill the Crystal Golem first? (Y: yes)").upcase)
                                        @game.dungeon.acquire(player, crystal_golem_card)
                                        break
                                    end
                                end
                            end
                        end
                        
                        if (attack > 0)
                            if player.has_played?("Flying Carpet")
                                @game.broadcast("#{player.name} flew by the monster(s) on their Flying Carpet!")
                            elsif player.attack > 0
                                max_kill = [player.attack, attack].min
                                kill = player.input_num("You encounter #{attack} monster(s), enter number to kill", 0..max_kill)
                                @game.broadcast("#{player.name} killed #{kill} monster(s) and took #{(attack - kill)} damage!")
                                player.attack -= kill
                                player.num_monsters_killed += kill
                                player.num_damage_dealt += kill
                                (attack - kill).times do
                                    player.damage(true)
                                end
                            else
                                attack.times do
                                    player.damage(true)
                                end
                                @game.broadcast("#{player.name} took #{attack} damage!")
                            end
                        end

                        break if player.dead?()

                        player.clank(clank)

                        player.move -= move
                        player.num_distance_moved += move

                        @game.broadcast("#{player.name} travelled to room #{room_num}.")
                        enter_room(player, room_num)
                        break if (player.move == 0) or player.frozen
                    end
                else
                    break
                end

                break if player.dead?() or player.mastery
            end
        end

        def teleport(player)
            loop do               
                player.output("\n#{Klank.table([{"TELEPORT" => (player.teleport + (flooded?(player) ? player.shrine_mermaid_teleport : 0) + ((player.visited_rooms.count > 1) ? player.door_before_teleport : 0))}])}")

                paths = []
                if (player.teleport + (flooded?(player) ? player.shrine_mermaid_teleport : 0)) > 0
                    paths = get_paths(player)
                end
                visited_rooms = []
                if (player.door_before_teleport > 0) && (player.visited_rooms.count > 1)
                    player.visited_rooms.each do |room|
                        if room.to_i != player.room_num && paths.none?{ |path| path[0].to_i == room.to_i }
                            visited_rooms << [room, room_desc(room)]
                        end
                    end
                end

                option = player.menu("TELEPORT FROM ROOM #{player.room_num}", paths + visited_rooms, true)
                if option != "N"
                    room_num = option.to_i
                    if (room_num <= 1) and !player.has_artifact?()
                        player.output("No leaving without an artifact!")
                    else
                        if crystal_cave?(player)
                            crystal_golem_card = @game.dungeon.crystal_golem
                            if crystal_golem_card != nil
                                if player.attack >= crystal_golem_card.attack
                                    if ("Y" == player.input("Do you want to kill the Crystal Golem first? (Y: yes)").upcase)
                                        @game.dungeon.acquire(player, crystal_golem_card)
                                        break
                                    end
                                end
                            end
                        end
                        
                        if visited_rooms.any?{ |room| room[0] == room_num }
                            player.door_before_teleport -= 1
                        elsif flooded?(player) and (player.shrine_mermaid_teleport > 0)
                            player.shrine_mermaid_teleport -= 1
                        else
                            player.teleport -= 1
                        end
                        player.num_times_teleported += 1

                        @game.broadcast("#{player.name} teleported to room #{room_num}.")
                        enter_room(player, room_num)

                        break if (player.teleport + (flooded?(player) ? player.shrine_mermaid_teleport : 0) + ((player.visited_rooms.count > 1) ? player.door_before_teleport : 0)) == 0
                    end
                else
                    break
                end

                break if player.dead?() or player.mastery
            end
        end

        def view(player)
            rooms = []
            @map["rooms"].each_key do |room_num|
                status = room_desc(room_num)
                if status.keys.count > 0
                    rooms << {"ROOM" => room_num}.merge(status)
                end
            end

            player.output("MAP\n#{Klank.table(rooms)}")
        end

        def depths?(player)
            (player.room_num >= @map["depths"])
        end

        def crystal_cave?(player)
            @map["rooms"][player.room_num]["crystal-cave"]
        end

        def flooded?(player)
            flooded_room?(player.room_num)
        end

        def flooded_room?(room_num)
            @map["rooms"][room_num.to_i]["flooded"]
        end

        def take_adjacent_secret(player)
            rooms = []
            paths = get_paths(player)
            paths.each do |p|
                room_num = p[0].to_i
                if (@map["rooms"][room_num]["minor-secrets"] > 0)
                    rooms << [room_num, "Minor Secrets: #{@map["rooms"][room_num]["minor-secrets"]}"]
                elsif (@map["rooms"][room_num]["major-secrets"] > 0)
                    rooms << [room_num, "Major Secrets: #{@map["rooms"][room_num]["major-secrets"]}"]
                end
            end
            option = player.menu("ADJACENT SECRET LIST", rooms, true)
            if option != "N"
                room_num = option.to_i
                if (@map["rooms"][room_num]["minor-secrets"] > 0)
                    @map["rooms"][room_num]["minor-secrets"] -= 1
                    @minor = Klank.randomize(@minor)
                    item = @minor.shift
                    player.num_minor_secrets_collected += 1
                else
                    @map["rooms"][room_num]["major-secrets"] -= 1
                    @major = Klank.randomize(@major)
                    item = @major.shift
                    player.num_major_secrets_collected += 1
                end
                @game.broadcast("#{player.name} took a #{item.name} from room #{room_num}")
                item.gain(player)
            end
            (option != "N")
        end

        def market?(player)
            (@map["rooms"][player.room_num]["store"]) and (@market.count > 0) and (player.coins >= 7)
        end

        def view_market(player)
            items = []
            @market.each do |m|
                items << {"NAME" => m.name, "DESCRIPTION" => m.description}
            end
            player.output("\nMARKET\n#{Klank.table(items)}")
        end

        def shop(player)
            loop do
                player.output("\n#{Klank.table([{"COINS" => player.coins}])}")

                options = []
                @market.each_with_index do |m, i|
                    options << [i, m.desc()]
                end
                item = player.menu("MARKET", options, true)

                break if item == "N"

                @bank += 7
                @game.broadcast("#{player.name} bought #{@market[item.to_i].name} from the market! There are #{@bank} coin(s) in the bank!")
                @market[item.to_i].gain(player)
                @market.delete_at(item.to_i)
                player.coins -= 7

                break if !market?(player)
            end
        end

        private

        def enter_room(player, room_num)
            player.room_num = room_num
            player.visited_rooms |= [room_num]
            player.num_rooms_visited += 1

            if room_num <= 1
                player.mastery = true
                @game.broadcast("#{player.name} has left and collects a Mastery Token!")
                @game.trigger_end(player)
            end

            if crystal_cave?(player)
                player.num_caves_visited += 1
                if !player.has_played?("Dead Run") and !player.has_played?("Flying Carpet")
                    @game.broadcast("#{player.name} has been frozen by the crystal cave!")
                    player.frozen = true
                end
            else
                player.frozen = false
            end

            if flooded?(player)
                player.num_flooded_rooms_visited += 1
            else
                if !player.air
                    @game.broadcast("#{player.name} has come up for air!")
                end
                player.air = true
            end

            if @map["rooms"][player.room_num]["minor-secrets"] > 0
                @map["rooms"][player.room_num]["minor-secrets"] -= 1
                @minor = Klank.randomize(@minor)
                item = @minor.shift
                @game.broadcast("#{player.name} found a #{item.desc}!")
                item.gain(player)
                player.num_minor_secrets_collected += 1
            end

            if @map["rooms"][player.room_num]["major-secrets"] > 0
                @map["rooms"][player.room_num]["major-secrets"] -= 1
                @major = Klank.randomize(@major)
                item = @major.shift
                @game.broadcast("#{player.name} found a #{item.desc}!")
                item.gain(player)
                player.num_major_secrets_collected += 1
            end

            if @map["rooms"][player.room_num]["monkey-idols"] > 0
                @map["rooms"][player.room_num]["monkey-idols"] -= 1
                player.item << Item.new(@game, {"name" => "Monkey Idol", "symbol" => "M", "points" => 5})
                @game.broadcast("#{player.name} bows down to the Monkey Idol!")
            end

            player.collect_coins(@map["rooms"][player.room_num]["coins"])

            player.heal(@map["rooms"][player.room_num]["heal"])

            if (@map["rooms"][player.room_num]["artifact"] > 0) and player.hold_artifact?()
                points = @map["rooms"][player.room_num]["artifact"]

                if player.menu("PICK UP #{points} POINT ARTIFACT?", [["Y", "Yes"], ["N", "No"]]) == "Y"
                    @game.broadcast("#{player.name} picks up the #{points} point artifact!")
                    @game.dragon.anger()
                    player.artifact << points
                    @map["rooms"][player.room_num]["artifact"] = 0
                end
            end
        end

        # return hash of keys of all paths in or out of room number
        def get_paths(player)
            paths = []
            @map["paths"].each_key do |key|
                if (key =~ /^#{player.room_num}-(\d+)$/) || (key =~ /^(\d+)-#{player.room_num}$/)
                    paths << [$1, path_desc(player, key).merge(room_desc($1.to_i))]
                end
            end
            paths
        end

        # return hash of keys of all paths out of room number
        def get_paths_out(player)
            paths_out = []
            @map["paths"].each_key do |key|
                if ((key =~ /^#{player.room_num}-(\d+)/) || ((key =~ /(\d+)-#{player.room_num}$/) && @map["paths"][key]["one-way"].nil?))
                    paths_out << [$1, path_desc(player, key).merge(room_desc($1.to_i))]
                end
            end
            paths_out
        end

        def path_desc(player, key)
            path = @map["paths"][key]

            rooms = key.split(/-/, 2)
            move_between_flooded_rooms = flooded_room?(rooms[0]) && flooded_room?(rooms[1]) && !player.has_item?("Scuba")

            desc = {
                "NAME" => key,
                "MOVE" => move_between_flooded_rooms ? 2 : (path.key?("move") ? path["move"] : 1),
                "MONSTERS" => path.key?("attack") ? path["attack"] : 0
            }

            clank = path.key?("clank") ? path["clank"] : 0
            if @game.sunken_treasures && (clank > 0)
                desc["CLANK"] = clank
            end

            if path["locked"]
                desc["LOCK"] = "YES"
            end

            desc
        end

        def room_desc(room_num)
            status = {}

            if (@map["rooms"][room_num]["minor-secrets"] > 0)
                status["MINOR"] = @map["rooms"][room_num]["minor-secrets"]
            elsif (@map["rooms"][room_num]["major-secrets"] > 0)
                status["MAJOR"] = @map["rooms"][room_num]["major-secrets"]
            elsif (@map["rooms"][room_num]["monkey-idols"] > 0)
                status["MONKEY IDOLS"] = @map["rooms"][room_num]["monkey-idols"]
            elsif (@map["rooms"][room_num]["artifact"] > 0)
                status["ARTIFACT"] = @map["rooms"][room_num]["artifact"]
            elsif (@map["rooms"][room_num]["coins"] > 0)
                status["COINS"] = @map["rooms"][room_num]["coins"]
            end

            players = @game.player.select{ |p| p.room_num == room_num }
            if players.count > 0
                status["PLAYERS"] = players.map { |p| p.name }.join(", ")
            end

            status
        end
    end
end

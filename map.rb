require "yaml"

module Klank
    require_relative "item.rb"
    require_relative "utils.rb"

    class Map

        attr_reader :map_num

        attr_accessor :bank

        def initialize(game, map)
            @game = game
            @map_num = map
            @map = YAML.load(File.read("map#{@map_num}.yml"))

            # make sure every room has a hash, "secrets" defined (default 0)
            @map["rooms"].each_key do |room_num|
                @map["rooms"][room_num] = {
                    "major-secrets" => 0,
                    "minor-secrets" => 0,
                    "monkey-idols" => 0,
                    "heal" => 0,
                    "artifact" => 0,
                    "crystal-cave" => false,
                    "store" => false,
                }.merge(@map["rooms"][room_num] || {})
            end

            # make sure every path has a hash, "move" and "attack" defined (default 1 and 0)
            @map["paths"].each_key do |key|
                @map["paths"][key] = {
                    "move" => 1,
                    "attack" => 0,
                    "locked" => false
                }.merge(@map["paths"][key] || {})
            end

            @major = []
            @minor = []
            @market = []

            YAML.load(File.read("major.yml")).each do |i|
                (i["count"] || 1).times do
                    @major << Item.new(game, i)
                end
            end

            YAML.load(File.read("minor.yml")).each do |i|
                (i["count"] || 1).times do
                    @minor << Item.new(game, i)
                end
            end

            YAML.load(File.read("market.yml")).each do |i|
                (i["count"] || 1).times do
                    @market << Item.new(game, i)
                end
            end

            @bank = 81

        end

        def move(player)
            loop do
                player.output("\n#{Klank.table([{"MOVE" => player.move, "ATTACK" => player.attack}])}")

                paths_out = get_paths_out(player.room_num)
                option = player.menu("MOVE FROM ROOM #{player.room_num}", paths_out, true)
                if option != "N"
                    room_num = option.to_i
                    path = paths_out.find { |p| p[0] == option }[1]["NAME"]

                    # get move, attack, and locked requirements and check player meets them
                    move = @map["paths"][path]["move"]
                    attack = @map["paths"][path]["attack"]
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
                player.output("\n#{Klank.table([{"TELEPORT" => player.teleport}])}")

                paths = get_paths(player.room_num)
                option = player.menu("TELEPORT FROM ROOM #{player.room_num}", paths, true)
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
                        
                        player.teleport -= 1
                        player.num_times_teleported += 1

                        @game.broadcast("#{player.name} teleported to room #{room_num}.")
                        enter_room(player, room_num)

                        break if player.teleport == 0
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

        def take_adjacent_secret(player)
            rooms = []
            paths = get_paths(player.room_num)
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

        def shop(player)
            loop do
                player.output("\n#{Klank.table([{"COINS" => player.coins}])}")

                options = []
                @market.each_with_index do |m, i|
                    options << [i, m.desc()]
                end
                item = player.menu("MARKET", options, true)

                break if item == "N"

                @game.broadcast("#{player.name} bought #{@market[item.to_i].name} from the market! There are #{@bank} coin(s) in the bank!")
                @market[item.to_i].gain(player)
                @market.delete_at(item.to_i)
                player.coins -= 7
                @bank += 7

                break if !market?(player)
            end
        end

        private

        def enter_room(player, room_num)
            player.room_num = room_num
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
        def get_paths(room_num)
            paths = []
            @map["paths"].each_key do |key|
                if (key =~ /^#{room_num}-(\d+)$/) || (key =~ /^(\d+)-#{room_num}$/)
                    paths << [$1, path_desc(key).merge(room_desc($1.to_i))]
                end
            end
            paths
        end

        # return hash of keys of all paths out of room number
        def get_paths_out(room_num)
            paths_out = []
            @map["paths"].each_key do |key|
                if ((key =~ /^#{room_num}-(\d+)/) ||
                    ((key =~ /(\d+)-#{room_num}$/) && @map["paths"][key]["one-way"].nil?))
                    paths_out << [$1, path_desc(key).merge(room_desc($1.to_i))]
                end
            end
            paths_out
        end

        def path_desc(key)
            path = @map["paths"][key]
            desc = {
                "NAME" => key,
                "MOVE" => path.key?("move") ? path["move"] : 1,
                "MONSTERS" => path.key?("attack") ? path["attack"] : 0,
            }

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
            end

            players = @game.player.select{ |p| p.room_num == room_num }
            if players.count > 0
                status["PLAYERS"] = players.map { |p| p.name }.join(", ")
            end

            status
        end
    end
end

require "yaml"

module Klank
    require_relative "item.rb"
    require_relative "utils.rb"

    class Map
        def initialize(game, map)
            @game = game
            @map = YAML.load(File.read("map#{map}.yml"))

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

        end 

        def move(player)
            loop do 
                paths_out = get_paths_out(player.room_num)
                paths_out["N"] = "No move"
                option = player.menu("MOVE LIST", paths_out)
                if option != "N"
                    room_num = option.to_i
                    # get move, attack, and locked requirements and check player meets them
                    move = @map["paths"][paths_out[room_num]]["move"]
                    attack = @map["paths"][paths_out[room_num]]["attack"]
                    locked = @map["paths"][paths_out[room_num]]["locked"]

                    if player.move < move
                        player.output("Not enough move!")
                    elsif locked and !player.has_item?("Master Key")
                        player.output("That path is locked!")
                    else
                        if (attack > 0) and (player.attack > 0) and !player.has_played?("Flying Carpet")
                            max_kill = [player.attack, attack].min
                            kill = player.input_num("You encounter #{attack} monster(s), enter number to kill", 0..max_kill)
                            @game.broadcast("#{player.name} killed #{kill} monster(s) and took #{(attack - kill)} damage!")
                            player.attack -= kill 
                            (attack - kill).times do 
                                player.damage(true)
                            end
                        end

                        player.move -= move

                        @game.broadcast("#{player.name} travelled to room #{room_num}.")
                        enter_room(player, room_num)
                        break if player.move == 0
                    end
                else 
                    break
                end
            end
        end

        def teleport(player)
            loop do 
                paths = get_paths(player.room_num)
                paths["N"] = "No teleport"
                option = player.menu("TELEPORT LIST", paths)
                if option != "N"
                    room_num = option.to_i
                    player.teleport -= 1

                    @game.broadcast("#{player.name} teleported to room #{room_num}.")
                    enter_room(player, room_num)

                    break if player.teleport == 0
                else
                    break
                end
            end
        end

        def depths?(player)
            (player.room_num >= @map["depths"])
        end

        def crystal_cave?(player)
            @map["rooms"][player.room_num]["crystal-cave"]
        end

        def take_adjacent_secret(player)
            false
        end

        def market?(player)
            @map["rooms"][player.room_num]["store"]
        end

        def shop(player)

        end

        private

        def enter_room(player, room_num)
            player.room_num = room_num

            if crystal_cave?(player) and !player.has_played?("Dead Run") and !player.has_played?("Flying Carpet")
                @game.broadcast("#{player.name} has been frozen by the crystal cave!")
                player.frozen = true 
            end

            if @map["rooms"][player.room_num]["minor-secrets"] > 0
                @map["rooms"][player.room_num]["minor-secrets"] -= 1
                @minor = Klank.randomize(@minor)
                item = @minor.shift
                item.gain(player)
                @game.broadcast("#{player.name} found a #{item.name}!")
            end

            if @map["rooms"][player.room_num]["major-secrets"] > 0
                @map["rooms"][player.room_num]["major-secrets"] -= 1
                @major = Klank.randomize(@major)
                item = @major.shift
                item.gain(player)
                @game.broadcast("#{player.name} found a #{item.name}!")
            end

            if @map["rooms"][player.room_num]["monkey-idols"] > 0
                @map["rooms"][player.room_num]["monkey-idols"] -= 1
                player.item << Item.new(@game, {"name" => "Monkey Idol", "points" => 5})
                @game.broadcast("#{player.name} bows down to the Monkey Idol!")
            end

            if (@map["rooms"][player.room_num]["artifact"] > 0) and player.hold_artifact?()
                points = @map["rooms"][player.room_num]["artifact"]

                if player.menu("PICK UP #{points} POINT ARTIFACT?", [["Y", "Yes"], ["N", "No"]]) == "Y"
                    @game.broadcast("#{player.name} picks up the #{points} point artifact!")
                    player.artifact << points
                    @map["rooms"][player.room_num]["artifact"] = 0
                end
            end
        end

        # return hash of keys of all paths in or out of room number
        def get_paths(room_num)
            paths = {}
            @map["paths"].each_key do |key|
                if (key =~ /^#{room_num}-(\d+)$/) || (key =~ /^(\d+)-#{room_num}$/)
                    paths[$1.to_i] = key
                end
            end
            paths
        end

        # return hash of keys of all paths out of room number
        def get_paths_out(room_num)
            paths_out = {}
            @map["paths"].each_key do |key|
                if ((key =~ /^#{room_num}-(\d+)/) ||
                    ((key =~ /(\d+)-#{room_num}$/) && @map["paths"][key]["one-way"].nil?))
                    paths_out[$1.to_i] = key
                end
            end
            paths_out
        end
    end
end

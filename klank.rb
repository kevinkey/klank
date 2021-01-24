require "socket"

module Klank
  require_relative "game.rb"
  require_relative "player.rb"

  games = []
  port = 8080
  port = ARGV[0] if ARGV.length == 1

  server = TCPServer.new port
  puts "Server is running on port #{port}..."
  loop do
    Thread.start(server.accept) do |client|
      sleep 0.1
      p client

      player = Player.new(client, games)

      loop do
        menu = []
        games.delete_if { |g| g.shutdown || g.started }
        games.each_with_index do |g, i|
          menu << [i, g.status]
        end
        menu << ["N", {"Name" => "Create a new game"}]
        option = player.menu("GAME LIST", menu)

        case option
        when "N"
          player.output("\nCREATE A GAME")

          name = String.new
          loop do
            name = player.input("Name")
            if games.find { |g| g.name == name } != nil
              player.output("#{name} is already taken! Choose a different name!")
            else
              break
            end
          end

          num = player.input_num("Players", 2..4)

          case player.menu("GAME SELECTION", [["1", {"DESC" => "Base Game"}], ["2", {"DESC" => "Sunken Treasures"}], ["R", {"DESC" => "Let the game randomly choose the game"}]])
          when "1"
            sunken_treasures = false
          when "2"
            sunken_treasures = true
          when "R"
            sunken_treasures = rand(true..false)
            player.output("#{sunken_treasures ? "Sunken Treasures" : "Base Game"} was randomly selected!")
          end

          case player.menu("MAP SELECTION", [["1", {"DESC" => "Play on Map 1"}], ["2", {"DESC" => "Play on Map 2"}], ["R", {"DESC" => "Let the game randomly choose the map"}]])
          when "1"
            map = 1
          when "2"
            map = 2
          when "R"
            map = rand(1..2)
            player.output("Map ##{map} was randomly selected!")
          end

          player.output("\nCreated #{name}, waiting for players...")

          game = Game.new(name, num, map, sunken_treasures)
          games << game
          game.join(player)
        else
          case player.menu("PLAY OR SPECTATE", [["P", {"DESC" => "Play"}], ["S", {"DESC" => "Spectate"}]])
          when "S"
            player.output("\nJoining #{games[option.to_i].name} as spectator...")
            games[option.to_i].spectate(player)
          else
            player.output("\nJoining #{games[option.to_i].name} as player...")
            games[option.to_i].join(player)
          end
        end
      end

      client.close
    end
  end

  puts "Server stopped..."
end
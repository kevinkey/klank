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

      player = Player.new(client)

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
          name = player.input("Name")
          num = player.input_num("Players", 2..4)
          map = player.input_num("Map", 1..2)
          player.output("\nCreated #{name}, waiting for players...")

          game = Game.new(name, num, map)
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
require "socket"

module Klank
  require_relative "game.rb"
  require_relative "player.rb"

  games = []

  server = TCPServer.new 2000
  loop do
    Thread.start(server.accept) do |client|
      sleep 0.1

      player = Player.new(client)

      loop do
        menu = []
        games.delete_if { |g| g.shutdown }
        games.each_with_index do |g, i|
          menu << [i, g.status]
        end
        menu << ["N", "Create a new game"]
        option = player.menu("GAME LIST", menu)

        case option 
        when "N"
          name = player.input("Name")
          num = player.input_num("Players", 2..4)
          player.output("\nCreated #{name}, waiting for players...")

          game = Game.new(name, num)
          games << game 
          game.join(player)
        else
          player.output("\nJoining #{games[option.to_i].name}...")
          games[option.to_i].join(player)
        end
      end

      client.close
    end
  end

  puts "Server stopped..."
end
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
        option = player.menu(menu)

        case option 
        when "N"
          name = player.input("Name")
          num = player.input("Players").to_i

          if (num >= 2) and (num <= 4)
            player.output("Created #{name}, waiting for players...")

            game = Game.new(name, num)
            games << game 
            game.join(player)
          end

        if (game.to_i > 0) and (game.to_i < (games.count + 1))
          player.output("Joining #{games[game.to_i - 1].name}...")
          games[game.to_i - 1].join(player)
        end

        if game.upcase == 'N'
          
        end
      end

      client.close
    end
  end

  puts "Server stopped..."
end
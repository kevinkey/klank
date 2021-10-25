#!/usr/bin/ruby

@bag = [1, 1, 2, 3, 3, 3]

def helloWorld(player, num_draws, x)
    outcomes = @bag.combination(num_draws).to_a
    count = 0
    outcomes.each do |outcome|
        countt = 0
        outcome.each do |cube|
            if (cube == player)
                countt += 1
            end
        end
        if (countt == x)
            count += 1
        end
    end
    return count
end

def factorial(num)
    (1..num).inject(1){ |prod, i| prod * i } 
end

def get_combination(num1, num2)
    factorial(num1) / (factorial(num2) * factorial(num1 - num2))
end

result = 0
player_id = 3
number_draws = 3
@bag.select { |c| c == player_id }.count.to_i.times do |j|
    result += (helloWorld(player_id, number_draws, j+1).to_f / get_combination(@bag.size, number_draws) * (j+1))
end
puts "#{result.to_s}"
module Klank 
    def self.randomize(array)
        temp = []
        array.each do |a|
          temp << {value: a, sort: rand}
        end

        temp.sort_by { |hash| hash[:sort] }.map { |t| t[:value] }
      end
end

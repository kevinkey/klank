module Klank 
  def self.randomize(array)
    temp = []
    array.each do |a|
      temp << {value: a, sort: rand}
    end

    temp.sort_by { |hash| hash[:sort] }.map { |t| t[:value] }
  end

  def self.table(array)
      columns = {}

      array.each do |hash|
        columns.merge!(hash)
      end

      columns.keys.each do |key|
        columns[key] = key.length
      end

      array.each do |hash|
        columns.keys.each do |key|
          if hash.key?(key)
            columns[key] = [columns[key], hash[key].to_s.length].max
          end
        end
      end

      table = []

      bar = []
      string = []    

      columns.each do |k, v|
        bar << Array.new(v, "-").join
        string << sprintf("%-#{v}s", k.to_s)
      end

      bar = "+-#{bar.join("-+-")}-+"
      table << bar
      table << "| #{string.join(" | ")} |"
      table << bar

      array.each do |hash|
        row = []
        columns.each do |k, v|
          row << sprintf("%-#{v}s", hash.key?(k) ? hash[k].to_s : "")
        end
        table << "| #{row.join(" | ")} |"
      end

      table << bar

      table.join("\n")
  end
end

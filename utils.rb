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

  def self.red(text)
      colorize(text, "31")
  end

  def self.green(text)
      colorize(text, "32")
  end

  def self.yellow(text)
      colorize(text, "33")
  end

  def self.blue(text)
      colorize(text, "34")
  end

  def self.magenta(text)
      colorize(text, "35")
  end

  def self.cyan(text)
      colorize(text, "36")
  end

  private

  def self.colorize(text, color_code)
    "\e[#{color_code}m#{text}\e[0m"
  end
end

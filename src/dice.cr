require "cincle"

module Dice
  include Cincle

  ########### WHITESPACE
  
  rule :w { (str(" ") | str("\t") | str("\r") | str("\n") ).repeat 0 }
  
  ########### NUMBERS
  
  macro build_numbers(numbers)
    {% for number, value in numbers %}
      node {{number}} {
        def value
          {{value}}
        end
      }
      rule {{number}} { str({{(number.chars.join "")}}) | str({{(number.chars.join "").capitalize}}) }
    {% end %}
  end
  
  node :number_digital { getter value : Int32 { raw.to_i } }
  rule :number_digital { match /\d+/ }

  build_numbers Hash(Symbol, Int32) { :one => 1, :two => 2, :three => 3, :four => 4, :five => 5, :six => 6, :eight => 8, :ten => 10, :twelve => 12, :fourteen => 14, :sixteen => 16, :eighteen => 18, :twenty => 20, :one_hundred => 100 }

  onion :number_literal, [:one, :two, :three, :four, :five, :six, :eight, :ten, :twelve, :fourteen, :sixteen, :eighteen, :twenty] {
    abstract def value
  }
  
  onion :number, [:number_literal, :number_digital] {
    def value
      onion.value
    end
  }
  
  ########### DICES

  node :fudge {
    def value
      (rand 3) - 1
    end
  }
  rule :fudge { (str "fudge") | (str "fate") | (str "f") }

  node :percent {
    def value
      rand 100
    end
  }
  rule :percent { (str "%") | (str "percentile") }

  node :faced {
    def value
      rand number.onion.value
    end
  }
  rule :faced { number >> w >> (str "faced").maybe }

  onion :dice, [:faced, :percent, :fudge] {
    abstract def value
  }

  ########## ROLL

  node :compact_roll { getter values : Array(Int32) { Array(Int32).new(number_digital.value) { dice.onion.value } } }
  rule :compact_roll { number_digital >> (str "d") >> dice }

  node :verbose_roll { getter values : Array(Int32) { Array(Int32).new(number.onion.value) { dice.onion.value } } }
  rule :verbose_roll { number >> w >> dice >> w >> ((str "dice") >> (str "s").maybe).maybe }

  node :literal_roll { getter values : Array(Int32) { [number.onion.value] } }
  rule :literal_roll { number }

  onion :single_roll, [:compact_roll, :verbose_roll, :literal_roll] {
    abstract def values
  }

  rule :positive_roll_separator { str("and") | str("plus") | str(",") | str("+") }
  rule :negative_roll_separator { str("minus") | str("-") }

  onion :roll_separator, [:positive_roll_separator, :negative_roll_separator] {}
  node :many_rolls {
    def positive_values
      single_rolls.map_with_index { |roll,index| {roll: roll, index: index} }.select { |entry|
        (entry[:index] == 0) || (roll_separators[entry[:index] - 1].positive_roll_separator?)
      }.map { |entry| entry[:roll].values }.flatten
    end
    def negative_values
      single_rolls.map_with_index { |roll,index| {roll: roll, index: index} }.select { |entry|
        (entry[:index] != 0) && (roll_separators[entry[:index] - 1].negative_roll_separator?)
      }.map { |entry| entry[:roll].values }.flatten
    end
    def values
      positive_values + negative_values.map &.*(-1)
    end
  }
  rule :many_rolls { single_roll >> (w >> roll_separator >> w >> single_roll).repeat 0 }

  rule :keep_modifier { str("keep") | str("select") | str("pick") | str("Keep") | str("Select") | str("Pick") | str("k") }
  rule :remove_modifier { str("Remove") | str("remove") | str("r") }
  onion :modifier, [:keep_modifier, :remove_modifier] {}

  rule :random_strategy { str("random") | str("r") }
  rule :best_strategy { str("bests") | str("best") | str("b") }
  rule :worst_strategy { str("worsts") | str("worst") | str("w") }
  onion :strategy, [:random_strategy, :best_strategy, :worst_strategy] {}

  rule :literal_modified_rolls { modifier >> w >> number >> w >> strategy.maybe >> w >> str("from") >> w >> many_rolls}
  rule :compact_modified_rolls { many_rolls >> modifier >> number_digital >> strategy.maybe }

  onion :modified_rolls, [:literal_modified_rolls, :compact_modified_rolls] {
    def values
      amount = number? ? number.value : number_digital.value
      vals = many_rolls.values
      if strategy?
        case {modifier, strategy}
        when {.keep_modifier?, .random_strategy?}
          vals.sample(amount)
        when {.remove_modifier?, .random_strategy?}
          vals.sample(vals.size - amount)
        when {.keep_modifier?, .best_strategy?}
          vals.sort.reverse[0, amount]
        when {.remove_modifier?, .best_strategy?}
          vals.sort.reverse[amount...(vals.size)]
        when {.keep_modifier?, .worst_strategy?}  
          vals.sort[0, amount]
        when {.remove_modifier?, .worst_strategy?}
          vals.sort[amount...(vals.size)]
        else
          [] of Int32
        end
      else
        case {modifier}
        when {.keep_modifier?}
          vals.sample(amount)
        when {.remove_modifier?}
          vals.sample(vals.size - amount)
        else
         [] of Int32
        end
      end
    end
  }

  node :rolls {
    def values
      modified_rolls? ? modified_rolls.values : many_rolls.values
    end
  }
  rule :rolls { (modified_rolls | many_rolls) >> w >> str(".").maybe }
  
  root :rolls
end

values = Dice.parse(ARGV[0]).values
puts "All: #{values}"
puts "Result: #{values.sum}"

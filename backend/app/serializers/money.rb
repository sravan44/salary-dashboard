# Money crosses the API boundary as an exact string with two decimals, never a float.
module Money
  module_function

  def format_amount(amount)
    return nil if amount.nil?

    whole, fraction = amount.round(2).to_s("F").split(".")
    "#{whole}.#{fraction.to_s.ljust(2, '0')}"
  end
end

# JSON shapes for salary records. Amounts are exact strings with their currency.
module CompensationSerializer
  module_function

  # `previous` is the record just before this one; the % change is derived, never stored, and only
  # given when both are in the same currency (INR → USD has no meaningful percentage).
  def record(compensation, previous: nil)
    {
      id: compensation.id,
      amount: Money.format_amount(compensation.amount),
      currency: compensation.currency,
      effective_from: compensation.effective_from.iso8601,
      effective_to: compensation.effective_to&.iso8601,
      current: compensation.effective_to.nil?,
      reason: compensation.reason,
      notes: compensation.notes,
      revised_by: compensation.revised_by,
      change_percent: change_percent(previous, compensation)
    }
  end

  # Newest first, each with its % change from the record before it.
  def history(compensations)
    oldest_first = compensations.sort_by(&:effective_from)
    oldest_first.each_with_index.map { |c, i| record(c, previous: i.zero? ? nil : oldest_first[i - 1]) }.reverse
  end

  def change_percent(previous, current)
    return nil if previous.nil? || previous.currency != current.currency

    format("%.2f", ((current.amount - previous.amount) / previous.amount * 100).round(2, BigDecimal::ROUND_HALF_UP))
  end
end

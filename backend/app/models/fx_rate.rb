# One cached reference rate: 1 `base` = `rate` `quote` on `rate_date`, as published by `source`.
class FxRate < ApplicationRecord
  validates :base, :quote, :rate_date, :source, :fetched_at, presence: true
  validates :rate, numericality: { greater_than: 0 }
end

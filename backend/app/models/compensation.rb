# One effective-dated annual base salary, plus why it changed (the revision).
# History is append-only: a change closes the current record and opens a new one
# (Compensations::RecordChange, M5). Every create/update is also logged in `versions`.
class Compensation < ApplicationRecord
  include Versioned

  MAX_AMOUNT = BigDecimal("999_999_999_999.99") # numeric(14,2)

  belongs_to :employee

  enum :reason, {
    hire: "hire", annual_review: "annual_review", promotion: "promotion",
    market_adjustment: "market_adjustment", correction: "correction"
  }, validate: true, scopes: false, instance_methods: false

  scope :current, -> { where(effective_to: nil) }

  validates :amount, numericality: { greater_than: 0, less_than_or_equal_to: MAX_AMOUNT }
  validates :currency, inclusion: { in: Acme::Reference.currencies }
  validates :effective_from, presence: true
  validates :notes, length: { maximum: 1_000 }
  validate :effective_to_not_before_effective_from

  private

  def effective_to_not_before_effective_from
    return if effective_to.nil? || effective_from.nil? || effective_to >= effective_from

    errors.add(:effective_to, "must be on or after the start date")
  end
end

# One entry in the append-only audit trail (see Versioned).
class Version < ApplicationRecord
  belongs_to :item, polymorphic: true

  # Written once, never edited or deleted through the app.
  def readonly? = persisted?
end

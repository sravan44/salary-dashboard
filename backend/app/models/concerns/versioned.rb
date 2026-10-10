# Writes an audit Version for every create/update, inside the same transaction as the change,
# so a change can never be saved without its audit entry.
#
# This is a deliberate, narrow use of callbacks: it has no business side effects and touches only
# this database. Business rules stay in services. Bulk inserts (insert_all) skip callbacks, so
# callers that use them write versions explicitly (see Seeds::EmployeeSeeder).
module Versioned
  extend ActiveSupport::Concern

  # Never logged: technical columns, and secrets (a password digest must not be copied anywhere).
  IGNORED_ATTRIBUTES = %w[id created_at updated_at password_digest].freeze

  included do
    has_many :versions, -> { order(:id) }, as: :item, inverse_of: :item
    after_create { record_version("create") }
    after_update { record_version("update") }
  end

  def self.changes_for(attributes)
    attributes.except(*IGNORED_ATTRIBUTES).transform_values { |(old, new)| [ serialize(old), serialize(new) ] }
  end

  def self.serialize(value)
    value.is_a?(BigDecimal) ? value.to_s("F") : value
  end

  private

  def record_version(event)
    changes = Versioned.changes_for(saved_changes)
    return if changes.empty?

    Version.create!(item: self, event: event, object_changes: changes, whodunnit: Current.actor)
  end
end

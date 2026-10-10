# Per-request context. `actor` is who is making changes; it is recorded in the audit trail.
# Set by controllers once authentication exists (M7) and by the seeder.
class Current < ActiveSupport::CurrentAttributes
  attribute :actor
end

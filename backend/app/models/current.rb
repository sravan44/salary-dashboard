# Per-request context. `actor` is who is making changes; it is recorded in the audit trail.
# Set from the signed-in user by Authentication, and by the seeder.
class Current < ActiveSupport::CurrentAttributes
  attribute :actor, :user, :session
end

# Someone who can sign in. Roles combine: access is the union of what each role allows.
#   viewer      the dashboard (aggregates only)
#   hr_manager  the dashboard + employees and their salaries (view, create, edit, deactivate)
#   admin       the dashboard + user accounts and roles
class User < ApplicationRecord
  include Versioned

  ROLES = %w[viewer hr_manager admin].freeze
  PERMISSIONS = {
    view_dashboard: ROLES,
    manage_employees: %w[hr_manager],
    manage_users: %w[admin]
  }.freeze

  has_secure_password
  has_many :sessions, dependent: :delete_all

  normalizes :email, with: ->(email) { email.strip.downcase }
  # Unique, in the fixed ROLES order, so equal role sets always look the same.
  normalizes :roles, with: ->(roles) { ROLES & Array(roles).map(&:to_s) | (Array(roles).map(&:to_s) - ROLES) }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :password, length: { minimum: 12 }, allow_nil: true
  validate :roles_are_known

  def can?(permission) = PERMISSIONS.fetch(permission).intersect?(roles)

  def permissions = PERMISSIONS.keys.index_with { |permission| can?(permission) }

  private

  def roles_are_known
    return errors.add(:roles, "must include at least one role") if roles.blank?

    unknown = roles - ROLES
    errors.add(:roles, "contains an unknown role: #{unknown.join(', ')}") if unknown.any?
  end
end

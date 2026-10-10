module Seeds
  # Demo sign-ins, one per role, for local use and demos. The password is documented in the README,
  # so it must never work on a real deployment: in production nothing is created unless
  # DEMO_USER_PASSWORD is set on purpose. Existing users are never changed.
  class DemoUsers
    DEFAULT_PASSWORD = "local-demo-password".freeze
    USERS = {
      "admin@acme.example" => %w[viewer hr_manager admin],
      "hr@acme.example" => %w[hr_manager],
      "viewer@acme.example" => %w[viewer]
    }.freeze

    # Returns the emails it created.
    def self.call(password: ENV["DEMO_USER_PASSWORD"].presence) = new(password).call

    def initialize(password)
      @password = password || (Rails.env.production? ? nil : DEFAULT_PASSWORD)
    end

    def call
      return [] if @password.nil?

      USERS.reject { |email, _| User.exists?(email:) }.map do |email, roles|
        User.create!(email:, roles:, password: @password).email
      end
    end
  end
end

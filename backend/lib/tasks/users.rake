namespace :users do
  desc "Create a user: EMAIL=... ROLES=admin,hr_manager PASSWORD=... (password from the environment, never printed)"
  task create: :environment do
    email = ENV.fetch("EMAIL", "").strip.downcase
    abort "#{email} already exists; not changing it." if User.exists?(email:)

    user = User.new(email:, roles: ENV.fetch("ROLES", "").split(",").map(&:strip), password: ENV.fetch("PASSWORD", ""))
    abort "Not created:\n  #{user.errors.full_messages.join("\n  ")}" unless user.save

    puts "Created #{user.email} with roles: #{user.roles.join(', ')}"
  end

  # Demo accounts for local use and demos, one per role. Needs DEMO_USER_PASSWORD (compose sets a
  # local placeholder); without it nothing is created. Existing users are never changed.
  DEMO_USERS = {
    "viewer@acme.example" => %w[viewer],
    "hr@acme.example" => %w[hr_manager],
    "admin@acme.example" => %w[admin hr_manager]
  }.freeze

  desc "Create demo users (viewer@, hr@, admin@acme.example) when DEMO_USER_PASSWORD is set"
  task seed_demo: :environment do
    password = ENV["DEMO_USER_PASSWORD"]
    next puts("DEMO_USER_PASSWORD is not set; no demo users created.") if password.blank?

    DEMO_USERS.each do |email, roles|
      next puts("#{email} exists; left unchanged.") if User.exists?(email:)

      User.create!(email:, roles:, password:)
      puts "Created demo user #{email} (#{roles.join(', ')})"
    end
  end
end

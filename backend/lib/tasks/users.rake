namespace :users do
  desc "Create a user: EMAIL=... ROLES=admin,hr_manager PASSWORD=... (password from the environment, never printed)"
  task create: :environment do
    email = ENV.fetch("EMAIL", "").strip.downcase
    abort "#{email} already exists; not changing it." if User.exists?(email:)

    user = User.new(email:, roles: ENV.fetch("ROLES", "").split(",").map(&:strip), password: ENV.fetch("PASSWORD", ""))
    abort "Not created:\n  #{user.errors.full_messages.join("\n  ")}" unless user.save

    puts "Created #{user.email} with roles: #{user.roles.join(', ')}"
  end

  desc "Create the demo sign-ins (admin@, hr@, viewer@acme.example); see README. In production only with DEMO_USER_PASSWORD"
  task seed_demo: :environment do
    created = Seeds::DemoUsers.call
    if created.any?
      puts "Created demo users: #{created.join(', ')}"
    elsif Rails.env.production? && ENV["DEMO_USER_PASSWORD"].blank?
      puts "DEMO_USER_PASSWORD is not set; no demo users in production."
    else
      puts "Demo users already exist; left unchanged."
    end
  end
end

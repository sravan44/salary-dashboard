namespace :app do
  desc "Seed demo data only into an empty database (run on container start when AUTO_SEED=true)"
  task seed_if_empty: :environment do
    if ENV["AUTO_SEED"] != "true"
      puts "AUTO_SEED is not enabled; not seeding."
    elsif Employee.exists?
      puts "Database already has #{Employee.count} employees; not seeding."
    else
      load Rails.root.join("db/seeds.rb")
    end
  end
end

# Seeds a deterministic synthetic workforce: `bin/rails db:seed`
#   SEED_EMPLOYEES  number of employees (default 10,000)
#   SEED_RANDOM     random seed (default 42); the same value always yields identical data
# Re-running REPLACES all employees and salary history (see Seeds::EmployeeSeeder).
if Rails.env.production? && ENV["SEED_REPLACE"] != "1"
  abort "Refusing to replace employee data in production. Set SEED_REPLACE=1 to confirm."
end

count = Integer(ENV.fetch("SEED_EMPLOYEES", "10000"))
random_seed = Integer(ENV.fetch("SEED_RANDOM", "42"))

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
result = Seeds::EmployeeSeeder.new(count: count, random_seed: random_seed).call
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

puts "Seeded #{result[:employees]} employees, #{result[:compensations]} salary records " \
     "(#{result[:current_compensations]} current) with random seed #{random_seed} in #{elapsed.round(2)}s"

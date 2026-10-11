# Measures the app's hot read paths on the current database (meant for the 10k seed).
#
#   bin/rails runner script/perf/measure.rb [LABEL]
#
# For each case: 3 warm-up runs, then RUNS timed runs (median and p95 in ms) of the real app code,
# the number of SQL statements it issues, and EXPLAIN (ANALYZE, BUFFERS) of each statement. Plans go
# to tmp/perf/plans-LABEL.txt; the summary is printed as a Markdown table. Everything runs inside a
# transaction that is rolled back, so the temporary FX rates it needs leave no trace.
require "fileutils"

RUNS = Integer(ENV.fetch("RUNS", 20))
label = ARGV.first || "run"
connection = ActiveRecord::Base.connection

# `rails runner` enables Active Record's query cache; repeated runs would then be answered from
# memory and look impossibly fast. Every measurement bypasses it.
def timed(runs)
  ActiveRecord::Base.uncached { timed_uncached(runs) { yield } }
end

def timed_uncached(runs)
  3.times { yield }
  samples = Array.new(runs) do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  end.sort
  [ samples[samples.size / 2], samples[(samples.size * 0.95).ceil - 1] ]
end

def statements
  captured = []
  callback = lambda do |*, payload|
    next if payload[:name].in?([ "SCHEMA", "EXPLAIN" ]) || payload[:sql] =~ /\A\s*(SAVEPOINT|RELEASE|ROLLBACK|BEGIN|COMMIT)/

    captured << [ payload[:sql], payload[:binds] ]
  end
  ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { ActiveRecord::Base.uncached { yield } }
  captured
end

FileUtils.mkdir_p(Rails.root.join("tmp/perf"))
plans_path = Rails.root.join("tmp/perf/plans-#{label}.txt")
rows = []

ActiveRecord::Base.transaction do
  Current.actor = "perf"
  { "USD" => "1.10", "INR" => "92.40", "GBP" => "0.85", "CAD" => "1.51", "AUD" => "1.66", "SGD" => "1.43" }.each do |quote, rate|
    FxRate.find_or_create_by!(base: "EUR", quote:, rate_date: Date.current - 1) do |row| # reuse rates already present
      row.assign_attributes(rate:, source: "perf (temporary)", fetched_at: Time.current)
    end
  end
  Fx::Snapshot.clear_memory!

  employee = Employee.joins(:compensations).group("employees.id").having("COUNT(*) >= 4").order(:id).first
  everyone = Insights::Population.new
  india = Insights::Population.new(country: %w[IN])
  directory = ->(params) { Employees::DirectoryQuery.new(params).call.records }

  cases = {
    "Directory: default page (name order)" => -> { directory.call({}) },
    "Directory: search \"rao\"" => -> { directory.call(q: "rao") },
    "Directory: 2 countries × 1 dept × active" => -> { directory.call(country: %w[IN US], department: %w[Engineering], status: %w[active]) },
    "Directory: USD 100k–150k, salary desc" => -> { directory.call(currency: "USD", min_salary: "100000", max_salary: "150000", sort: "-salary") },
    "Directory: deep page (400 of 400)" => -> { directory.call(page: "400") },
    "Employee: salary history" => -> { CompensationSerializer.history(Compensation.where(employee:).to_a) },
    "Employee: history in USD" => -> { CompensationSerializer.history(Compensation.where(employee:).to_a, conversion: Fx::Conversion.new(to: "USD")) },
    "Employee: audit trail" => -> { Versions::ForEmployeeQuery.new(employee).call.to_a },
    "Dashboard: overview (summary)" => -> { Insights::SummaryQuery.new(everyone).call },
    "Dashboard: pay by department (INR)" => -> { Insights::PayStatsQuery.new(everyone, group_by: :department, currency: "INR", limit: 20).call },
    "Dashboard: pay by job title (INR)" => -> { Insights::PayStatsQuery.new(everyone, group_by: :job_title, currency: "INR", limit: 10).call },
    "Dashboard: distribution (INR)" => -> { Insights::DistributionQuery.new(everyone, currency: "INR", buckets: 10).call },
    "Dashboard: filtered (India) pay by dept" => -> { Insights::PayStatsQuery.new(india, group_by: :department, currency: "INR", limit: 20).call },
    "Converted (USD): pay by department" => -> { Insights::ConvertedQuery.new(everyone, to: "USD", snapshot: Fx::Snapshot.latest).pay_stats(group_by: :department, limit: 20) },
    "Converted (USD): distribution" => -> { Insights::ConvertedQuery.new(everyone, to: "USD", snapshot: Fx::Snapshot.latest).distribution(buckets: 10) }
  }

  File.open(plans_path, "w") do |plans|
    plans.puts "# EXPLAIN (ANALYZE, BUFFERS) — #{label} — #{Time.current.utc.iso8601}"
    cases.each do |name, run|
      sql = statements(&run)
      median, p95 = timed(RUNS, &run)
      plan_ms = 0.0
      seq_scans = []
      plans.puts "\n## #{name} (#{sql.size} statements)"
      sql.each do |text, binds|
        next unless text =~ /\A\s*(SELECT|WITH)/i

        plan = connection.exec_query("EXPLAIN (ANALYZE, BUFFERS) #{text}", "EXPLAIN", binds).rows.flatten
        plans.puts "\n#{text}\n" + plan.join("\n")
        plan_ms += plan.grep(/Execution Time: ([\d.]+)/) { Regexp.last_match(1).to_f }.sum
        seq_scans.concat(plan.grep(/Seq Scan on (\w+)/) { Regexp.last_match(1) })
      end
      rows << [ name, sql.size, median.round(1), p95.round(1), plan_ms.round(1), seq_scans.uniq.join(", ").presence || "—" ]
    end
  end
  raise ActiveRecord::Rollback
end

puts "| Case | SQL statements | median ms | p95 ms | DB execution ms (EXPLAIN) | Seq scans |"
puts "|---|---|---|---|---|---|"
rows.each { |row| puts "| #{row.join(' | ')} |" }
puts "\nPlans: #{plans_path.relative_path_from(Rails.root)} (#{RUNS} timed runs per case)"

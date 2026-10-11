# End-to-end request timings against a running app (production mode recommended).
#
#   ruby script/perf/http.rb http://localhost:3000 hr@acme.example <password> [EMPLOYEE_ID]
#
# Signs in, then times each endpoint RUNS times (default 20) after 3 warm-ups; prints median and p95 ms.
require "json"
require "net/http"
require "uri"

base, email, password, employee_id = ARGV
abort "usage: ruby script/perf/http.rb BASE_URL EMAIL PASSWORD [EMPLOYEE_ID]" unless base && email && password
RUNS = Integer(ENV.fetch("RUNS", 20))
uri = URI(base)
http = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https")

sign_in = Net::HTTP::Post.new("/api/v1/session", "Content-Type" => "application/json")
sign_in.body = { email:, password: }.to_json
response = http.request(sign_in)
abort "sign-in failed: #{response.code}" unless response.code == "201"
cookie = response["set-cookie"].split(";").first
employee_id ||= JSON.parse(http.request(Net::HTTP::Get.new("/api/v1/employees?per_page=1", "Cookie" => cookie)).body)["data"][0]["id"]

graphql = lambda do |query, variables = {}|
  request = Net::HTTP::Post.new("/graphql", "Content-Type" => "application/json", "Cookie" => cookie)
  request.body = { query:, variables: }.to_json
  request
end
overview = "query($f: DashboardFilters) { dashboard(filters: $f) { headcount countriesCount currencies { currency headcount } " \
           "headcountByCountry { countryCode headcount } headcountByDepartment { department headcount } hiresByYear { year headcount } } }"
detail = "query($c: Currency!) { dashboard { distribution(currency: $c, buckets: 10) { from to count } " \
         "byDepartment: payStats(groupBy: DEPARTMENT, currency: $c, limit: 20) { group median } " \
         "byJobTitle: payStats(groupBy: JOB_TITLE, currency: $c, limit: 10) { group median } } }"
converted = "query { dashboard { converted(to: USD) { available rates { currency rate } distribution(buckets: 10) { count } " \
            "byDepartment: payStats(groupBy: DEPARTMENT, limit: 20) { group median } byJobTitle: payStats(groupBy: JOB_TITLE, limit: 10) { group median } } } }"

get = ->(path) { Net::HTTP::Get.new(path, "Cookie" => cookie) }
cases = {
  "GET directory (default page)" => -> { get.("/api/v1/employees") },
  "GET directory ?q=rao" => -> { get.("/api/v1/employees?q=rao") },
  "GET directory 2 countries × dept × active" => -> { get.("/api/v1/employees?country[]=IN&country[]=US&department[]=Engineering&status[]=active") },
  "GET directory USD 100k–150k, salary desc" => -> { get.("/api/v1/employees?currency=USD&min_salary=100000&max_salary=150000&sort=-salary") },
  "GET directory page 400" => -> { get.("/api/v1/employees?page=400") },
  "GET employee profile" => -> { get.("/api/v1/employees/#{employee_id}") },
  "GET salary history" => -> { get.("/api/v1/employees/#{employee_id}/compensations") },
  "GET salary history ?report=USD" => -> { get.("/api/v1/employees/#{employee_id}/compensations?report=USD") },
  "GET audit trail" => -> { get.("/api/v1/employees/#{employee_id}/versions") },
  "POST /graphql DashboardOverview" => -> { graphql.(overview) },
  "POST /graphql DashboardCurrencyDetail (INR)" => -> { graphql.(detail, { c: "INR" }) },
  "POST /graphql DashboardConverted (USD)" => -> { graphql.(converted) }
}

puts "| Request | status | median ms | p95 ms |"
puts "|---|---|---|---|"
cases.each do |name, build|
  status = nil
  3.times { status = http.request(build.call).code }
  samples = Array.new(RUNS) do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status = http.request(build.call).code
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  end.sort
  puts "| #{name} | #{status} | #{samples[samples.size / 2].round(1)} | #{samples[(samples.size * 0.95).ceil - 1].round(1)} |"
end

# Smoke test for a running deployment (stdlib only; runs with any Ruby 3).
#
#   SMOKE_PASSWORD='<demo password>' ruby script/smoke.rb https://<app>.fly.dev
#
# Uses the demo accounts (viewer@ and hr@acme.example). The password is read from the environment
# and never printed. Prints one PASS/FAIL line per check and exits 1 if any check fails.
require "json"
require "net/http"
require "uri"

base = URI(ARGV[0] || abort("usage: SMOKE_PASSWORD=... ruby script/smoke.rb BASE_URL"))
password = ENV.fetch("SMOKE_PASSWORD") { abort "set SMOKE_PASSWORD (the demo users' password)" }
https = base.scheme == "https"
failures = 0

check = lambda do |name, ok, detail = nil|
  failures += 1 unless ok
  puts "#{ok ? 'PASS' : 'FAIL'}  #{name}#{detail ? "  (#{detail})" : ''}"
end

http = Net::HTTP.start(base.host, base.port, use_ssl: https, open_timeout: 10, read_timeout: 30)
get = ->(path, cookie = nil) { http.request(Net::HTTP::Get.new(path, cookie ? { "Cookie" => cookie } : {})) }
post_json = lambda do |path, body, cookie = nil|
  request = Net::HTTP::Post.new(path, { "Content-Type" => "application/json" }.merge(cookie ? { "Cookie" => cookie } : {}))
  request.body = body.to_json
  http.request(request)
end
graphql = ->(query, cookie = nil) { post_json.("/graphql", { query: }, cookie) }
sign_in = lambda do |email|
  response = post_json.("/api/v1/session", { email:, password: })
  [ response, response["set-cookie"].to_s ]
end

# 1. The app is up and serves the React app on the same origin.
check.("GET /up", get.("/up").code == "200")
home = get.("/")
check.("GET / serves the app", home.code == "200" && home.body.include?('id="root"'))
check.("GET /dashboard (client route) serves the app", get.("/dashboard").code == "200")
check.("GET /graphiql is off", get.("/graphiql").code == "404")

# 2. HTTPS only: plain HTTP is redirected, HSTS is sent.
if https
  plain = Net::HTTP.get_response(URI("http://#{base.host}/up"))
  check.("http:// redirects to https://", plain.code.start_with?("30") && plain["location"].to_s.start_with?("https://"), "#{plain.code} → #{plain['location']}")
  check.("Strict-Transport-Security header", !home["strict-transport-security"].to_s.empty?)
end

# 3. Nothing without signing in.
check.("signed out: GET /api/v1/employees → 401", get.("/api/v1/employees").code == "401")
check.("signed out: POST /graphql → 401", graphql.("{ dashboard { headcount } }").code == "401")

# 4. Viewer: dashboard only.
response, set_cookie = sign_in.("viewer@acme.example")
check.("viewer signs in", response.code == "201", response.code)
flags = set_cookie.downcase
check.("session cookie is HttpOnly + SameSite=Lax#{' + Secure' if https}",
       flags.include?("httponly") && flags.include?("samesite=lax") && (!https || flags.include?("secure")))
viewer = set_cookie.split(";").first
headcount = JSON.parse(graphql.("{ dashboard { headcount } }", viewer).body).dig("data", "dashboard", "headcount")
check.("viewer: dashboard headcount", headcount.to_i.positive?, headcount.inspect)
check.("viewer: GET /api/v1/employees → 403", get.("/api/v1/employees", viewer).code == "403")

# 5. Reporting currency: rates were fetched, with provenance.
converted = JSON.parse(graphql.("{ dashboard { converted(to: USD) { available rateDate source stale includedHeadcount " \
                                "excludedCurrencies { currency headcount } } } }", viewer).body).dig("data", "dashboard", "converted") || {}
check.("FX rates available (USD)", converted["available"] == true,
       "#{converted['rateDate']} · #{converted['source']} · stale=#{converted['stale']} · included #{converted['includedHeadcount']} · " \
       "excluded #{converted['excludedCurrencies'].inspect}")

# 6. HR manager: the directory and an employee's salary history.
response, set_cookie = sign_in.("hr@acme.example")
check.("hr signs in", response.code == "201", response.code)
hr = set_cookie.split(";").first
directory = get.("/api/v1/employees?per_page=1", hr)
body = JSON.parse(directory.body)
check.("hr: GET /api/v1/employees → 200", directory.code == "200", "total #{body.dig('meta', 'total')}")
employee_id = body.dig("data", 0, "id")
history = get.("/api/v1/employees/#{employee_id}/compensations?report=USD", hr)
records = JSON.parse(history.body)["data"] || []
check.("hr: salary history in USD", history.code == "200" && records.any? && records.first["converted"],
       "#{records.size} records, current #{records.first&.dig('amount')} #{records.first&.dig('currency')} ≈ #{records.first&.dig('converted', 'amount')} USD")
check.("hr: GET /api/v1/users → 403", get.("/api/v1/users", hr).code == "403")

# 7. Sign-out ends the session at once.
signed_out = http.request(Net::HTTP::Delete.new("/api/v1/session", "Cookie" => hr))
check.("sign out → 204, then 401", signed_out.code == "204" && get.("/api/v1/employees", hr).code == "401")

puts failures.zero? ? "\nAll checks passed." : "\n#{failures} check(s) failed."
exit(failures.zero? ? 0 : 1)

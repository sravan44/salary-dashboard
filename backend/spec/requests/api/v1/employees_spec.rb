require "rails_helper"

# A small, hand-picked population so every filter has an unambiguous expected result.
RSpec.describe "Employee directory API" do
  def hire(number, name, country:, department:, title:, amount:, currency:, status: "active", hire_date: Date.new(2020, 1, 15))
    employee = create(:employee, employee_number: number, full_name: name, email: "#{name.parameterize(separator: '.')}@acme.example",
                                 country_code: country, department:, job_title: title, status:, hire_date:)
    create(:compensation, employee:, amount:, currency:, effective_from: hire_date)
    employee
  end

  let!(:asha)  { hire("EMP-000001", "Asha Rao",     country: "IN", department: "Engineering", title: "Senior Software Engineer", amount: "2400000", currency: "INR", hire_date: Date.new(2019, 4, 1)) }
  let!(:james) { hire("EMP-000002", "James Smith",  country: "US", department: "Engineering", title: "Software Engineer",        amount: "120000",  currency: "USD", hire_date: Date.new(2021, 6, 1)) }
  let!(:clara) { hire("EMP-000003", "Clara Weber",  country: "DE", department: "People",      title: "HR Generalist",            amount: "72000",   currency: "EUR", hire_date: Date.new(2018, 2, 1)) }
  let!(:ravi)  { hire("EMP-000004", "Ravi Rao",     country: "IN", department: "Finance",     title: "Financial Analyst",        amount: "1800000", currency: "INR", status: "terminated") }
  let!(:emma)  { hire("EMP-000005", "Emma Smith",   country: "US", department: "Engineering", title: "Software Engineer",        amount: "100000",  currency: "USD", hire_date: Date.new(2022, 9, 1)) }
  let!(:louis) { hire("EMP-000006", "Louis Martin", country: "FR", department: "Sales",       title: "Account Executive",        amount: "65000",   currency: "EUR") }

  def directory(params = {})
    get "/api/v1/employees", params: params
    response.parsed_body
  end

  def numbers(params = {}) = directory(params)["data"].map { |row| row["employee_number"] }

  describe "listing" do
    it "returns employees sorted by name, with pagination metadata" do
      body = directory

      expect(response).to have_http_status(:ok)
      expect(body["data"].map { |r| r["full_name"] }).to eq([ "Asha Rao", "Clara Weber", "Emma Smith", "James Smith", "Louis Martin", "Ravi Rao" ])
      expect(body["meta"]).to eq("page" => 1, "per_page" => 25, "total" => 6, "total_pages" => 1)
    end

    it "includes each employee's current salary as an exact string with its currency" do
      row = directory(q: "EMP-000002")["data"].sole

      expect(row).to include(
        "id" => james.id, "employee_number" => "EMP-000002", "full_name" => "James Smith", "country_code" => "US",
        "department" => "Engineering", "job_title" => "Software Engineer", "status" => "active", "hire_date" => "2021-06-01",
        "current_salary" => { "amount" => "120000.00", "currency" => "USD" }
      )
    end

    it "shows only the current salary, not older history" do
      james.compensations.sole.update!(effective_to: Date.new(2023, 12, 31))
      create(:compensation, employee: james, amount: "130000", currency: "USD", effective_from: Date.new(2024, 1, 1), reason: "annual_review")

      expect(directory(q: "EMP-000002")["data"].sole["current_salary"]["amount"]).to eq("130000.00")
    end
  end

  describe "search (q)" do
    it "matches part of a name, case-insensitively" do
      expect(numbers(q: "smi")).to contain_exactly("EMP-000002", "EMP-000005")
    end

    it "matches part of an employee number" do
      expect(numbers(q: "000003")).to eq([ "EMP-000003" ])
    end

    it "matches part of an email" do
      expect(numbers(q: "louis.martin@")).to eq([ "EMP-000006" ])
    end

    it "treats % and _ as literal characters, not wildcards" do
      expect(numbers(q: "%")).to be_empty
      expect(numbers(q: "_")).to be_empty
    end

    it "ignores surrounding whitespace and an empty search" do
      expect(numbers(q: "  Rao  ")).to contain_exactly("EMP-000001", "EMP-000004")
      expect(numbers(q: "   ").size).to eq(6)
    end
  end

  describe "filters" do
    it "filters by country" do
      expect(numbers(country: "IN")).to contain_exactly("EMP-000001", "EMP-000004")
    end

    it "filters by department" do
      expect(numbers(department: "Engineering")).to contain_exactly("EMP-000001", "EMP-000002", "EMP-000005")
    end

    it "filters by exact job title" do
      expect(numbers(job_title: "Software Engineer")).to contain_exactly("EMP-000002", "EMP-000005")
    end

    it "filters by status" do
      expect(numbers(status: "terminated")).to eq([ "EMP-000004" ])
    end

    it "filters by the current salary's currency, across countries" do
      expect(numbers(currency: "EUR")).to contain_exactly("EMP-000003", "EMP-000006")
    end

    it "combines filters with AND" do
      expect(numbers(country: "US", department: "Engineering", q: "emma")).to eq([ "EMP-000005" ])
    end

    it "accepts several values per filter: OR within a filter, AND across filters" do
      expect(numbers(country: %w[DE FR])).to contain_exactly("EMP-000003", "EMP-000006")
      expect(numbers(country: %w[IN US], department: %w[Finance People])).to eq([ "EMP-000004" ])
      expect(numbers(job_title: [ "HR Generalist", "Account Executive" ])).to contain_exactly("EMP-000003", "EMP-000006")
      expect(numbers(status: %w[active terminated]).size).to eq(6)
    end

    it "ignores blank and repeated values in a multi-value filter" do
      expect(numbers(country: [ "", "DE", "DE" ])).to eq([ "EMP-000003" ])
      expect(numbers(country: [ "" ]).size).to eq(6)
    end

    it "returns an empty page, not an error, when nothing matches" do
      body = directory(country: "SG")

      expect(response).to have_http_status(:ok)
      expect(body["data"]).to eq([])
      expect(body["meta"]).to include("total" => 0, "total_pages" => 0)
    end
  end

  describe "salary range" do
    it "filters by min and max salary within one currency, inclusive" do
      expect(numbers(currency: "USD", min_salary: "100000", max_salary: "110000")).to eq([ "EMP-000005" ])
      expect(numbers(currency: "USD", min_salary: "100000")).to contain_exactly("EMP-000002", "EMP-000005")
      expect(numbers(currency: "INR", max_salary: "2000000")).to eq([ "EMP-000004" ])
    end

    it "rejects a salary range without a currency, because amounts in different currencies are not comparable" do
      body = directory(min_salary: "50000")

      expect(response).to have_http_status(:bad_request)
      expect(body["error"]["code"]).to eq("invalid_parameters")
      expect(body["error"]["details"]).to include("currency" => [ "is required when filtering by salary" ])
    end

    it "rejects non-numeric, negative or inverted ranges" do
      directory(currency: "USD", min_salary: "abc")
      expect(response).to have_http_status(:bad_request)

      directory(currency: "USD", min_salary: "-1")
      expect(response).to have_http_status(:bad_request)

      body = directory(currency: "USD", min_salary: "200000", max_salary: "100000")
      expect(body["error"]["details"]).to include("max_salary" => [ "must be greater than or equal to min_salary" ])
    end
  end

  describe "sorting" do
    it "sorts by an allowed field, descending with a '-' prefix" do
      expect(numbers(sort: "-hire_date").first(2)).to eq([ "EMP-000005", "EMP-000002" ])
      expect(numbers(sort: "employee_number")).to eq(%w[EMP-000001 EMP-000002 EMP-000003 EMP-000004 EMP-000005 EMP-000006])
    end

    it "sorts by salary only within one currency" do
      expect(numbers(currency: "USD", sort: "-salary")).to eq([ "EMP-000002", "EMP-000005" ])

      body = directory(sort: "salary")
      expect(response).to have_http_status(:bad_request)
      expect(body["error"]["details"]).to include("sort" => [ "by salary requires a currency filter" ])
    end

    it "rejects sort fields outside the allowlist" do
      body = directory(sort: "email; DROP TABLE employees")

      expect(response).to have_http_status(:bad_request)
      expect(body["error"]["details"]["sort"].first).to start_with("must be one of")
    end
  end

  describe "pagination" do
    it "returns the requested page" do
      body = directory(per_page: 2, page: 2, sort: "employee_number")

      expect(body["data"].map { |r| r["employee_number"] }).to eq(%w[EMP-000003 EMP-000004])
      expect(body["meta"]).to eq("page" => 2, "per_page" => 2, "total" => 6, "total_pages" => 3)
    end

    it "returns an empty list for a page past the end" do
      body = directory(per_page: 5, page: 9)

      expect(response).to have_http_status(:ok)
      expect(body["data"]).to eq([])
      expect(body["meta"]["total"]).to eq(6)
    end

    it "rejects page and per_page outside their limits" do
      %w[0 -1 abc].each do |page|
        directory(page: page)
        expect(response).to have_http_status(:bad_request), "page=#{page}"
      end
      %w[0 101].each do |per_page|
        directory(per_page: per_page)
        expect(response).to have_http_status(:bad_request), "per_page=#{per_page}"
      end
    end
  end

  describe "invalid filter values" do
    it "rejects unknown countries, departments, statuses and currencies with every problem listed" do
      body = directory(country: "XX", department: "Astrology", status: "retired", currency: "ABC")

      expect(response).to have_http_status(:bad_request)
      expect(body["error"]["details"].keys).to contain_exactly("country", "department", "status", "currency")
    end

    it "rejects a multi-value filter when any one value is unknown" do
      body = directory(country: %w[DE XX], status: %w[active retired])

      expect(response).to have_http_status(:bad_request)
      expect(body["error"]["details"].keys).to contain_exactly("country", "status")
    end

    it "rejects more than 50 values for one filter" do
      body = directory(job_title: Array.new(51) { |i| "Title #{i}" })

      expect(response).to have_http_status(:bad_request)
      expect(body["error"]["details"]["job_title"]).to eq([ "accepts at most 50 values" ])
    end

    it "rejects an overly long search" do
      directory(q: "x" * 101)

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /api/v1/employees/:id" do
    it "returns the employee profile with current salary" do
      get "/api/v1/employees/#{clara.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to include(
        "employee_number" => "EMP-000003", "email" => "clara.weber@acme.example", "hire_date" => "2018-02-01",
        "current_salary" => { "amount" => "72000.00", "currency" => "EUR" }
      )
    end

    it "returns a null salary rather than failing for an employee without a salary record" do
      no_salary = create(:employee, employee_number: "EMP-000099")

      get "/api/v1/employees/#{no_salary.id}"
      expect(response.parsed_body["data"]["current_salary"]).to be_nil
      expect(directory(q: "EMP-000099")["data"].sole["current_salary"]).to be_nil
    end

    it "returns 404 with an error body for an unknown employee" do
      get "/api/v1/employees/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end
  end
end

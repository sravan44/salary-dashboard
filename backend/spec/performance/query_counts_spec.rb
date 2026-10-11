require "rails_helper"

# Fixed query counts for the hot read paths: they must not grow with the number of rows (no N+1)
# and must not make repeated passes over the same data. Timings are in docs/evidence/performance.md.
RSpec.describe "Query counts on hot read paths" do
  before { create_insights_fixture }

  it "directory: one count and one page query, however many rows are on the page" do
    small = sql_statements { Employees::DirectoryQuery.new(per_page: "2").call.records.each(&:current_amount) }
    large = sql_statements { Employees::DirectoryQuery.new(per_page: "100").call.records.each(&:current_amount) }

    expect([ small.size, large.size ]).to eq([ 2, 2 ])
  end

  it "dashboard overview: one pass over the population for all six figures" do
    statements = sql_statements { Insights::SummaryQuery.new(Insights::Population.new).call }

    expect(statements.size).to eq(1)
  end

  it "audit trail: one query that looks rows up by item (not a scan of the whole log)" do
    employee = Employee.find_by!(employee_number: "EMP-000007")
    statements = sql_statements { Versions::ForEmployeeQuery.new(employee).call.to_a }

    expect(statements.size).to eq(1)
    expect(statements.first).to include("UNION ALL")
  end
end

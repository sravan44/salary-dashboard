require "rails_helper"

RSpec.describe Seeds::EmployeeSeeder do
  # A small population keeps the spec fast; the 10,000 run is recorded in docs/evidence.
  subject(:seed!) { described_class.new(count: 300, random_seed: 42).call }

  def snapshot
    Employee.order(:employee_number).includes(:compensations).map do |e|
      [ e.employee_number, e.full_name, e.email, e.country_code, e.department, e.job_title, e.status, e.hire_date,
        e.compensations.sort_by(&:effective_from).map { |c| [ c.amount.to_s, c.currency, c.effective_from, c.effective_to, c.reason ] } ]
    end
  end

  it "creates exactly the requested number of employees, numbered without gaps" do
    seed!

    expect(Employee.count).to eq(300)
    expect(Employee.order(:employee_number).pluck(:employee_number).values_at(0, -1)).to eq(%w[EMP-000001 EMP-000300])
  end

  it "gives every employee exactly one current salary" do
    seed!

    expect(Compensation.current.count).to eq(300)
    expect(Compensation.current.distinct.count(:employee_id)).to eq(300)
  end

  it "builds history with no gaps or overlaps: each closed record ends the day before the next one starts" do
    seed!

    Employee.includes(:compensations).find_each do |employee|
      history = employee.compensations.sort_by(&:effective_from)
      expect(history.first.effective_from).to eq(employee.hire_date)
      history.each_cons(2) do |earlier, later|
        expect(earlier.effective_to).to eq(later.effective_from - 1)
        expect(later.amount).to be > earlier.amount
      end
      expect(history.last.effective_to).to be_nil
    end
  end

  it "keeps every salary on or before the as-of date, so no future-dated records exist" do
    seed!

    expect(Compensation.maximum(:effective_from)).to be <= described_class::AS_OF
    expect(Employee.maximum(:hire_date)).to be <= described_class::AS_OF
  end

  it "pays each employee in their country's currency" do
    seed!

    mismatches = Compensation.joins(:employee).pluck(:currency, "employees.country_code")
                             .reject { |currency, country| Acme::Reference.currency_for(country) == currency }
    expect(mismatches).to be_empty
  end

  it "spreads employees across countries, currencies, departments and both statuses" do
    seed!

    expect(Employee.distinct.count(:country_code)).to eq(8)
    expect(Compensation.distinct.count(:currency)).to eq(7)
    expect(Employee.distinct.count(:department)).to eq(Acme::Reference.departments.size)
    expect(Employee.distinct.pluck(:status)).to contain_exactly("active", "terminated")
  end

  it "only produces records that pass the model validations" do
    seed!

    expect(Employee.all.reject(&:valid?)).to be_empty
    expect(Compensation.all.reject(&:valid?)).to be_empty
  end

  it "is deterministic: the same random seed produces identical data" do
    seed!
    first = snapshot
    seed!

    expect(snapshot).to eq(first)
  end

  it "replaces previous data when re-run, so it never duplicates employees" do
    seed!
    seed!

    expect(Employee.count).to eq(300)
    expect(Compensation.current.count).to eq(300)
  end

  it "produces different data for a different random seed" do
    seed!
    first = snapshot
    described_class.new(count: 300, random_seed: 7).call

    expect(snapshot).not_to eq(first)
  end

  it "explains every salary record: the first is the hire, later ones are reviews or market adjustments" do
    seed!

    Employee.includes(:compensations).find_each do |employee|
      reasons = employee.compensations.sort_by(&:effective_from).map(&:reason)
      expect(reasons.first).to eq("hire")
      expect(reasons.drop(1)).to all(be_in(%w[annual_review market_adjustment]))
    end
    expect(Compensation.distinct.pluck(:revised_by)).to eq([ "seed" ])
  end

  it "writes one 'create' audit version per seeded employee and salary record, attributed to the seed" do
    seed!

    expect(Version.where(item_type: "Employee", event: "create").count).to eq(Employee.count)
    expect(Version.where(item_type: "Compensation", event: "create").count).to eq(Compensation.count)
    expect(Version.distinct.pluck(:whodunnit)).to eq([ "seed" ])
  end

  it "logs the same values that were stored" do
    seed!
    compensation = Compensation.order(:id).first

    changes = Version.find_by!(item: compensation).object_changes
    expect(changes["amount"]).to eq([ nil, compensation.amount.to_s("F") ])
    expect(changes["reason"]).to eq([ nil, "hire" ])
  end

  it "replaces its audit versions on re-run instead of piling them up" do
    seed!
    seed!

    expect(Version.count).to eq(Employee.count + Compensation.count)
  end

  it "reports what it created" do
    expect(seed!).to include(employees: 300, current_compensations: 300)
    expect(seed![:versions]).to eq(Employee.count + Compensation.count)
  end
end

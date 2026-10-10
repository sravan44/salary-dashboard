require "rails_helper"

RSpec.describe Employees::Update do
  let(:employee) { create(:employee, full_name: "Asha Rao", country_code: "IN", department: "Engineering", status: "active") }
  let!(:salary) { create(:compensation, employee:, amount: "2400000", currency: "INR") }

  def call(attributes) = described_class.call(employee, attributes)

  it "updates profile fields and records only what changed in the audit log" do
    result = call(full_name: "Asha R. Rao", department: "Product")

    expect(result).to be_success
    expect(employee.reload).to have_attributes(full_name: "Asha R. Rao", department: "Product")
    expect(Version.where(item: employee, event: "update").sole.object_changes)
      .to eq("full_name" => [ "Asha Rao", "Asha R. Rao" ], "department" => %w[Engineering Product])
  end

  it "deactivates and reactivates, keeping the record and salary history" do
    expect(call(status: "terminated")).to be_success
    expect(employee.reload.status).to eq("terminated")

    expect(call(status: "active")).to be_success
    expect(employee.reload.status).to eq("active")
    expect(employee.compensations).to eq([ salary ])
    expect(Version.where(item: employee, event: "update").map(&:object_changes))
      .to eq([ { "status" => %w[active terminated] }, { "status" => %w[terminated active] } ])
  end

  it "does not change the salary or its currency when the country changes" do
    call(country_code: "DE")

    expect(employee.reload.country_code).to eq("DE")
    expect(salary.reload).to have_attributes(amount: BigDecimal("2400000"), currency: "INR", effective_to: nil)
  end

  it "refuses fields that cannot be changed here, and changes nothing" do
    result = call(full_name: "New Name", hire_date: "2010-01-01", employee_number: "EMP-123456", salary: { amount: "1" })

    expect(result).not_to be_success
    expect(result.errors).to eq(
      "hire_date" => [ "cannot be changed after the employee is created" ],
      "employee_number" => [ "cannot be changed after the employee is created" ],
      "salary" => [ "is changed by recording a salary change, not by editing the employee" ]
    )
    expect(employee.reload.full_name).to eq("Asha Rao")
  end

  it "returns field errors for invalid values and saves nothing" do
    result = call(full_name: "", status: "retired", country_code: "XX")

    expect(result.errors.keys).to contain_exactly("full_name", "status", "country_code")
    expect(employee.reload.full_name).to eq("Asha Rao")
  end

  it "reports a duplicate email caught only by the database as a field error" do
    allow(employee).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

    expect(call(email: "new@acme.example").errors).to eq("email" => [ "has already been taken" ])
  end

  it "reports a duplicate email" do
    create(:employee, email: "taken@acme.example")

    expect(call(email: "TAKEN@acme.example").errors).to eq("email" => [ "has already been taken" ])
  end
end

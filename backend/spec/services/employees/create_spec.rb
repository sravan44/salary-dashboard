require "rails_helper"

RSpec.describe Employees::Create do
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Date.new(2026, 10, 10)) { example.run } }

  let(:attributes) do
    {
      full_name: "Meera Iyer", email: "Meera.Iyer@ACME.example", country_code: "IN", department: "Engineering",
      job_title: "Software Engineer", hire_date: "2026-10-01", salary: { amount: "1850000.50", currency: "INR" }
    }
  end

  def call(overrides = {}) = described_class.call(attributes.merge(overrides))

  it "creates an active employee and their first salary, starting on the hire date" do
    result = call

    expect(result).to be_success
    employee = result.employee.reload
    expect(employee).to have_attributes(full_name: "Meera Iyer", email: "meera.iyer@acme.example", status: "active",
                                        hire_date: Date.new(2026, 10, 1))
    expect(employee.compensations.sole).to have_attributes(
      amount: BigDecimal("1850000.50"), currency: "INR", effective_from: Date.new(2026, 10, 1), effective_to: nil, reason: "hire"
    )
  end

  it "assigns the next employee number" do
    create(:employee, employee_number: "EMP-000041")
    create(:employee, employee_number: "EMP-000007")

    expect(call.employee.employee_number).to eq("EMP-000042")
  end

  it "starts numbering at EMP-000001 when there are no employees" do
    expect(call.employee.employee_number).to eq("EMP-000001")
  end

  it "ignores an employee number or status sent by the caller" do
    employee = call(employee_number: "EMP-999999", status: "terminated").employee

    expect(employee).to have_attributes(employee_number: "EMP-000001", status: "active")
  end

  it "writes an audit entry for the employee and the salary, with who did it" do
    Current.actor = "unauthenticated"
    employee = call.employee

    expect(Version.where(item: employee).pluck(:event, :whodunnit)).to eq([ %w[create unauthenticated] ])
    expect(Version.where(item: employee.compensations.sole).pluck(:event)).to eq([ "create" ])
  end

  describe "validation (nothing is saved when anything is invalid)" do
    def expect_rejected(overrides, errors)
      result = nil
      expect { result = call(overrides) }.not_to change { [ Employee.count, Compensation.count, Version.count ] }
      expect(result).not_to be_success
      expect(result.errors).to include(errors)
    end

    it "rejects an invalid salary and keeps the employee unsaved" do
      expect_rejected({ salary: { amount: "0", currency: "INR" } }, "salary.amount" => [ "must be greater than 0" ])
    end

    it "rejects an unsupported or missing salary currency" do
      expect_rejected({ salary: { amount: "100", currency: "XYZ" } }, "salary.currency" => [ "is not included in the list" ])
      expect_rejected({ salary: nil }, "salary.amount" => [ "is not a number" ])
    end

    it "rejects a hire date in the future, since salaries cannot start in the future" do
      expect_rejected({ hire_date: "2026-10-11" }, "hire_date" => [ "can't be in the future" ])
    end

    it "rejects a missing or malformed hire date" do
      expect_rejected({ hire_date: "" }, "hire_date" => [ "can't be blank" ])
      expect_rejected({ hire_date: "2026-02-30" }, "hire_date" => [ "can't be blank" ])
    end

    it "reports profile and salary problems together" do
      result = call(full_name: "", country_code: "XX", salary: { amount: "-5", currency: "INR" })

      expect(result.errors.keys).to contain_exactly("full_name", "country_code", "salary.amount")
    end

    it "rejects an email that is already in use, whatever its case" do
      create(:employee, email: "meera.iyer@acme.example")

      expect_rejected({}, "email" => [ "has already been taken" ])
    end

    it "reports an email taken between validation and saving as a field error" do
      allow_any_instance_of(Employee).to receive(:save!).and_wrap_original do |original|
        build(:employee, email: "meera.iyer@acme.example").save # another request wins the email first
        original.call
      end

      result = call
      expect(result).not_to be_success
      expect(result.errors).to eq("email" => [ "has already been taken" ])
    end

    it "fails loudly rather than reuse a number once EMP-999999 is taken" do
      create(:employee, employee_number: "EMP-999999")

      expect { call }.to raise_error(RuntimeError, "Employee numbers exhausted")
    end

    it "reports a duplicate email caught only by the database (a concurrent create) as a field error" do
      allow_any_instance_of(Employee).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique, "index_employees_on_email")

      expect_rejected({}, "email" => [ "has already been taken" ])
    end
  end

  describe "two creates at the same moment" do
    self.use_transactional_tests = false

    after do
      Version.delete_all
      Compensation.delete_all
      Employee.delete_all
    end

    it "never gives two employees the same number" do
      results = Array.new(4) do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            call(email: "person#{i}@acme.example").employee.employee_number
          end
        end
      end.map(&:value)

      expect(results.sort).to eq(%w[EMP-000001 EMP-000002 EMP-000003 EMP-000004])
    end
  end
end

require "rails_helper"

RSpec.describe Employee do
  describe "validations" do
    it "is valid with complete, supported attributes" do
      expect(build(:employee)).to be_valid
    end

    it "requires the core profile fields" do
      employee = described_class.new

      expect(employee).not_to be_valid
      expect(employee.errors.attribute_names).to include(
        :employee_number, :full_name, :email, :country_code, :department, :job_title, :hire_date
      )
    end

    it "requires employee numbers in the EMP-000000 format" do
      expect(build(:employee, employee_number: "123")).not_to be_valid
    end

    it "rejects a duplicate employee number" do
      create(:employee, employee_number: "EMP-000001")

      expect(build(:employee, employee_number: "EMP-000001")).not_to be_valid
    end

    it "stores email in lower case and rejects a duplicate regardless of case" do
      create(:employee, email: "  Asha.Rao@ACME.example ")

      expect(described_class.last.email).to eq("asha.rao@acme.example")
      expect(build(:employee, email: "ASHA.RAO@acme.example")).not_to be_valid
    end

    it "rejects a malformed email" do
      expect(build(:employee, email: "not-an-email")).not_to be_valid
    end

    it "says a missing country or department can't be blank (not that it's an unknown value)" do
      employee = build(:employee, country_code: "", department: nil)
      employee.validate

      expect(employee.errors.to_hash).to include(country_code: [ "can't be blank" ], department: [ "can't be blank" ])
    end

    it "rejects unsupported countries and departments" do
      expect(build(:employee, country_code: "XX")).not_to be_valid
      expect(build(:employee, department: "Astrology")).not_to be_valid
    end

    it "only allows active or terminated status" do
      expect(build(:employee, status: "on_vacation")).not_to be_valid
      expect(build(:employee, status: "terminated")).to be_valid
    end
  end

  describe "database constraints (the last line of defence)" do
    it "enforces unique employee numbers even when validations are skipped" do
      create(:employee, employee_number: "EMP-000007")
      duplicate = build(:employee, employee_number: "EMP-000007")

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces a known status even when validations are skipped" do
      employee = create(:employee)

      expect { employee.update_column(:status, "unknown") }.to raise_error(ActiveRecord::StatementInvalid, /check/i)
    end
  end

  describe "#current_compensation" do
    it "is the record with no end date, ignoring closed history" do
      employee = create(:employee)
      create(:compensation, employee:, amount: "100000", effective_from: Date.new(2020, 1, 15), effective_to: Date.new(2022, 12, 31))
      current = create(:compensation, employee:, amount: "110000", effective_from: Date.new(2023, 1, 1))

      expect(employee.reload.current_compensation).to eq(current)
    end
  end

  it "cannot be deleted while it has salary history, so history is never lost" do
    employee = create(:employee)
    create(:compensation, employee:)

    expect { employee.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end

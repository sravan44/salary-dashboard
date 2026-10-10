require "rails_helper"

RSpec.describe Compensation do
  let(:employee) { create(:employee) }

  describe "validations" do
    it "is valid with a positive amount, supported currency and start date" do
      expect(build(:compensation, employee:)).to be_valid
    end

    it "keeps money exact as a decimal, never a float" do
      compensation = create(:compensation, employee:, amount: "123456.78")

      expect(compensation.reload.amount).to eq(BigDecimal("123456.78"))
      expect(compensation.amount).to be_a(BigDecimal)
    end

    it "rejects zero and negative amounts" do
      expect(build(:compensation, employee:, amount: 0)).not_to be_valid
      expect(build(:compensation, employee:, amount: -1)).not_to be_valid
    end

    it "rejects amounts beyond numeric(14,2)" do
      expect(build(:compensation, employee:, amount: "1000000000000")).not_to be_valid
    end

    it "rejects an unsupported currency" do
      expect(build(:compensation, employee:, currency: "XYZ")).not_to be_valid
    end

    it "requires a start date" do
      expect(build(:compensation, employee:, effective_from: nil)).not_to be_valid
    end

    it "rejects an end date before the start date" do
      record = build(:compensation, employee:, effective_from: Date.new(2024, 1, 1), effective_to: Date.new(2023, 12, 31))

      expect(record).not_to be_valid
      expect(record.errors[:effective_to]).to include("must be on or after the start date")
    end

    it "records why the salary changed, from a fixed list of reasons" do
      %w[hire annual_review promotion market_adjustment correction].each do |reason|
        expect(build(:compensation, employee:, reason:)).to be_valid
      end
      expect(build(:compensation, employee:, reason: "because")).not_to be_valid
      expect(build(:compensation, employee:, reason: nil)).not_to be_valid
    end

    it "keeps optional notes short enough to read" do
      expect(build(:compensation, employee:, notes: "Annual cycle 2026, rating: exceeds")).to be_valid
      expect(build(:compensation, employee:, notes: "x" * 1_001)).not_to be_valid
    end

    it "allows a record that starts and ends on the same day" do
      expect(build(:compensation, employee:, effective_from: Date.new(2024, 1, 1), effective_to: Date.new(2024, 1, 1))).to be_valid
    end
  end

  describe "database constraints (the last line of defence)" do
    it "allows only one current salary per employee" do
      create(:compensation, employee:, effective_from: Date.new(2020, 1, 1))
      second_current = build(:compensation, employee:, effective_from: Date.new(2021, 1, 1))

      expect { second_current.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows many closed records alongside one current record" do
      create(:compensation, employee:, effective_from: Date.new(2020, 1, 1), effective_to: Date.new(2020, 12, 31))
      create(:compensation, employee:, effective_from: Date.new(2021, 1, 1), effective_to: Date.new(2021, 12, 31))
      create(:compensation, employee:, effective_from: Date.new(2022, 1, 1))

      expect(employee.compensations.count).to eq(3)
      expect(employee.compensations.current.count).to eq(1)
    end

    it "rejects two records starting on the same day" do
      create(:compensation, employee:, effective_from: Date.new(2020, 1, 1), effective_to: Date.new(2020, 6, 30))
      clash = build(:compensation, employee:, effective_from: Date.new(2020, 1, 1), effective_to: Date.new(2020, 3, 31))

      expect { clash.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a non-positive amount even when validations are skipped" do
      record = create(:compensation, employee:)

      expect { record.update_column(:amount, 0) }.to raise_error(ActiveRecord::StatementInvalid, /check/i)
    end

    it "rejects an unknown reason even when validations are skipped" do
      record = create(:compensation, employee:)

      expect { record.update_column(:reason, "bonus") }.to raise_error(ActiveRecord::StatementInvalid, /check/i)
    end

    it "rejects an end date before the start date even when validations are skipped" do
      record = create(:compensation, employee:, effective_from: Date.new(2024, 1, 1))

      expect { record.update_column(:effective_to, Date.new(2023, 1, 1)) }.to raise_error(ActiveRecord::StatementInvalid, /check/i)
    end
  end
end

require "rails_helper"

RSpec.describe Compensations::RecordChange do
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Date.new(2026, 10, 10)) { example.run } }

  let(:employee) { create(:employee, hire_date: Date.new(2024, 4, 1)) }
  let!(:hired) { create(:compensation, employee:, amount: "100000", currency: "USD", effective_from: Date.new(2024, 4, 1), effective_to: Date.new(2025, 3, 31), reason: "hire") }
  let!(:current) { create(:compensation, employee:, amount: "110000", currency: "USD", effective_from: Date.new(2025, 4, 1), reason: "annual_review") }

  let(:raise_params) { { amount: "121000.50", currency: "USD", effective_from: "2026-10-01", reason: "promotion", notes: "Promoted to Senior" } }

  def call(overrides = {}) = described_class.call(employee_id: employee.id, attributes: raise_params.merge(overrides))

  it "closes the current salary the day before the new one starts, and adds the new one as current" do
    Current.actor = "hr@acme.example"
    result = call

    expect(result).to be_success
    expect(current.reload.effective_to).to eq(Date.new(2026, 9, 30))
    expect(result.compensation).to have_attributes(
      amount: BigDecimal("121000.50"), currency: "USD", effective_from: Date.new(2026, 10, 1), effective_to: nil,
      reason: "promotion", notes: "Promoted to Senior", revised_by: "hr@acme.example"
    )
    expect(employee.compensations.current.sole).to eq(result.compensation)
    expect(hired.reload.effective_to).to eq(Date.new(2025, 3, 31)) # older history untouched
  end

  it "audits both the closing of the old record and the new one" do
    Current.actor = "hr@acme.example"
    new_record = call.compensation

    expect(Version.where(item: current, event: "update").sole)
      .to have_attributes(whodunnit: "hr@acme.example", object_changes: { "effective_to" => [ nil, "2026-09-30" ] })
    expect(Version.where(item: new_record).sole.event).to eq("create")
  end

  it "allows a currency change (e.g. a relocation)" do
    expect(call(currency: "EUR", amount: "98000")).to be_success
  end

  it "accepts today as the start date" do
    expect(call(effective_from: "2026-10-10")).to be_success
  end

  describe "rejections leave the history exactly as it was" do
    def expect_rejected(overrides, errors)
      result = nil
      expect { result = call(overrides) }.not_to change { [ Compensation.count, Version.count, current.reload.effective_to ] }
      expect(result).not_to be_success
      expect(result.errors).to include(errors)
    end

    it "rejects a start date on or before the current salary's start" do
      expect_rejected({ effective_from: "2025-04-01" }, "effective_from" => [ "must be after the current salary's start date (2025-04-01)" ])
      expect_rejected({ effective_from: "2025-01-01" }, "effective_from" => [ "must be after the current salary's start date (2025-04-01)" ])
    end

    it "rejects a start date in the future (no scheduled raises yet)" do
      expect_rejected({ effective_from: "2026-10-11" }, "effective_from" => [ "can't be in the future" ])
    end

    it "rejects a missing or invalid date" do
      expect_rejected({ effective_from: "" }, "effective_from" => [ "can't be blank" ])
      expect_rejected({ effective_from: "2026-02-30" }, "effective_from" => [ "can't be blank" ])
    end

    it "rejects a non-positive amount and an unsupported currency" do
      expect_rejected({ amount: "0", currency: "XYZ" }, "amount" => [ "must be greater than 0" ], "currency" => [ "is not included in the list" ])
    end

    it "rejects 'hire' and unknown reasons" do
      message = [ "must be one of: annual_review, promotion, market_adjustment, correction" ]
      expect_rejected({ reason: "hire" }, "reason" => message)
      expect_rejected({ reason: "bonus" }, "reason" => message)
    end

    it "rejects a pay change for a deactivated employee" do
      employee.update!(status: "terminated")

      expect_rejected({}, "employee" => [ "is deactivated; reactivate them before recording a pay change" ])
    end

    it "rolls back the closing of the old record if adding the new one fails" do
      allow(Compensation).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "simulated failure")

      expect { call }.to raise_error(ActiveRecord::StatementInvalid)
      expect(current.reload.effective_to).to be_nil
      expect(employee.compensations.count).to eq(2)
    end
  end

  it "records the first salary for an employee who has none" do
    other = create(:employee, hire_date: Date.new(2026, 1, 5))

    result = described_class.call(employee_id: other.id, attributes: raise_params.merge(effective_from: "2026-02-01", reason: "correction"))
    expect(result).to be_success
    expect(other.compensations.current.sole.amount).to eq(BigDecimal("121000.50"))
  end

  it "raises not found for an unknown employee" do
    expect { described_class.call(employee_id: 0, attributes: raise_params) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  describe "two changes recorded at the same moment" do
    self.use_transactional_tests = false

    after do
      Version.delete_all
      Compensation.delete_all
      Employee.delete_all
    end

    it "applies them one after the other: one current salary, no overlapping periods" do
      dates = %w[2026-09-01 2026-10-01 2026-08-15 2026-07-01]
      results = dates.map do |date|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection { call(effective_from: date, amount: "130000") }
        end
      end.map(&:value)

      history = employee.compensations.order(:effective_from).to_a
      expect(results.count(&:success?)).to be >= 1
      expect(history.count { |c| c.effective_to.nil? }).to eq(1)
      history.each_cons(2) { |older, newer| expect(older.effective_to).to eq(newer.effective_from - 1) }
    end
  end
end

require "rails_helper"

# Every expected number below is derived by hand from spec/support/insights_fixture.rb.
RSpec.describe "Insights queries" do
  before { create_insights_fixture }

  let(:everyone) { Insights::Population.new }

  describe Insights::SummaryQuery do
    subject(:summary) { described_class.new(everyone).call }

    it "counts only active employees" do
      expect(summary.headcount).to eq(6) # 7 employees, 1 terminated
    end

    it "counts distinct countries" do
      expect(summary.countries_count).to eq(4)
    end

    it "gives headcount per currency, largest first, never a combined amount" do
      expect(summary.currencies).to eq([ { currency: "USD", headcount: 3 }, { currency: "EUR", headcount: 2 },
                                          { currency: "INR", headcount: 1 } ])
    end

    it "gives headcount per country, largest first" do
      expect(summary.headcount_by_country).to eq([ { country_code: "US", headcount: 3 }, { country_code: "DE", headcount: 1 },
                                                    { country_code: "FR", headcount: 1 }, { country_code: "IN", headcount: 1 } ])
    end

    it "gives headcount per department, largest first" do
      expect(summary.headcount_by_department).to eq([ { department: "Engineering", headcount: 3 }, { department: "People", headcount: 2 },
                                                       { department: "Sales", headcount: 1 } ])
    end

    it "counts current employees by the year they were hired, oldest year first" do
      Employee.find_by!(employee_number: "EMP-000005").update!(hire_date: Date.new(2023, 6, 1))

      expect(summary.hires_by_year).to eq([ { year: 2020, headcount: 5 }, { year: 2023, headcount: 1 } ])
    end

    it "applies the dashboard filters" do
      us = described_class.new(Insights::Population.new(country: "US")).call

      expect(us.headcount).to eq(3)
      expect(us.currencies).to eq([ { currency: "USD", headcount: 3 } ])
    end
  end

  describe Insights::PayStatsQuery do
    def stats(group_by, population: everyone, **options)
      described_class.new(population, group_by:, **options).call
    end

    it "keeps every group's figures within one currency" do
      expect(stats(:country)).to eq([
        { group: "US", currency: "USD", headcount: 3, min: "90000.00", max: "120000.00", avg: "103333.33", median: "100000.00" },
        { group: "DE", currency: "EUR", headcount: 1, min: "72000.00", max: "72000.00", avg: "72000.00", median: "72000.00" },
        { group: "FR", currency: "EUR", headcount: 1, min: "65000.00", max: "65000.00", avg: "65000.00", median: "65000.00" },
        { group: "IN", currency: "INR", headcount: 1, min: "2400000.00", max: "2400000.00", avg: "2400000.00", median: "2400000.00" }
      ])
    end

    it "splits a department that pays in two currencies into two rows instead of adding them up" do
      engineering = stats(:department).select { |row| row[:group] == "Engineering" }

      expect(engineering).to contain_exactly(
        include(currency: "USD", headcount: 2, avg: "110000.00", median: "110000.00"),
        include(currency: "INR", headcount: 1, avg: "2400000.00")
      )
    end

    it "takes the median of an even count as the mean of the two middle values" do
      people = stats(:department).find { |row| row[:group] == "People" }

      expect(people).to include(currency: "EUR", headcount: 2, median: "68500.00", min: "65000.00", max: "72000.00")
    end

    it "uses only the current salary, not older history" do
      sales = stats(:department).find { |row| row[:group] == "Sales" }

      expect(sales).to include(min: "90000.00", max: "90000.00")
    end

    it "can be narrowed to one currency, for single-currency charts" do
      expect(stats(:department, currency: "USD").map { |row| row[:group] }).to eq(%w[Engineering Sales])
    end

    it "groups by job title, breaks headcount ties alphabetically, and respects the limit" do
      expect(stats(:job_title).map { |r| [ r[:group], r[:currency], r[:headcount] ] }).to eq([
        [ "HR Generalist", "EUR", 2 ], [ "Software Engineer", "USD", 2 ], [ "Account Executive", "USD", 1 ], [ "Software Engineer", "INR", 1 ]
      ])
      expect(stats(:job_title, limit: 1).map { |r| r[:group] }).to eq([ "HR Generalist" ])
    end

    it "applies the dashboard filters" do
      rows = stats(:job_title, population: Insights::Population.new(department: "People"))

      expect(rows).to eq([ { group: "HR Generalist", currency: "EUR", headcount: 2, min: "65000.00", max: "72000.00",
                             avg: "68500.00", median: "68500.00" } ])
    end

    it "rejects a grouping outside the allowlist" do
      expect { stats(:email) }.to raise_error(ArgumentError, /group_by/)
    end
  end

  describe Insights::DistributionQuery do
    def distribution(currency, buckets: 5, population: everyone)
      described_class.new(population, currency:, buckets:).call
    end

    it "splits the range of one currency into equal-width buckets whose counts add up to the headcount" do
      result = distribution("USD") # 90,000 .. 120,000 in 5 buckets of 6,000

      expect(result.map { |b| [ b[:from], b[:to], b[:count] ] }).to eq([
        [ "90000.00", "96000.00", 1 ], [ "96000.00", "102000.00", 1 ], [ "102000.00", "108000.00", 0 ],
        [ "108000.00", "114000.00", 0 ], [ "114000.00", "120000.00", 1 ]
      ])
      expect(result.sum { |b| b[:count] }).to eq(3)
    end

    it "uses a single bucket when everyone in that currency earns the same" do
      expect(distribution("INR")).to eq([ { from: "2400000.00", to: "2400000.00", count: 1 } ])
    end

    it "returns no buckets for a currency nobody in the population is paid in" do
      expect(distribution("SGD")).to eq([])
    end

    it "applies the dashboard filters" do
      result = distribution("EUR", buckets: 5, population: Insights::Population.new(country: "FR"))

      expect(result.sum { |b| b[:count] }).to eq(1)
    end
  end

  describe Insights::Population do
    it "filters by country, department and job title together" do
      population = described_class.new(country: "US", department: "Engineering", job_title: "Software Engineer")

      expect(population.relation.count).to eq(2)
    end

    it "ignores blank filters" do
      expect(described_class.new(country: "", department: nil).relation.count).to eq(6)
    end
  end
end

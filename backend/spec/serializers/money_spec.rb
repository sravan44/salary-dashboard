require "rails_helper"

RSpec.describe Money do
  describe ".format_amount" do
    it "always shows exactly two decimals" do
      expect(described_class.format_amount(BigDecimal("120000"))).to eq("120000.00")
      expect(described_class.format_amount(BigDecimal("1234.5"))).to eq("1234.50")
      expect(described_class.format_amount(BigDecimal("99.99"))).to eq("99.99")
    end

    it "stays exact for the largest numeric(14,2) amount, where a float would lose digits" do
      expect(described_class.format_amount(BigDecimal("999999999999.99"))).to eq("999999999999.99")
    end

    it "returns nil when there is no amount" do
      expect(described_class.format_amount(nil)).to be_nil
    end
  end
end

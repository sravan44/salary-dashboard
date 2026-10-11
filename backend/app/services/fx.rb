# Indicative currency conversion for analytics. Reference rates come from the ECB via Frankfurter,
# are cached in `fx_rates` (EUR base, as published), and are never used to change stored salaries.
module Fx
  BASE = "EUR".freeze
  SOURCE = "ECB reference rates via Frankfurter".freeze

  class ProviderError < StandardError; end

  # How a rate is shown in provenance: exact to 10 decimal places ("0.0119047619", "1.1").
  def self.display_rate(rate) = rate.round(10).to_s("F")
end

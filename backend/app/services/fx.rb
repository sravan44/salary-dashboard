# Indicative currency conversion for analytics. Reference rates come from the ECB via Frankfurter,
# are cached in `fx_rates` (EUR base, as published), and are never used to change stored salaries.
module Fx
  BASE = "EUR".freeze
  SOURCE = "ECB reference rates via Frankfurter".freeze

  class ProviderError < StandardError; end
end

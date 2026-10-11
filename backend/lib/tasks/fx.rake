namespace :fx do
  desc "Fetch the latest ECB reference rates from Frankfurter into fx_rates (one request; safe to re-run)"
  task refresh: :environment do
    result = Fx::Refresh.call
    puts "Stored #{result[:stored]} rates for #{result[:date].iso8601} (#{Fx::SOURCE})"
  rescue Fx::ProviderError => e
    abort "FX refresh failed: #{e.message}. Existing rates are unchanged."
  end
end

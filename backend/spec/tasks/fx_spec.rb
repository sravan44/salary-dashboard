require "rails_helper"
require "rake"

RSpec.describe "fx:refresh" do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "fx:refresh" } }

  def run
    task = Rake::Task["fx:refresh"]
    task.reenable
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    task.invoke
    output.string
  ensure
    $stdout = original_stdout
  end

  it "stores the latest rates and says which date and source they are" do
    allow(Fx::FrankfurterClient).to receive(:new).and_return(FxHelpers::FakeProvider.new(rates: { "USD" => "1.10", "INR" => "92.40" }))

    expect(run).to include("Stored 2 rates for 2026-10-09 (ECB reference rates via Frankfurter)")
    expect(FxRate.count).to eq(2)
  end

  it "exits with an error, keeping the existing rates, when the provider fails" do
    allow(Fx::FrankfurterClient).to receive(:new).and_return(FxHelpers::FakeProvider.new(error: Fx::ProviderError.new("could not reach Frankfurter (Net::OpenTimeout)")))

    expect { run }.to raise_error(SystemExit).and output(/FX refresh failed: could not reach Frankfurter/).to_stderr
  end
end

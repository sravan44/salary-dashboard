require "rails_helper"

# config/recurring.yml is read by Solid Queue's scheduler; this checks it says what we mean.
RSpec.describe "Recurring jobs (config/recurring.yml)" do
  def tasks(env) = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml")).fetch(env)

  %w[production development].each do |env|
    it "refreshes exchange rates on weekdays at 16:30 Frankfurt time in #{env}, after the ECB publishes" do
      task = tasks(env).fetch("refresh_exchange_rates")
      expect(task).to include("class" => "FxRefreshJob")

      schedule = Fugit.parse_cronish(task.fetch("schedule"))
      friday_evening = Time.find_zone("Europe/Berlin").local(2026, 10, 9, 17, 0)
      next_run = schedule.next_time(friday_evening).to_t.in_time_zone("Europe/Berlin")

      expect(next_run).to eq(Time.find_zone("Europe/Berlin").local(2026, 10, 12, 16, 30)) # the following Monday
    end
  end

  it "is a schedule Solid Queue accepts" do
    task = SolidQueue::RecurringTask.from_configuration("refresh_exchange_rates", **tasks("production").fetch("refresh_exchange_rates").symbolize_keys)

    expect(task).to be_valid
  end
end

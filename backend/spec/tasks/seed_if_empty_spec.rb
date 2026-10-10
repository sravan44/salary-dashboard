require "rails_helper"
require "rake"

# The container runs `bin/rails app:seed_if_empty` on every start, so a fresh database gets demo data
# without a manual step, and an existing database is never touched.
RSpec.describe "app:seed_if_empty" do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "app:seed_if_empty" } }

  def run_task(env)
    task = Rake::Task["app:seed_if_empty"]
    task.reenable
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    with_env(env) { task.invoke }
    output.string
  ensure
    $stdout = original_stdout
  end

  # Minimal ENV override that always restores the previous values.
  def with_env(env)
    previous = env.keys.to_h { |key| [ key, ENV[key] ] }
    env.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  it "seeds an empty database when AUTO_SEED is on" do
    output = run_task("AUTO_SEED" => "true", "SEED_EMPLOYEES" => "40")

    expect(Employee.count).to eq(40)
    expect(Compensation.current.count).to eq(40)
    expect(output).to include("Seeded 40 employees")
    expect(User.pluck(:email)).to contain_exactly("admin@acme.example", "hr@acme.example", "viewer@acme.example")
  end

  it "never touches a database that already has employees" do
    existing = create(:employee)

    output = run_task("AUTO_SEED" => "true", "SEED_EMPLOYEES" => "40")

    expect(Employee.pluck(:id)).to eq([ existing.id ])
    expect(output).to include("already has 1 employees; not seeding")
  end

  it "does nothing unless AUTO_SEED is on" do
    output = run_task("AUTO_SEED" => nil, "SEED_EMPLOYEES" => "40")

    expect(Employee.count).to eq(0)
    expect(output).to include("AUTO_SEED is not enabled")
  end
end

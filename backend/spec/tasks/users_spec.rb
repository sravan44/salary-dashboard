require "rails_helper"
require "rake"

RSpec.describe "users rake tasks" do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "users:create" } }

  def run(name, env)
    task = Rake::Task[name]
    task.reenable
    previous = env.keys.to_h { |key| [ key, ENV[key] ] }
    env.each { |key, value| ENV[key] = value }
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    task.invoke
    output.string
  ensure
    $stdout = original_stdout
    previous.each { |key, value| ENV[key] = value }
  end

  describe "users:create" do
    it "creates a user with the given roles; the password comes from the environment and is never printed" do
      output = run("users:create", "EMAIL" => "first.admin@acme.example", "ROLES" => "admin,hr_manager", "PASSWORD" => "a long secret password")

      user = User.find_by!(email: "first.admin@acme.example")
      expect(user.roles).to eq(%w[hr_manager admin])
      expect(user.authenticate("a long secret password")).to be_truthy
      expect(output).to include("Created first.admin@acme.example")
      expect(output).not_to include("a long secret password")
    end

    it "refuses to change an existing user" do
      create(:user, email: "taken@acme.example")

      expect { run("users:create", "EMAIL" => "taken@acme.example", "ROLES" => "admin", "PASSWORD" => "a long secret password") }
        .to raise_error(SystemExit).and output(/already exists/).to_stderr
    end

    it "explains invalid input instead of saving" do
      expect { run("users:create", "EMAIL" => "x@acme.example", "ROLES" => "root", "PASSWORD" => "short") }
        .to raise_error(SystemExit).and output(/(?=.*unknown role: root)(?=.*Password is too short)/m).to_stderr
      expect(User.count).to eq(0)
    end
  end

  describe "users:seed_demo" do
    it "creates the demo sign-ins with the documented password when none is given (outside production)" do
      output = run("users:seed_demo", "DEMO_USER_PASSWORD" => nil)

      expect(User.order(:email).pluck(:email)).to eq(%w[admin@acme.example hr@acme.example viewer@acme.example])
      expect(output).to include("Created demo users: admin@acme.example, hr@acme.example, viewer@acme.example")
    end

    it "creates nothing in production without DEMO_USER_PASSWORD, and says so" do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect(run("users:seed_demo", "DEMO_USER_PASSWORD" => nil)).to include("no demo users in production")
      expect(User.count).to eq(0)
    end

    it "reports when there is nothing to create" do
      run("users:seed_demo", "DEMO_USER_PASSWORD" => nil)

      expect(run("users:seed_demo", "DEMO_USER_PASSWORD" => nil)).to include("Demo users already exist")
    end
  end
end

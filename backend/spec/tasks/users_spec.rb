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
    it "does nothing without DEMO_USER_PASSWORD" do
      output = run("users:seed_demo", "DEMO_USER_PASSWORD" => nil)

      expect(output).to include("DEMO_USER_PASSWORD is not set")
      expect(User.count).to eq(0)
    end

    it "creates one demo user per role, and leaves existing users alone on a re-run" do
      run("users:seed_demo", "DEMO_USER_PASSWORD" => "a local demo password")
      User.find_by!(email: "viewer@acme.example").update!(password: "changed by the user")
      run("users:seed_demo", "DEMO_USER_PASSWORD" => "a local demo password")

      expect(User.order(:email).pluck(:email, :roles)).to eq([
        [ "admin@acme.example", %w[hr_manager admin] ], [ "hr@acme.example", %w[hr_manager] ], [ "viewer@acme.example", %w[viewer] ]
      ])
      expect(User.find_by!(email: "viewer@acme.example").authenticate("changed by the user")).to be_truthy
    end
  end
end

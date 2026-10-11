# Run the current release with Docker Compose. Hooked after every publish, which includes `deploy:rollback`,
# so a rollback rebuilds and runs the previous release the same way.
namespace :docker do
  compose = ->(*args) { [ :docker, "compose", "-f", fetch(:compose_file), *args ] }

  desc "Build the image from the current release and (re)start the database and app containers"
  task :up do
    on roles(:app) do
      within current_path do
        execute(*compose.("up", "--detach", "--build", "--remove-orphans"))
        execute :docker, "image", "prune", "--force" # drop the previous release's dangling image
      end
    end
  end

  desc "Wait until the app answers its health check"
  task :health do
    on roles(:app) do
      healthy = false
      fetch(:health_attempts).times do
        break healthy = true if test("curl --fail --silent --output /dev/null #{fetch(:health_url)}")

        sleep 5
      end
      unless healthy
        within(current_path) { execute(*compose.("logs", "--tail", "60", "app")) }
        raise "The app did not answer #{fetch(:health_url)}; its last log lines are above"
      end
      info "Healthy: #{fetch(:health_url)}"
    end
  end

  desc "Show the containers' state"
  task :ps do
    on(roles(:app)) { within(current_path) { execute(*compose.("ps")) } }
  end

  desc "Show the app's recent log (LINES=100)"
  task :logs do
    on(roles(:app)) { within(current_path) { execute(*compose.("logs", "--tail", ENV.fetch("LINES", "100"), "app")) } }
  end
end

after "deploy:published", "docker:up"
after "docker:up", "docker:health"

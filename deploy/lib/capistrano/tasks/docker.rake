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
        # Asked inside the app container, so it works the same with or without Caddy's HTTPS in front.
        break healthy = true if test(:docker, "compose", "-f", "#{current_path}/#{fetch(:compose_file)}",
                                     "exec", "-T", "app", "curl", "--fail", "--silent", "--output", "/dev/null",
                                     "http://localhost:3000/up")

        sleep 5
      end
      unless healthy
        within(current_path) { execute(*compose.("logs", "--tail", "60", "app")) }
        raise "The app did not answer /up; its last log lines are above"
      end
      info "Healthy: the app answers /up"
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

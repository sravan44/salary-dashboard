# Capistrano driving Docker: each deploy checks out the repository into a new release folder on the server,
# then `docker compose` builds the image from that release and replaces the running app container.
# PostgreSQL runs in its own container with a named volume, so data survives every deploy and rollback.
lock "~> 3.19"

set :application, "salary-dashboard"
set :repo_url, "https://github.com/sravan44/salary-dashboard.git" # public: the server clones without a key
set :branch, ENV.fetch("BRANCH", "main") # deploy/deploy.env or the shell
set :deploy_to, "/home/ubuntu/salary-dashboard"
set :keep_releases, 3

# Secrets live only on the server (shared/.env, mode 600, written by deploy/server-setup.sh); each release links to it.
append :linked_files, ".env"

set :compose_file, "compose.production.yaml"
set :health_attempts, 60 # × 5 s: the first start builds the image, migrates and seeds 10,000 employees

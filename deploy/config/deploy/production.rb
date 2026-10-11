# The EC2 instance (t3.micro, Ubuntu 24.04). Its address, login and SSH key come from deploy/deploy.env
# (git-ignored; copy deploy/deploy.env.example) or the shell, so none of them is in git.
server DeployEnv.fetch("DEPLOY_HOST"), user: ENV.fetch("DEPLOY_USER", "ubuntu"), roles: %w[app]

set :ssh_options, {
  keys: [ File.expand_path(ENV.fetch("DEPLOY_KEY", "~/.ssh/salary-dashboard.pem")) ],
  auth_methods: %w[publickey],
  forward_agent: false
}

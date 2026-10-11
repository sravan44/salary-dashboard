# Deploying with Capistrano (EC2 + Docker Compose)

Run every command below from your machine. `<ip>` is the instance's public or Elastic IP, and `<key>.pem` is its key pair file.

## Once per instance

1. **Key file.** Move it out of Downloads and make it private:
   ```bash
   mkdir -p ~/.ssh && mv ~/Downloads/<key>.pem ~/.ssh/ && chmod 600 ~/.ssh/<key>.pem
   ```
2. **Security group.** Allow SSH (22) from your IP and HTTP (80) from anywhere.
3. **Check SSH.** This should print Ubuntu 24.04 and about 1 GB of memory:
   ```bash
   ssh -i ~/.ssh/<key>.pem ubuntu@<ip> 'lsb_release -ds; free -h; df -h /'
   ```
4. **Prepare the server.** This adds swap, installs Docker and creates the secrets in `~/salary-dashboard/shared/.env`. It prints the demo password once; save it.
   ```bash
   ssh -i ~/.ssh/<key>.pem ubuntu@<ip> 'bash -s' < deploy/server-setup.sh
   ```

## Once per machine you deploy from

```bash
cd deploy
bundle install
cp deploy.env.example deploy.env
```
Then edit `deploy.env` (git-ignored):
```
DEPLOY_HOST=<ip>
DEPLOY_USER=ubuntu
DEPLOY_KEY=~/.ssh/<key>.pem
BRANCH=main
```

## Every deploy

The server clones from GitHub, so **push first**: only pushed commits are deployed.
```bash
cd deploy
bundle exec cap production deploy
```
The first deploy builds the image on the server, which takes about 10–15 minutes on a t3.micro. Later deploys reuse cached layers. The deploy ends with `Healthy: http://localhost/up`, or with the app's last log lines if it failed.

Then open `http://<ip>`. Use plain **http**: there's no certificate yet.

## Checking and fixing

| Command (from `deploy/`) | What it does |
|---|---|
| `bundle exec cap production docker:ps` | Show the containers' state |
| `bundle exec cap production docker:logs` | Show the app's last 100 log lines (`LINES=300` for more) |
| `bundle exec cap production deploy:rollback` | Run the previous release again; the database is untouched |
| `BRANCH=my-branch bundle exec cap production deploy` | Deploy another pushed branch |

From the repository root:
```bash
SMOKE_PASSWORD='<demo password>' ruby backend/script/smoke.rb http://<ip>
```
This runs the 16 end-to-end checks and exits 1 if any fails.

## Troubleshooting
- **`Permission denied (publickey)`:** check the wrong key, user or IP. Ubuntu AMIs log in as `ubuntu`.
- **`linked file … .env does not exist`:** step 4 hasn't been run on this instance.
- **The deploy hangs at `docker:health`:** run `docker:logs`. The first start migrates and seeds 10,000 employees before it answers.
- **The address changed after a stop/start:** associate an Elastic IP and update `DEPLOY_HOST`.

# Deploying with Capistrano (EC2 + Docker Compose)

Run every command below from your machine. The instance needs **at least 20 GB of disk**; the default 8 GB fills up during the first image build. `<ip>` is the instance's public or Elastic IP, and `<key>.pem` is its key pair file.

## Once per instance

1. **Key file.** Move it out of Downloads and make it private:
   ```bash
   mkdir -p ~/.ssh && mv ~/Downloads/<key>.pem ~/.ssh/ && chmod 600 ~/.ssh/<key>.pem
   ```
2. **Security group.** Allow SSH (22) from your IP, and HTTP (80) and HTTPS (443) from anywhere.
3. **Check SSH.** This should print Ubuntu (24.04 or later) and about 1 GB of memory:
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
The first deploy builds the image on the server, which takes about 10–15 minutes on a t3.micro. Later deploys reuse cached layers. The deploy ends with `Healthy: the app answers /up`, or with the app's last log lines if it failed.

Then open `https://<domain>` once HTTPS is on (below); until then, `http://<ip>`.

## HTTPS (once per domain)

Caddy runs in front of the app and gets a Let's Encrypt certificate for `APP_HOST` automatically.
1. **DNS.** At GoDaddy, choose **DNS → Add record**: type **A**, name e.g. `salary`, value `<ip>`, TTL 600. Check it from your machine; it should print `<ip>`:
   ```bash
   dig +short salary.<yourdomain>
   ```
2. **Security group.** Add an inbound rule: HTTPS (443) from anywhere.
3. **Tell the server.** These settings stay in the server's `.env`, not in git:
   ```bash
   ssh -i ~/.ssh/<key>.pem ubuntu@<ip> "cd ~/salary-dashboard/shared && sed -i '/^APP_HOST=/d; /^FORCE_SSL=/d' .env && printf 'APP_HOST=salary.<yourdomain>\nFORCE_SSL=true\n' >> .env && grep -E '^(APP_HOST|FORCE_SSL)=' .env"
   ```
4. **Deploy:** `bundle exec cap production deploy`. Caddy requests the certificate on its first start, within a few seconds. Then:
   ```bash
   SMOKE_PASSWORD='<demo password>' ruby backend/script/smoke.rb https://salary.<yourdomain>
   ```
   Over HTTPS, the smoke test also checks the http → https redirect, HSTS and `Secure` cookies.

If the certificate doesn't arrive, run `ssh … 'cd ~/salary-dashboard/current && docker compose -f compose.production.yaml logs caddy | tail -30'`. The usual causes are DNS not pointing at `<ip>` yet, or port 80 or 443 closed. Let's Encrypt checks the domain over port 80.

## Demo email inbox (optional, demo only)

Until Gmail is set up, the demo can keep its emails in an Admin-only inbox instead of dropping them. This is extended behaviour for the demo, not for real use; production will send through SMTP (next section).
```bash
ssh -i ~/.ssh/<key>.pem ubuntu@<ip> "cd ~/salary-dashboard/shared && sed -i '/^EMAIL_INBOX=/d' .env && echo 'EMAIL_INBOX=true' >> .env && grep '^EMAIL_INBOX=' .env"
```
Deploy again. Then sign in as an Admin and choose **Email inbox (demo)** in the menu (`https://<domain>/letter_opener`). Once `SMTP_USERNAME` is set, email goes through SMTP and the inbox stays empty; set `EMAIL_INBOX=false` (or remove the line) to hide it. Each deploy empties it.

## Account emails through Gmail (once)

Invitations and reset links are sent through Gmail's SMTP server. Without these settings the app works, but sends no email; Admins can still set passwords on the Users screen.
1. In the Google account that will send the emails, turn on **2-Step Verification**. Then go to **Security → App passwords**, create one named e.g. "Salary demo", and copy the 16 characters.
2. Add the settings to the server's `.env`. Type the app password where shown, without spaces:
   ```bash
   ssh -i ~/.ssh/<key>.pem ubuntu@<ip> "cd ~/salary-dashboard/shared && sed -i '/^SMTP_USERNAME=/d; /^SMTP_PASSWORD=/d; /^MAIL_FROM=/d' .env && printf 'SMTP_USERNAME=you@gmail.com\nSMTP_PASSWORD=<app password>\nMAIL_FROM=you@gmail.com\n' >> .env && grep -c '^SMTP_' .env"
   ```
   It should print `2`.
3. Deploy again (`bundle exec cap production deploy`), so the app restarts with the settings.
4. Test it with **Forgot password?** for your own account, or by choosing yourself under **Send a password link to** on the Users screen. If nothing arrives, run `bundle exec cap production docker:logs` and look for `Failed delivery of mail`.

Links in the emails point at `https://<APP_HOST>`. Gmail allows about 500 emails a day from a personal account.

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
- **The address changed after a stop/start:** associate an Elastic IP, then update `DEPLOY_HOST` and the DNS A record.
- **Disk full (`No space left on device` while building):** the default 8 GB disk is too small. Grow the volume to 20 GB (EC2 → Volumes → Modify volume), then `sudo growpart /dev/nvme0n1 1 && sudo resize2fs /dev/nvme0n1p1 && docker builder prune -af`.

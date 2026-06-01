# Axon - Universal CI/CD Pipeline

A production-ready CI/CD template that works for any language or framework.
Supports both GitHub Actions and GitLab CI with 100% free-tier tools and zero secrets in the repository.

---

## What This Is

This repository provides a complete CI/CD foundation for web apps, APIs, microservices, and mobile projects.
Docker is the abstraction layer, so the pipeline itself never changes regardless of what language you use.
You adapt only the Dockerfile.

Key properties:
- Works on GitHub Actions and GitLab CI with equivalent pipelines
- No external paid services required
- All secrets stored per-environment in CI/CD variables, never in code
- .env is written to the server at deploy time from a base64-encoded secret
- Monitoring stack included (Prometheus, Grafana, Loki, Alertmanager)

---

## Prerequisites

- A server with Docker and Docker Compose installed (Ubuntu 22.04+ recommended)
- SSH access to the server with an ed25519 key pair (no passphrase)
- A GitHub or GitLab account

Server setup (one-time):

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-plugin curl
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy
sudo mkdir -p /srv/axon
sudo chown deploy:deploy /srv/axon
echo "<your public key>" | sudo -u deploy tee -a /home/deploy/.ssh/authorized_keys
```

Generate deploy key pair:

```bash
ssh-keygen -t ed25519 -C "ci-deploy" -f ~/.ssh/id_ed25519_deploy -N ""
# id_ed25519_deploy     -> CI secret DEPLOY_SSH_KEY
# id_ed25519_deploy.pub -> server authorized_keys
```

---

## Quick Start

```bash
# Clone and enter the repo
git clone https://github.com/suphakin-th/axon.git
cd axon

# Copy environment template
cp .env.example .env
# Edit .env with your local values

# Start local dev (hot-reload)
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Run tests
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test
```

---

## Architecture

```
feature/*  --+
fix/*      --+--> develop --MR--> uat --MR--> main
refactor/* --+              |              |
                       auto-deploy     manual gate
                         to UAT          to PROD
```

All branches except develop and feature/* are protected and require merge requests.
Direct push to uat and main is blocked.

---

## Pipeline Stages

```
[test] -> [build] -> [deploy:uat  (auto)]    uat branch
                  -> [deploy:prod (manual)]   main branch
                           |
                      [migrate (manual)]      both envs
```

### Stage 1 - test

Runs on every pull request and every push to uat and main.

```bash
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test
```

Spins up an ephemeral database container for the test run, then discards it.
The test command is defined in the Dockerfile test stage CMD and can be anything your language uses.

### Stage 2 - build

Runs only on pushes to uat and main (not on pull requests).

Builds the Docker image, tags it with both the git SHA (immutable) and branch name (cache pointer),
then pushes to the container registry.

- GitHub: ghcr.io (free for public repos, 500 MB for private)
- GitLab: GitLab Container Registry (free, unlimited)

### Stage 3 - deploy

| Job          | When       | Gate                                                  |
|--------------|------------|-------------------------------------------------------|
| deploy:uat   | uat push   | Automatic after build succeeds                        |
| deploy:prod  | main push  | Manual - reviewer approves in GitHub / click Play in GitLab |

The deploy job:
1. SSHes to the server
2. Decodes APP_ENV_B64 from the CI secret and writes it to /srv/axon/.env
3. Appends APP_VERSION and APP_IMAGE to the .env
4. Runs docker compose pull and docker compose up -d --remove-orphans
5. Polls the health endpoint for up to 2 minutes

### Stage 4 - migrate

Always manual. Never runs automatically.

| Platform | How to trigger                                       |
|----------|------------------------------------------------------|
| GitHub   | Actions tab -> migrate.yml -> Run workflow -> choose env |
| GitLab   | Click Play on migrate:uat or migrate:prod in pipeline UI |

Always check pending migrations before clicking. Review what will change before proceeding.

---

## Free-Tier Tools

| Tool                      | Free allowance                            | Purpose                        |
|---------------------------|-------------------------------------------|--------------------------------|
| GitHub Actions            | 2,000 min/month private, unlimited public | CI runner                      |
| GitLab CI                 | 400 min/month SaaS, unlimited self-hosted | CI runner                      |
| ghcr.io                   | Free public, 500 MB private               | Image registry for GitHub      |
| GitLab Container Registry | Free unlimited                            | Image registry for GitLab      |
| appleboy/ssh-action       | Free open-source                          | SSH deploy from GitHub Actions |
| Docker Compose            | Free                                      | Dev and production orchestration|

---

## Secrets Setup

### How .env Reaches the Server

Secrets are never stored in the repository. The .env is encoded as base64 and stored in CI,
then decoded on the server at deploy time.

Encode your .env file:

```bash
# macOS / Linux
base64 -w 0 .env.uat   # paste as APP_ENV_B64 in the uat environment
base64 -w 0 .env.prod  # paste as APP_ENV_B64 in the production environment

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('.env.uat'))  | clip
[Convert]::ToBase64String([IO.File]::ReadAllBytes('.env.prod')) | clip
```

### GitHub - Settings -> Environments -> [uat / production] -> Secrets

| Secret         | Description                                    |
|----------------|------------------------------------------------|
| DEPLOY_HOST    | Server IP or hostname                          |
| DEPLOY_USER    | SSH username (e.g. deploy)                     |
| DEPLOY_SSH_KEY | Private SSH key, ed25519, no passphrase        |
| APP_ENV_B64    | base64-encoded .env content for this env       |
| APP_PORT       | Port the app exposes (e.g. 3000)               |
| HEALTH_PATH    | Health check endpoint (e.g. /health)           |
| DEPLOY_PATH    | Server directory (e.g. /srv/axon)              |
| MIGRATE_CMD    | Migration command (e.g. npm run migrate)       |

GITHUB_TOKEN is auto-generated per job. No setup required.

To enable the manual gate for production:
Settings -> Environments -> production -> Required reviewers -> add yourself.

### GitLab - Settings -> CI/CD -> Variables (set Environment scope per row)

| Variable        | Scope       | Masked | Description                    |
|-----------------|-------------|--------|--------------------------------|
| DEPLOY_SSH_KEY  | All         | No     | Private SSH key (File type)    |
| DEPLOY_HOST     | uat         | No     | UAT server IP                  |
| DEPLOY_HOST     | production  | No     | PROD server IP                 |
| DEPLOY_USER     | uat/prod    | No     | SSH username per env           |
| APP_ENV_B64     | uat         | Yes    | base64 .env for UAT            |
| APP_ENV_B64     | production  | Yes    | base64 .env for PROD           |
| APP_PORT        | uat/prod    | No     | App port per env               |
| HEALTH_PATH     | uat/prod    | No     | Health check path per env      |
| DEPLOY_PATH     | uat/prod    | No     | Server path per env            |
| MIGRATE_CMD     | uat/prod    | No     | Migration command per env      |

---

## Adapting for Your Language

Edit only the Dockerfile. The pipeline does not change.

Each stage has inline comments showing how to swap the base image and commands.

| Language     | deps base image                   | Test command             | Run command                  |
|--------------|-----------------------------------|--------------------------|------------------------------|
| Node.js      | node:20-alpine                    | npm test                 | node dist/server.js          |
| Python       | python:3.12-slim                  | pytest -v                | gunicorn app:app             |
| Go           | golang:1.22-alpine                | go test ./...            | /app/server (compiled)       |
| PHP (Laravel)| php:8.4-cli-alpine                | php artisan test         | nginx + php-fpm              |
| Java (Maven) | eclipse-temurin:21                | mvn test                 | java -jar app.jar            |
| Ruby         | ruby:3.3-alpine                   | bundle exec rspec        | bundle exec puma             |
| .NET         | mcr.microsoft.com/dotnet/sdk:8.0  | dotnet test              | dotnet app.dll               |

For mobile projects (React Native, Flutter):
- test stage: flutter test or npm test (Jest)
- builder stage: flutter build apk or react-native bundle
- deploy stage: upload to Firebase App Distribution or publish to store

---

## Monitoring Stack

An optional observability stack that runs on a dedicated monitoring server.
Collects metrics, logs, and alerts from all app servers.

### Architecture

```
App Servers (UAT + PROD)              Monitoring Server
  Node Exporter :9100   ----------->  Prometheus :9090
  cAdvisor      :8080   ----------->    scrape_interval: 15s
  Redis Exporter:9121   ----------->    retention: 30 days
  Promtail      :9080   -- push -->   Loki :3100
  
  Blackbox (on monitoring) -------->  Prometheus (HTTP probes)
  probe http://UAT-HOST
  probe http://PROD-HOST
                                      Grafana :3000
                                        datasource: Prometheus
                                        datasource: Loki
                                      
                                      Alertmanager :9093
                                        email -> on-call team
```

### Services

| Service      | Image                           | Port | Purpose                    |
|--------------|---------------------------------|------|----------------------------|
| Prometheus   | prom/prometheus:v2.53.0         | 9090 | Metrics collection/storage |
| Grafana      | grafana/grafana:12.0.0          | 3000 | Dashboards and visualization|
| Loki         | grafana/loki:3.5.0              | 3100 | Log aggregation            |
| Alertmanager | prom/alertmanager:v0.27.0       | 9093 | Alert routing and silencing|
| Blackbox     | prom/blackbox-exporter:v0.25.0  | 9115 | HTTP/TCP endpoint probing  |

### Agents on App Servers

Installed via monitoring/install-agents.sh on each app server.

| Agent          | Version | Port | Collects                         |
|----------------|---------|------|----------------------------------|
| Node Exporter  | v1.8.1  | 9100 | CPU, memory, disk, network       |
| cAdvisor       | v0.49.1 | 8080 | Docker container resource usage  |
| Promtail       | v3.5.0  | 9080 | Container logs, pushed to Loki   |
| Redis Exporter | v1.62.0 | 9121 | Redis memory, commands, latency  |

Install agents:

```bash
# UAT server
scp monitoring/install-agents.sh deploy@UAT_HOST:~/
ssh deploy@UAT_HOST "SERVER_ENV=uat bash ~/install-agents.sh"

# PROD server
scp monitoring/install-agents.sh deploy@PROD_HOST:~/
ssh deploy@PROD_HOST "SERVER_ENV=prod bash ~/install-agents.sh"
```

### Alert Rules

| Alert           | Condition                         | Severity | Fires after |
|-----------------|-----------------------------------|----------|-------------|
| InstanceDown    | Node Exporter unreachable         | critical | 2 min       |
| HTTPDown        | HTTP probe fails                  | critical | 2 min       |
| HTTPSlowResponse| HTTP response > 5s                | warning  | 5 min       |
| HighCPU         | CPU usage > 85%                   | warning  | 5 min       |
| HighMemory      | Memory usage > 90%                | warning  | 5 min       |
| HighDisk        | Disk usage > 85% on /             | warning  | 5 min       |
| ContainerDown   | App container missing from cAdvisor| critical | 2 min      |
| HighRedisMemory | Redis memory > 85% of maxmemory   | warning  | 5 min       |
| RedisDown       | Redis Exporter unreachable        | critical | 2 min       |

Critical alerts repeat every 1 hour. Warning alerts repeat every 4 hours.
Critical alert inhibits warning alert from the same instance.

### Deploy Monitoring Config

The CI pipeline deploys monitoring changes automatically when files under monitoring/ change on uat or main.

To deploy manually:

```bash
# Full redeploy
scp -r monitoring/ deploy@MONITORING_HOST:~/monitoring/
ssh deploy@MONITORING_HOST "cd ~/monitoring && docker compose up -d --remove-orphans"

# Reload Prometheus config only (no restart)
scp monitoring/prometheus/prometheus.yml deploy@MONITORING_HOST:~/monitoring/prometheus/prometheus.yml
ssh deploy@MONITORING_HOST "curl -s -X POST http://localhost:9090/-/reload"

# Restart Alertmanager after rule changes
scp monitoring/prometheus/rules/alerts.yml deploy@MONITORING_HOST:~/monitoring/prometheus/rules/alerts.yml
ssh deploy@MONITORING_HOST "cd ~/monitoring && docker compose restart prometheus"
```

### Known Limitation - Per-Container Metrics

Docker 29.x uses the containerd snapshotter by default. cAdvisor cannot resolve per-container
CPU/memory layers when this is enabled. The dashboard shows Docker daemon aggregate metrics instead.

Permanent fix (requires a brief Docker restart):

```bash
sudo tee -a /etc/docker/daemon.json <<'EOF'
{"features": {"containerd-snapshotter": false}}
EOF
sudo systemctl restart docker
```

---

## File Reference

| File                           | Purpose                                           |
|--------------------------------|---------------------------------------------------|
| .github/workflows/ci.yml       | GitHub Actions: test -> build -> deploy           |
| .github/workflows/migrate.yml  | GitHub Actions: manual migration workflow         |
| .gitlab-ci.yml                 | GitLab CI: equivalent pipeline                    |
| Dockerfile                     | Multi-stage universal build template              |
| docker-compose.yml             | Production stack (image-only)                     |
| docker-compose.dev.yml         | Local dev with hot-reload and local DB            |
| docker-compose.test.yml        | CI test environment with ephemeral DB             |
| .env.example                   | Environment variable template                     |
| .gitignore                     | Blocks .env* and CI tool artifacts                |

---

## Rollback

### App rollback (no migration involved)

Find the previous image SHA from the pipeline history, then on the server:

```bash
ssh deploy@SERVER
cd /srv/axon
# Edit .env: set APP_VERSION to the previous commit SHA
docker compose pull
docker compose up -d --remove-orphans
```

Or re-run the previous pipeline's deploy job from the CI UI.

### Rollback a migration

Migrations do not auto-rollback. Options:

Option A - Restore from backup (if taken before migrate):
```bash
pg_restore -U postgres -h DB_HOST -d DATABASE -c /tmp/backup_TIMESTAMP.dump
```

Option B - Write a compensating migration:
```bash
# Create a new migration that reverses the change, then deploy and run migrate
```

Option C - Roll back one step if down() is implemented:
```bash
ssh deploy@SERVER
cd /srv/axon
docker compose run --rm --no-deps app sh -c "your-framework rollback --step=1"
```

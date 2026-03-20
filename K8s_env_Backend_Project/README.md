# Multi-Container Python/Node App (The DB Connection)

## Goal
Connect two containers using a custom bridge network.

## The Project
A simple Flask (Python) or Express (Node) app that counts how many people visit a website.

## Architecture
Container 1 (App) talks to Container 2 (Redis or MongoDB).

## Skills Applied
- `docker network create`
- Docker Naming/DNS (connecting by name, not IP)
- Environment Variables

---

## Workaround

### Start Script

```bash
set -x

# 1. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 2. Define your target user
TARGET_USER="<username>"

# 3. Wait for the user to be created by the lab system
# This checks every 5 seconds until the user exists in /etc/passwd
echo "Waiting for $TARGET_USER to be created..."
while ! id "$TARGET_USER" >/dev/null 2>&1; do
  sleep 5
done

# 4. Now that the user exists, grant the permissions
usermod -aG docker "$TARGET_USER"
systemctl enable --now docker
echo "Configuration complete for $TARGET_USER"
```

### Clone Repository

```bash
git clone https://github.com/TonyStark0542/PersonalProjects.git
```

**Credentials:**
- Username: `<your-username>`
- Password: `<your-github-token>`

---

## Manual Docker Commands

### Start MongoDB Container

```bash
docker run -d --name my-mongodb mongo:latest
```

### Build Flask Application

```bash
cd PersonalProjects/Backend_Project
docker build -t flask-img .
```

### Run Flask Container

```bash
docker run -d -p 5000:5000 --name my-flask-app flask-img
```

**NOTE:** VM should allow port 5000

### Transfer File into Container

```bash
cd ~/PersonalProjects
docker cp db_backup.archive my-mongodb:/db_backup.archive
```

### Run Restore inside Container

```bash
docker exec -it my-mongodb mongorestore --archive=/db_backup.archive --gzip
```

### Verify the Data

```bash
docker exec -it my-mongodb mongosh --eval "show dbs"
```

---

## Using Docker Compose (Alternative Method)

### Fire up the infrastructure

```bash
docker compose up -d
```

### Restore your data

```bash
docker exec -it my-mongodb mongorestore --archive=/db_backup.archive --gzip
```

### Verify

```bash
docker exec -it my-mongodb mongosh --eval "show dbs"
```

### Allow Port 5000 on your VM

```bash
gcloud compute firewall-rules create allow-flask \
    --allow tcp:5000 \
    --target-tags=http-server \
    --description="Allow port 5000 for Flask app"
```

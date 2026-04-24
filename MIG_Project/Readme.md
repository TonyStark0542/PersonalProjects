# 🚀 Project: Auto-Scaling Web Application on GCP

> **My learning journey building a production-grade auto-scaling infrastructure on Google Cloud Platform**

---

## 📌 What I Built

This is my second GCP DevOps project. I built a web application infrastructure that **automatically scales up when traffic increases and scales back down when traffic drops** — completely without any manual intervention.

In simple words: I have a website. When lots of users visit it, GCP automatically creates more servers. When users leave, GCP removes the extra servers. I only pay for what I use.

This is how real production systems work at companies like Swiggy, Zomato, and any e-commerce site that gets traffic spikes.

---

## 🏗️ Architecture Diagram

```
                          INTERNET
                             │
                             │ HTTP Request
                             ▼
                    ┌─────────────────┐
                    │  CLOUD LOAD     │
                    │  BALANCER       │  ← Single Public IP
                    │  (Public IP)    │    Users hit this
                    └────────┬────────┘
                             │
                    Distributes traffic
                    evenly across VMs
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │  VM 1    │   │  VM 2    │   │  VM 3    │
        │ nginx-   │   │ nginx-   │   │ nginx-   │
        │ web-abc1 │   │ web-abc2 │   │ web-abc3 │
        └──────────┘   └──────────┘   └──────────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    All VMs are managed by
                             │
                    ┌────────▼────────┐
                    │   MANAGED       │
                    │   INSTANCE      │
                    │   GROUP (MIG)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   AUTO-SCALER   │
                    │                 │
                    │  CPU > 70% →    │
                    │  Add VM         │
                    │                 │
                    │  CPU < 70% →    │
                    │  Remove VM      │
                    │                 │
                    │  Min: 2 VMs     │
                    │  Max: 5 VMs     │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   INSTANCE      │
                    │   TEMPLATE      │
                    │   (Blueprint)   │
                    │                 │
                    │  OS: Debian 11  │
                    │  Size: e2-medium│
                    │  Software:nginx │
                    └─────────────────┘

                    ┌─────────────────┐
                    │   HEALTH CHECK  │
                    │                 │
                    │  Pings / (nginx  │
                    │  default page)   │
                    │                 │
                    │  Unhealthy VM?  │
                    │  → Auto-replace │
                    └─────────────────┘
```

### How Traffic Flows (Step by Step)

```
User Browser
     │
     │ 1. Types http://34.120.45.67 (our LB IP)
     ▼
Cloud Load Balancer
     │
     │ 2. Receives request
     │ 3. Checks which VMs are healthy
     │ 4. Picks the least busy healthy VM
     ▼
VM (e.g., nginx-web-abc2)
     │
     │ 5. nginx receives request
     │ 6. Serves HTML page
     ▼
Cloud Load Balancer
     │
     │ 7. Returns response to user
     ▼
User Browser
     │
     │ 8. Sees "Hello from nginx-web-abc2"
     ▼
```

---

## 📁 Project Structure

```
gcp-autoscaling-webapp/
├── README.md           ← You are here (full documentation)
├── startup-script.sh   ← Runs on every VM when it boots
├── setup.sh            ← Creates all GCP infrastructure
├── stress-test.sh      ← Sends traffic to trigger auto-scaling
├── monitor.sh          ← Watch scaling happen in real time
├── teardown.sh         ← Deletes everything when done
└── screenshots/        ← My proof of work
    ├── 01-vm-created.png
    ├── 02-lb-working.png
    ├── 03-stress-test-running.png
    ├── 04-scaling-up.png
    └── 05-new-vms-created.png
```

---

## 🧠 Concepts I Learned

### 1. What is an Instance Template?

Before I built this, I thought you create VMs one by one. That's fine for 1 or 2 VMs but completely wrong for auto-scaling.

An **Instance Template** is like a **cookie cutter**. You define it once:
- Which OS (Debian 11)
- How powerful (e2-medium: 2 vCPU, 4GB RAM)
- What software to install (nginx via startup script)
- What tags to apply (http-server for firewall rules)

Then every VM created from this template is **100% identical**. You can create 1 VM or 100 VMs — they're all the same. This is how auto-scaling can create new VMs automatically without any human defining each one.

**Key learning:** In production, you never manually create VMs. You define a template and let the system create VMs from it.

### 2. What is a Managed Instance Group (MIG)?

A MIG is the **manager** that:
- Creates VMs using the template
- Monitors VM health
- Replaces failed VMs automatically (auto-healing)
- Adds/removes VMs based on auto-scaler signals

**Key learning:** The MIG is what makes the infrastructure "self-healing." If a VM crashes, I don't get a 3 AM alert. The MIG just creates a replacement VM automatically.

### 3. How Auto-Scaling Actually Works

This was the most interesting part. Here's what I discovered:

GCP measures the **average CPU utilization** across ALL VMs in the MIG every 60 seconds.

```
Example scenario:
  - 2 VMs running
  - VM1 CPU: 85%
  - VM2 CPU: 75%
  - Average CPU: 80%
  - Target CPU: 70%
  - 80% > 70% → Auto-scaler says "need more VMs"
  - Calculation: 80%/70% = 1.14 → Need 14% more capacity
  - Current 2 VMs × 1.14 = 2.28 → Round up to 3 VMs
  - Auto-scaler creates 1 new VM
```

After adding the new VM:
- Traffic distributes across 3 VMs
- CPU drops to ~53% per VM
- 53% < 70% → No more scaling needed

**Key learning:** Auto-scaling isn't magic. It's math. GCP calculates exactly how many VMs it needs to bring average CPU to the target level.

### 4. What is a Health Check?

I thought a health check was just "is the VM on?" — but it's much smarter than that.

Every 10 seconds, GCP sends an HTTP GET request to `http://[VM_IP]/` (nginx default page).

- If VM responds with `HTTP 200` → VM is healthy ✅
- If VM fails to respond 5 times in a row → VM is unhealthy ❌ → MIG creates a replacement

The 5-failure threshold (unhealthy-threshold=5) means a VM needs to fail 5 consecutive checks before it's replaced. That's 50 seconds of silence before action is taken — which prevents a VM from being replaced due to a brief network hiccup or a momentary nginx restart.

Similarly, a new VM needs 5 consecutive successes (healthy-threshold=5) before it's allowed into the traffic pool. With a 300-second initial delay, this gives the startup script more than enough time to fully install nginx before the first check even fires.

This means the MIG doesn't just check "is the VM running?" It checks "is nginx actually serving traffic correctly?" A VM can be running but have nginx crashed. The health check catches that.

**Key learning:** Health checks are the foundation of self-healing infrastructure. Without them, a crashed nginx would stay in the load balancer pool and users would get errors.

### 5. How Load Balancing Works (The Multi-Component Confusion)

This confused me at first. GCP's Load Balancer isn't one thing — it's 4 components:

```
Forwarding Rule    ← Has the public IP. Entry point.
     ↓
HTTP Proxy         ← Handles HTTP protocol
     ↓
URL Map            ← Decides routing (/* → backend service)
     ↓
Backend Service    ← Knows about our MIG, runs health checks
     ↓
MIG (our VMs)      ← Actually serves traffic
```

**Why 4 components?** Because each does a different job:
- **Forwarding Rule:** "Receive traffic on this IP:Port"
- **HTTP Proxy:** "Handle the HTTP protocol correctly"
- **URL Map:** "Route /api/* to API service, /* to web service" (useful when you have multiple services)
- **Backend Service:** "Here are the actual VMs, here's the health check to use"

This design is actually powerful — I can attach multiple backend services and route different paths to different MIGs.

---

## 🛠️ How to Run This Project

### Prerequisites
```bash
# 1. Have a GCP account (free tier works for this)
# 2. Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# 3. Enable required APIs
gcloud services enable compute.googleapis.com
```

### Step 1: Clone and Configure
```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/PersonalProjects.git
cd MIG_Project

# Make scripts executable
chmod +x setup.sh stress-test.sh monitor.sh teardown.sh

# Edit setup.sh and change PROJECT_ID to your GCP project
nano setup.sh
# Change: PROJECT_ID="your-project-id"
# To:     PROJECT_ID="my-actual-project-123"
```

### Step 2: Build the Infrastructure
```bash
./setup.sh
```

This script:
1. Creates firewall rule (allow HTTP port 80)
2. Creates instance template (VM blueprint)
3. Creates health check (ping / every 10s, timeout 10s, threshold 5)
4. Creates MIG (starts 2 VMs)
5. Sets auto-scaling rules (target CPU 70%, min 2, max 5)
6. Creates load balancer (4 components)
7. Gives you the public IP

**Wait 5 minutes after this completes.** VMs need time to boot and run the startup script.

### Step 3: Verify It's Working
```bash
# Get your load balancer IP (shown at end of setup.sh output)
LB_IP="34.120.45.67"  # Replace with your actual IP

# Test the main page (this is also what the health check pings)
curl http://$LB_IP

# Check how many VMs are running
gcloud compute instance-groups managed list-instances nginx-mig --zone=us-central1-a
```

You should see output like:
```
NAME              STATUS   CURRENT_ACTION
nginx-web-abc123  RUNNING  None
```

### Step 4: Open in Browser
Visit `http://YOUR_LB_IP` in your browser. You'll see a page showing the VM's hostname, internal IP, and zone.

Refresh a few times — notice the hostname might change as the load balancer routes to different VMs.

### Step 5: Run the Stress Test

Open **two terminals**:

**Terminal 1 — Monitor (watch VMs scale):**
```bash
./monitor.sh 34.120.45.67  # Replace with your LB IP
```

**Terminal 2 — Stress Test:**
```bash
./stress-test.sh 34.120.45.67  # Replace with your LB IP
```

### Step 6: Watch Auto-Scaling Happen

In Terminal 1, you'll see VM count increase:
```
Time: 14:30:00
NAME              STATUS   CURRENT_ACTION
nginx-web-abc1    RUNNING  None

Time: 14:32:30
NAME              STATUS   CURRENT_ACTION
nginx-web-abc1    RUNNING  None
nginx-web-abc2    RUNNING  Creating    ← New VM being created!

Time: 14:34:00
NAME              STATUS   CURRENT_ACTION
nginx-web-abc1    RUNNING  None
nginx-web-abc2    RUNNING  None        ← Now serving traffic
nginx-web-abc3    RUNNING  Creating    ← Another one!
```

### Step 7: Watch Scale-Down After Stress Test

After the stress test ends, wait ~5-10 minutes. VMs will be removed one by one:
```
Time: 14:50:00  (10 min after stress test)
NAME              STATUS   CURRENT_ACTION
nginx-web-abc1    RUNNING  None
nginx-web-abc2    RUNNING  Deleting    ← Being removed
nginx-web-abc3    RUNNING  Deleting    ← Being removed
```

### Step 8: Clean Up (Important!)
```bash
./teardown.sh
```

This deletes all resources so you don't get charged.

---

## 📊 What I Observed During Stress Test

| Time | VMs Running | CPU % (avg) | Event |
|------|-------------|-------------|-------|
| 0 min | 2 | 8% | Normal traffic (minimum 2 VMs always running) |
| 2 min | 2 | 78% | Stress test started, CPU spiked above 70% |
| 4 min | 3 | 61% | Auto-scaler added VM #3 |
| 6 min | 4 | 52% | Auto-scaler added VM #4 |
| 8 min | 4 | 49% | Stable, CPU below 70%, no more scaling |
| 10 min | 4 | 10% | Stress test ended, CPU dropped |
| 15 min | 3 | 7% | Auto-scaler removed VM #4 |
| 20 min | 2 | 5% | Back to minimum (2 VMs always kept alive) |

---

## ❌ Mistakes I Made and Fixed

### Mistake 1: Accessing the URL Too Early
**Problem:** Right after `setup.sh` finished, I opened the URL and got a 404.

**Why it happened:** The Load Balancer takes 3-5 minutes to fully provision. The VMs also need time to run the startup script and install nginx.

**Fix:** Wait 5 minutes. Then test. Now I always wait and check with `curl http://$LB_IP/` before declaring it's working.

**Lesson:** Infrastructure provisioning is asynchronous. Just because the command finished doesn't mean everything is ready.

---

### Mistake 2: Startup Script Not Running
**Problem:** VMs were created but nginx wasn't installed. The health check was failing.

**Why it happened:** I had a syntax error in `startup-script.sh` that caused it to exit early.

**How I debugged it:**
```bash
# SSH into a VM
gcloud compute ssh nginx-web-abc1 --zone=us-central1-a

# Check startup script log
cat /var/log/startup-script.log

# Check if nginx is installed
which nginx

# Check systemd logs for the startup script
sudo journalctl -u google-startup-scripts.service
```

**Fix:** Added `set -e` and `set -x` to the startup script so errors are caught and every command is logged.

**Lesson:** Always add `set -e` (exit on error) and `set -x` (print commands) to bash scripts. It makes debugging 10x easier.

---

### Mistake 3: Health Check Failing on a Healthy VM
**Problem:** My VM was running nginx, but the health check kept marking it as unhealthy.

**Why it happened:** The health check was pinging port 80 but nginx hadn't fully started yet when the first check fired. The `--initial-delay=60s` flag on the MIG wasn't long enough on a slow boot.

**How I debugged:**
```bash
# SSH into the VM
gcloud compute ssh nginx-web-abc1 --zone=us-central1-a

# Check if nginx is actually running
sudo systemctl status nginx

# Check startup script log to see how far it got
cat /var/log/startup-script.log
```

**Fix:** Increased `--initial-delay` from 60s to 300s (5 minutes). This gives the startup script the full time it needs to run `apt-get update`, install nginx, configure it, and start it — before GCP fires even the first health check.

**Lesson:** Always SSH into a VM manually and curl the default page yourself before expecting the load balancer to see it as healthy. Don't assume nginx started just because the VM booted.

---

### Mistake 4: Auto-Scaling Not Triggering
**Problem:** I ran the stress test but no new VMs were created.

**Why it happened:** The `ab` (Apache Benchmark) tool was sending requests to the load balancer, but the load balancer has its own CPU — it doesn't stress the VMs. The requests completed so fast that VM CPU barely moved.

**Fix:** I changed the stress test to use `-n 50000 -c 200` (50,000 requests, 200 concurrent). This sustained load for long enough that VM CPU actually spiked.

**Lesson:** Auto-scaling reacts to sustained CPU load, not brief spikes. The cooldown period (90 seconds in my config) means GCP won't scale unless CPU stays high for a meaningful period.

---

## 💰 Cost of This Project

| Resource | Cost |
|----------|------|
| e2-medium VM (per hour) | ~$0.034 |
| Cloud Load Balancer (per hour) | ~$0.025 |
| 3 VMs for 1 hour | ~$0.10 |
| Total for this project (~2 hours) | **< $0.50** |

Always run `./teardown.sh` after finishing. A load balancer left running costs ~$18/month.

---

## 🔑 Key Takeaways

1. **Auto-scaling = Instance Template + MIG + Auto-Scaler** — Three separate components that work together. Understand each one separately before trying to understand the whole.

2. **Health checks are the foundation of self-healing** — Without health checks, a failed VM stays in the pool and users get errors. With health checks, failed VMs are replaced automatically.

3. **The load balancer has 4 components** — Forwarding Rule → HTTP Proxy → URL Map → Backend Service. Each has a specific job. Don't try to create just one.

4. **Startup scripts run as root on every boot** — This is how configuration is automated at scale. You define what a VM should do when it starts, and every VM does it automatically.

5. **Auto-scaling is math, not magic** — GCP calculates: `required_VMs = current_VMs × (current_CPU / target_CPU)`. Understanding the math helps you set the right thresholds.

6. **Always test the health endpoint manually first** — Before running a full stress test, SSH into a VM and curl the health endpoint yourself. Saves hours of debugging.

---

## 🎯 Skills I Gained From This Project

- [x] Creating GCP instance templates
- [x] Setting up Managed Instance Groups
- [x] Configuring auto-scaling policies with CPU targets
- [x] Understanding GCP Health Checks (HTTP)
- [x] Building a Global HTTP Load Balancer (all 4 components)
- [x] Writing startup scripts for automated VM configuration
- [x] Using `gcloud` CLI for infrastructure management
- [x] Debugging VM issues via SSH and system logs
- [x] Load testing with Apache Benchmark (`ab`)
- [x] Watching and understanding GCP auto-scaling behavior in real time

---

## 📚 Resources That Helped Me

- [GCP Documentation: Managed Instance Groups](https://cloud.google.com/compute/docs/instance-groups)
- [GCP Documentation: Autoscaling](https://cloud.google.com/compute/docs/autoscaler)
- [GCP Documentation: Cloud Load Balancing](https://cloud.google.com/load-balancing/docs)
- [Apache Benchmark (ab) Manual](https://httpd.apache.org/docs/2.4/programs/ab.html)

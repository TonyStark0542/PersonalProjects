# 🐍 Container Python App — The DB Connection
## Version 2: Deployed on Kubernetes (GKE)

This guide walks you through deploying a Python Flask app connected to MongoDB on Google Kubernetes Engine (GKE). Every step is explained in plain English so you know **what** you're doing and **why**.

---

## 📋 Prerequisites

- Google Cloud SDK (`gcloud`) installed and authenticated
- `kubectl` installed
- You have cloned this repository

```bash
git clone <your-repo-url>
cd <your-repo-folder>
```

---

## 🗺️ What We're Building

```
Internet
    ↓
Flask App (3 Pods)          ← handles HTTP requests
    ↓
MongoDB (1 Pod)             ← stores all your data
    ↓
Persistent Volume (PVC)     ← so data survives Pod restarts
```

---

## 🚀 Deployment Steps

### Step 1 — Create the Kubernetes Cluster on GKE

```bash
gcloud container clusters create python-app-cluster \
  --zone=us-central1-a \
  --num-nodes=3 \
  --machine-type=e2-medium
```

**What this does:**
This spins up a real Kubernetes cluster on Google Cloud with **3 worker nodes**. Think of nodes as the physical machines that will run your Pods. `e2-medium` is the machine type — 2 vCPUs, 4GB RAM per node. This takes 3-5 minutes to complete.

---

### Step 2 — Create the Persistent Volume Claim for MongoDB

```bash
kubectl apply -f mongo-pvc.yaml
```

> ⏳ **Wait 10-15 seconds** before moving to Step 3.

**What this does:**
MongoDB needs to store data somewhere permanent. By default, everything inside a container is wiped when the Pod restarts. This PVC (Persistent Volume Claim) reserves a chunk of disk storage from Google Cloud that will **survive Pod restarts, crashes, and redeploys**. Your data stays safe no matter what happens to the Pod.

---

### Step 3 — Deploy MongoDB

```bash
kubectl apply -f mongo-deployment.yaml
```

**What this does:**
This creates the MongoDB Pod using the PVC from Step 2 as its storage. MongoDB's data directory (`/data/db`) is mounted to the persistent disk, so nothing gets lost if the Pod goes down.

---

### Step 4 — Verify the PVC is Attached to MongoDB

```bash
kubectl describe pvc mongo-pvc
```

**What this does:**
This checks that the persistent storage is properly connected to the MongoDB container. You want to see `Status: Bound` in the output — that means the storage is successfully attached. If it shows `Pending`, wait a few more seconds and try again.

**Expected output (look for this line):**
```
Status:    Bound
```

---

### Step 5 — Deploy the Flask App

```bash
kubectl apply -f flask-deployment.yaml
```

**What this does:**
This deploys your Python Flask web app. It creates multiple Pods (as defined in `flask-deployment.yaml`) that connect to the MongoDB service internally. Kubernetes handles the networking between Flask and MongoDB automatically.

---

### Step 6 — Check Pod Status

```bash
kubectl get pods
```

**What this does:**
Lists all running Pods and their current status. You want all Pods showing `Running` before proceeding.

**What you'll see:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
mongodb-deployment-6bc85c5bf9-qggs7    1/1     Running   0          2m
flask-deployment-abc123-xyz            1/1     Running   0          1m
flask-deployment-abc123-def            1/1     Running   0          1m
```

**If status is NOT `Running`** (e.g., `ContainerCreating`, `CrashLoopBackOff`, `Error`), dig into the details:

```bash
kubectl describe pod <pod_name>
```

Replace `<pod_name>` with the actual name from `kubectl get pods`. Scroll to the **Events** section at the bottom — it tells you exactly what went wrong.

> ✅ Only move to Step 7 once all Pods show `Running` status.

---

### Step 7 — Restore the MongoDB Database Backup

This is a two-part step. First copy the backup file into the MongoDB Pod, then restore it.

**Part A — Copy the backup file into the MongoDB Pod:**

```bash
kubectl cp db_backup.archive mongodb-deployment-6bc85c5bf9-qggs7:/db_backup.archive
```

> ⚠️ Replace `mongodb-deployment-6bc85c5bf9-qggs7` with your actual MongoDB Pod name from `kubectl get pods`.

**What this does:**
`kubectl cp` works like the regular `cp` command but copies files **into a running Pod**. This puts your `db_backup.archive` file inside the MongoDB container's filesystem at the root path `/db_backup.archive`.

**Part B — Restore the database from the backup:**

```bash
kubectl exec -it mongodb-deployment-6bc85c5bf9-qggs7 -- mongorestore --archive=/db_backup.archive --gzip
```

> ⚠️ Again, replace the Pod name with your actual MongoDB Pod name.

**What this does:**
`kubectl exec -it` opens a connection inside the running Pod and runs a command — in this case `mongorestore`. This reads the backup archive and loads all the data back into MongoDB. The `--gzip` flag tells it the archive is compressed.

---

## 🔍 Useful Debugging Commands

```bash
# See all pods and their status
kubectl get pods

# See detailed info + events for a specific pod
kubectl describe pod <pod_name>

# See live logs from a pod
kubectl logs <pod_name>

# See logs from a crashed/previous pod instance
kubectl logs <pod_name> --previous

# Check PVC storage status
kubectl get pvc

# Check all running services
kubectl get services
```

---

## 🧠 Quick Concept Reference

| Term | What it means in plain English |
|---|---|
| **Pod** | The smallest unit in Kubernetes — wraps your container |
| **Deployment** | Manages Pods, keeps them running, handles restarts |
| **PVC** | A request for persistent storage — survives Pod restarts |
| **Service** | A stable network address to reach your Pods |
| **Node** | The actual machine (VM) that runs your Pods |
| `kubectl apply` | Create or update a resource from a yaml file |
| `kubectl cp` | Copy files into or out of a running Pod |
| `kubectl exec` | Run a command inside a running Pod |

---

## ⚠️ Common Issues

| Problem | Fix |
|---|---|
| Pod stuck in `ContainerCreating` | Run `kubectl describe pod <name>` and check Events |
| Pod in `CrashLoopBackOff` | Run `kubectl logs <name> --previous` to see crash logs |
| PVC stuck in `Pending` | Wait 15-20 seconds, GCP disk provisioning takes time |
| `mongorestore` fails | Make sure the backup file path inside the Pod is correct |
| Wrong Pod name in Step 7 | Run `kubectl get pods` first and copy the exact name |

---

## 📁 File Structure

```
.
├── README.md                  # This file
├── mongo-pvc.yaml             # Persistent storage claim for MongoDB
├── mongo-deployment.yaml      # MongoDB Pod + Service definition
├── flask-deployment.yaml      # Flask App Pods + Service definition
└── db_backup.archive          # MongoDB database backup (compressed)
```

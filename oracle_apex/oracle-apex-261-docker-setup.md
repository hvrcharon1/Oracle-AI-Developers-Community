# Oracle APEX 26.1 on Docker with Oracle AI Database 26ai (Free Edition)
### A Complete Step-by-Step Guide for Windows 11

> **Author:** Harshal Vijay Rasal  
> **Date:** May 2026  
> **Environment:** Windows 11 + Docker Desktop  
> **Result:** Oracle APEX 26.1 fully accessible via browser at `http://localhost:8081/ords/apex`

---

## 📋 Table of Contents

1. [Overview & Architecture](#overview--architecture)
2. [Prerequisites](#prerequisites)
3. [Why This Approach?](#why-this-approach)
4. [Folder Structure Setup](#folder-structure-setup)
5. [Download APEX 26.1](#download-apex-261)
6. [The docker-compose.yml (Final Working Version)](#the-docker-composeyml-final-working-version)
7. [Common Errors & Fixes](#common-errors--fixes)
8. [Running the Stack](#running-the-stack)
9. [Setting the APEX Admin Password](#setting-the-apex-admin-password)
10. [Accessing APEX in Your Browser](#accessing-apex-in-your-browser)
11. [APEXlang — No Extra Install Needed](#apexlang--no-extra-install-needed)
12. [Configuring AI Providers in APEX 26.1](#configuring-ai-providers-in-apex-261)
13. [Managing Your Docker Stack](#managing-your-docker-stack)
14. [Troubleshooting Reference](#troubleshooting-reference)
15. [Quick Reference Card](#quick-reference-card)

---

## Overview & Architecture

This guide walks you through installing **Oracle APEX 26.1** inside a Docker container running **Oracle AI Database 26ai Free (23.26.x)**, with **ORDS 26.1.1** serving APEX through your local browser — all on **Windows 11**.

```
Your Windows 11 Machine
│
├── Docker Desktop
│   ├── Container: oracle-apex-docker-db-1
│   │   └── Oracle AI Database 26ai Free (23.26.0.0)
│   │       └── FREEPDB1 (Pluggable Database)
│   │           └── APEX 26.1 installed here
│   │
│   └── Container: oracle-apex-docker-ords-1
│       └── ORDS 26.1.1 (web layer)
│           └── Serves APEX to your browser
│
└── Your Browser → http://localhost:8081/ords/apex ✅
```

**Your existing local Oracle databases (e.g. 23ai 23.9) are completely untouched.**

---

## Prerequisites

| Requirement | Details |
|---|---|
| OS | Windows 11 |
| Docker Desktop | Installed and running |
| Oracle Account | Free account at oracle.com (for container registry login) |
| APEX 26.1 zip | Downloaded from oracle.com/tools/downloads/apex-downloads |
| Disk Space | ~10 GB free minimum |
| RAM | 8 GB+ recommended |

---

## Why This Approach?

- ✅ **Zero risk** to any existing local Oracle databases
- ✅ **No local Oracle installation** required for 26ai
- ✅ Everything runs in **isolated Docker containers**
- ✅ Easy to stop, start, or tear down
- ✅ **APEXlang, AI Interactive Reports, AI Agents** — all included automatically in APEX 26.1

---

## Folder Structure Setup

Create the following folder structure on your Windows machine:

```
C:\oracle-apex-docker\
├── docker-compose.yml
├── apex\              ← APEX 26.1 files go here
├── oracle_oradata\    ← DB data files (auto-populated)
└── ords_config\       ← ORDS config (auto-populated)
```

Open **Command Prompt as Administrator** and run:

```cmd
mkdir C:\oracle-apex-docker
cd C:\oracle-apex-docker
mkdir apex
mkdir oracle_oradata
mkdir ords_config
```

---

## Download APEX 26.1

1. Go to: https://www.oracle.com/tools/downloads/apex-downloads/
2. Download `apex_26.1_en.zip` (English only, ~670MB) or `apex_26.1.zip` (all languages)
3. Extract the zip
4. Copy **the contents of the `apex` subfolder** (not the folder itself) into `C:\oracle-apex-docker\apex\`

Your `C:\oracle-apex-docker\apex\` should contain:
```
apexins.sql
apxrtins.sql
images\
builder\
core\
utilities\
... (53 items total)
```

> ⚠️ Make sure you copy the **contents** of the apex folder, not the folder itself.

---

## The docker-compose.yml (Final Working Version)

This is the **battle-tested, final working version** after resolving all issues encountered during setup.

Create `C:\oracle-apex-docker\docker-compose.yml` with this exact content:

```yaml
services:

  db:
    image: container-registry.oracle.com/database/free:23.26.0.0
    hostname: database
    shm_size: '1gb'
    ports:
      - "1522:1521"
    environment:
      - ORACLE_PWD=YourPassword123x
    volumes:
      - ./oracle_oradata/:/opt/oracle/oradata
    healthcheck:
      test: ["CMD", "sqlplus", "-L", "sys/YourPassword123x@//localhost:1521/FREEPDB1", "as", "sysdba"]
      interval: 60s
      timeout: 30s
      retries: 40
      start_period: 300s

  ords:
    image: container-registry.oracle.com/database/ords:latest
    ports:
      - "8081:8080"
    environment:
      - DBHOST=database
      - DBPORT=1521
      - DBSERVICENAME=FREEPDB1
      - ORACLE_PWD=YourPassword123x
      - APEX_PWD=YourPassword123x
    volumes:
      - ./ords_config/:/etc/ords/config
      - ./apex/:/opt/oracle/apex
    depends_on:
      db:
        condition: service_healthy
    restart: on-failure
```

> Replace `YourPassword123x` with your own password. **Critical password rules** — see next section.

---

## Common Errors & Fixes

### ❌ Error 1: "The password you entered contains invalid characters"

**Cause:** Special characters like `!`, `#`, `@`, `$` are not allowed in Docker environment variables.

**Fix:** Use a password with **only letters and numbers** (mixed case):
```
✅ Good:  Myoracle92x
✅ Good:  MyOracle2026
❌ Bad:   Myoracle92!
❌ Bad:   Welcome123#
```

---

### ❌ Error 2: "container oracle-apex-docker-db-1 is unhealthy"

**Cause:** Default healthcheck fires too early — the DB needs more time to initialize on first run.

**Fix:** Use these healthcheck settings (already included in the yml above):
```yaml
healthcheck:
  interval: 60s       # check every 60 seconds (not 30)
  timeout: 30s        # allow 30s for response
  retries: 40         # try 40 times
  start_period: 300s  # wait 5 minutes before first check
```

Also add `shm_size: '1gb'` to the db service to prevent shared memory errors.

---

### ❌ Error 3: "ORA-12514: Cannot connect to database. Service FREEPDB1 is not registered with the listener"

**Cause:** ORDS started before the DB's PDB was fully registered with the listener.

**Fix:** Add `restart: on-failure` to the ords service. This causes ORDS to automatically retry if it hits this timing issue:
```yaml
ords:
  ...
  restart: on-failure
```

---

### ❌ Error 4: "Password cannot be null" (looping)

**Cause:** Previous run used a password with invalid characters, and the container got into a loop.

**Fix:**
```cmd
docker compose down --volumes
rmdir /s /q oracle_oradata
mkdir oracle_oradata
rmdir /s /q ords_config
mkdir ords_config
```
Then fix your password in `docker-compose.yml` and run `docker compose up` again.

---

## Running the Stack

### Step 1: Login to Oracle Container Registry

```cmd
docker login container-registry.oracle.com
```

Enter your Oracle account credentials (oracle.com login). Create a free account if you don't have one.

### Step 2: Start Everything

```cmd
cd C:\oracle-apex-docker
docker compose up
```

**What happens next (first run only):**

| Phase | What's happening | Time |
|---|---|---|
| Image pull | Downloads Oracle DB image (~3.7GB) | 5–15 mins |
| Image pull | Downloads ORDS image (~1GB) | 2–5 mins |
| DB creation 7% | Copying database files | 10–15 mins |
| DB creation 30% | Creating and starting Oracle instance | 3–5 mins |
| DB creation 50% | Completing database creation | 3–5 mins |
| DB creation 100% | **DATABASE IS READY TO USE!** | — |
| ORDS startup | Installing ORDS 26.1.1 + APEX 26.1 | 20–30 mins |
| **Done!** | APEX ready at localhost:8081 | — |

> **Total first-run time: approximately 45–90 minutes** depending on your hardware and internet speed.

> ⚠️ Do NOT close the Command Prompt window or press Ctrl+C during this process.

> ⚠️ Prevent your PC from sleeping: open a new Command Prompt and run:
> ```cmd
> powercfg /change standby-timeout-ac 0
> ```

### Step 3: Watch for the Success Message

In the logs, look for:
```
######################
DATABASE IS READY TO USE!
######################
```

Then ORDS will start and you'll see:
```
Oracle REST Data Services initialized
```

---

## Setting the APEX Admin Password

If `APEX_PWD` was set in your `docker-compose.yml`, the APEX admin password may be set automatically. If not, run this in a **new** Command Prompt:

```cmd
docker exec -it oracle-apex-docker-db-1 sqlplus sys/YourPassword123x@//localhost:1521/FREEPDB1 as sysdba
```

Then inside SQL*Plus:

```sql
@/opt/oracle/apex/apxchpwd.sql
```

Follow the prompts:
- **Username:** `ADMIN`
- **Email:** your email address
- **Password:** a strong password (this time special chars ARE allowed, e.g. `MyApex26#`)

---

## Accessing APEX in Your Browser

Open any browser on your Windows 11 machine and go to:

```
http://localhost:8081/ords/apex
```

Login with:

| Field | Value |
|---|---|
| Workspace | `INTERNAL` |
| Username | `ADMIN` |
| Password | password you set in apxchpwd.sql |

---

## APEXlang — No Extra Install Needed

**APEXlang** is the headline feature of APEX 26.1 — an open, declarative, human-readable specification language for Oracle APEX applications.

> ✅ APEXlang is **built into APEX 26.1** — no separate download or installation required.

Once you're logged into APEX, APEXlang is available immediately:
- **APEXlang View** in Page Designer
- **Export apps** as `.apx` text files
- **Git-friendly diffs** with Static IDs
- **AI-ready** application metadata

Other APEX 26.1 features also available out of the box:
- **AI Interactive Reports** — natural language queries on your data
- **AI Agents & AI Tools** — governed conversational action in applications
- **Data Reporter** — self-service reporting for business users

---

## Configuring AI Providers in APEX 26.1

APEX 26.1 supports connecting to external AI models through **Generative AI Services**. This powers features like AI Interactive Reports, AI Agents, and the App Builder AI assistant.

You can configure **two types** of AI providers — as shown in this working setup:

| Provider | Type | Model Used |
|---|---|---|
| OCI AI Provider | OCI Generative AI Service | `xai.grok-4-1-fast-reasoning` |
| ollama local | Ollama (local LLM) | `llama3.2:latest` |

---

### Step 1: Go to Workspace Utilities → Generative AI

1. Log into APEX at `http://localhost:8081/ords/apex`
2. From the App Builder home, click the **Workspace Utilities** icon (grid icon in left sidebar)
3. Click **Generative AI**
4. Click **Create** to add a new AI provider

---

### Option A: Configure OCI Generative AI Service (Cloud)

This uses Oracle Cloud Infrastructure's AI inference endpoint.

**What you need first:**
- An OCI account (free tier works)
- Your OCI **Compartment ID** (from OCI Console → Identity → Compartments)
- OCI **API Key** credentials (User → API Keys → Add API Key)

**Steps in APEX:**

1. Click **Create** on the Generative AI Services page
2. Fill in the **Identification** section:
   - **AI Provider:** `OCI Generative AI Service`
   - **Name:** `OCI AI Provider` (or any name you prefer)

3. Fill in the **OCI Generative AI** section:
   - **Compartment ID:** your OCI compartment OCID
     ```
     ocid1.tenancy.oc1..aaaaaaaa...
     ```
   - **Region:** `us-phoenix-1` (or your nearest region)
     - Available regions: US Midwest (Chicago), US East (Ashburn), US West (Phoenix), Germany Central (Frankfurt), UK South (London)
   - **Model ID:** choose your model, e.g.:
     ```
     xai.grok-4-1-fast-reasoning
     ```
     Other options: `meta.llama-3-70b-instruct`, `cohere.command-r-plus`, etc.

4. Fill in the **Settings** section:
   - **Used by App Builder:** ✅ Toggle ON
   - **Default for New Apps:** ✅ Toggle ON
   - **Base URL:**
     ```
     https://inference.generativeai.us-phoenix-1.oci.oraclecloud.com
     ```

5. Fill in the **Credentials** section:
   - Select or create OCI credentials (your API Key private key)

6. Click **Test Connection** to verify
7. Click **Apply Changes**

---

### Option B: Configure Ollama (Local LLM — No Cloud Needed)

Ollama lets you run AI models **entirely on your local machine** — no internet or OCI account required. Perfect for development and privacy-sensitive scenarios.

**Prerequisites:**
- Install Ollama from: https://ollama.com/download
- Pull a model, e.g.:
  ```cmd
  ollama pull llama3.2
  ```
- Ollama runs on `http://localhost:11434` by default

> ⚠️ When APEX runs inside Docker, it cannot use `localhost` to reach Ollama on your Windows host. Use the special Docker hostname instead:
> ```
> http://host.docker.internal:11434
> ```

**Steps in APEX:**

1. Click **Create** on the Generative AI Services page
2. Fill in:
   - **AI Provider:** `Ollama`
   - **Name:** `ollama local`
   - **Base URL:** `http://host.docker.internal:11434`
   - **Model ID:** `llama3.2:latest`
3. Leave credentials empty (Ollama has no auth by default)
4. Click **Test Connection**
5. Click **Apply Changes**

---

### Step 2: Enable AI on Your Application

Once a provider is configured, enable it on individual applications:

1. Open your application in App Builder
2. Click **Edit Application Definition** (top right)
3. Go to the **AI** tab
4. Set **Service** to your configured provider (e.g. `OCI AI Provider`)
5. Add a **Consent Message** if desired:
   ```
   This application uses AI to assist you. Your data may be 
   processed by OCI Generative AI Services.
   ```
6. Click **Apply Changes**

Or from the App Builder home page, click **"Enable Generative AI"** → **Configure** in the right panel.

---

### Generative AI Services Summary

```
Workspace Utilities → Generative AI Services
│
├── OCI AI Provider (cloud)
│   ├── Provider: OCI Generative AI Service
│   ├── Region: us-phoenix-1
│   ├── Model: xai.grok-4-1-fast-reasoning
│   ├── Base URL: https://inference.generativeai.us-phoenix-1.oci.oraclecloud.com
│   └── Used by App Builder: ✅ Yes
│
└── ollama local (on-premise)
    ├── Provider: Ollama
    ├── Model: llama3.2:latest
    ├── Base URL: http://host.docker.internal:11434
    └── No credentials required
```

---

## Managing Your Docker Stack

### Start containers (after first setup)
```cmd
cd C:\oracle-apex-docker
docker compose up -d
```
> On subsequent starts, the DB boots in ~2–3 minutes (no rebuild).

### Stop containers
```cmd
docker compose down
```

### Check container status
```cmd
docker ps
```

### View logs
```cmd
docker logs oracle-apex-docker-db-1
docker logs oracle-apex-docker-ords-1
```

### Restart only ORDS (if it exits)
```cmd
docker compose restart ords
```

### Full clean reset (⚠️ deletes all DB data)
```cmd
docker compose down --volumes
rmdir /s /q oracle_oradata
mkdir oracle_oradata
rmdir /s /q ords_config
mkdir ords_config
docker compose up
```

---

## Troubleshooting Reference

| Symptom | Cause | Fix |
|---|---|---|
| Password invalid chars error | `!`, `#`, `@` in password | Use alphanumeric password only |
| DB container unhealthy | Healthcheck fires too early | Add `start_period: 300s` |
| ORDS exits with ORA-12514 | PDB not registered yet | Add `restart: on-failure` to ords |
| Password cannot be null loop | Bad password from previous run | `docker compose down --volumes`, recreate folders |
| ORDS container not running | Timing issue on first connect | `docker compose restart ords` |
| Browser can't reach localhost:8081 | ORDS not started yet | Wait for "REST Data Services initialized" in logs |
| DB stuck at 7% for long time | Normal — large file copy | Wait 10–15 minutes, don't interrupt |

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│           ORACLE APEX 26.1 — DOCKER QUICK REF           │
├─────────────────────────────────────────────────────────┤
│  APEX URL      │  http://localhost:8081/ords/apex        │
│  DB Port       │  1522 (mapped from container 1521)      │
│  ORDS Port     │  8081 (mapped from container 8080)      │
│  PDB Name      │  FREEPDB1                               │
│  DB Image      │  free:23.26.0.0                         │
│  ORDS Image    │  ords:latest (26.1.1)                   │
├─────────────────────────────────────────────────────────┤
│  APEX Login                                             │
│  Workspace     │  INTERNAL                              │
│  Username      │  ADMIN                                 │
│  Password      │  (set via apxchpwd.sql)                │
├─────────────────────────────────────────────────────────┤
│  START         │  docker compose up -d                  │
│  STOP          │  docker compose down                   │
│  STATUS        │  docker ps                             │
│  ORDS RESTART  │  docker compose restart ords           │
└─────────────────────────────────────────────────────────┘
```

---

## Notes

- **Your existing Oracle databases are safe.** This Docker setup uses port `1522` for the DB and `8081` for APEX — no conflict with any local Oracle instance on port `1521`.
- **Data persists** between container restarts because `oracle_oradata` is mounted as a volume on your Windows filesystem.
- **APEX files in `C:\oracle-apex-docker\apex\`** are only needed during initial setup. After APEX is installed into the DB, they are no longer actively used — but keep them in case you need to reinstall.
- This setup is intended for **local development**. For production, additional security hardening is required.

---

## Acknowledgements

This guide was built through a real, live installation session on Windows 11 — including encountering and resolving every error documented here. Hopefully it saves you the hours it took to figure out!

If this helped you, consider starring the repo and sharing it with the Oracle APEX community. 🚀

---

*Guide compiled: May 2026 | Oracle APEX 26.1 | Oracle AI Database 26ai Free 23.26.0.0 | ORDS 26.1.1 | Docker Desktop on Windows 11*

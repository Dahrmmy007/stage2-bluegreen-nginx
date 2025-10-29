# HNG Stage 2 - Blue-Green Deployment with Docker & Nginx

**Name:** Ologbon Damilola  
**Slack Username:** Damien  
**Track:** DevOps  
**Stage:** 2 - Zero-Downtime Blue-Green Deployment

---

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Setup Instructions](#setup-instructions)
- [Testing Guide](#testing-guide)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Technical Specifications](#technical-specifications)
- [Success Criteria](#success-criteria)

---

## 🎯 Project Overview

This project implements a **zero-downtime blue-green deployment system** using Docker Compose and Nginx as a load balancer. The system automatically detects failures in the primary service and switches to the backup service within seconds, ensuring high availability and resilience.

### Key Features

✅ **Automatic Failover** - Switches from Blue to Green on failure detection  
✅ **Zero Downtime** - No failed requests during failover  
✅ **Fast Detection** - Aggressive timeouts (2-3 seconds)  
✅ **Health Monitoring** - Continuous health checks on all services  
✅ **Header Preservation** - Forwards application headers unchanged  
✅ **Dynamic Configuration** - Environment-based setup via `.env` file

### What Makes This Special

- **Sub-5 Second Failover**: Detects and switches to backup in under 5 seconds
- **Retry Logic**: Automatically retries failed requests on backup server
- **Zero Failed Requests**: Client never sees 5xx errors during failover
- **Production-Ready**: Implements industry-standard high availability patterns

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Client                              │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          │ HTTP Request
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Nginx Load Balancer                       │
│                    (Port 8080)                               │
│                                                              │
│  • Primary/Backup Upstream Configuration                     │
│  • Health Checks & Timeouts                                  │
│  • Automatic Retry Logic                                     │
│  • Header Forwarding                                         │
└─────────────┬────────────────────────────┬──────────────────┘
              │                            │
              │ Primary                    │ Backup
              │ (max_fails=1)              │ (activated on failure)
              │                            │
              ▼                            ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│   Blue Service          │    │   Green Service         │
│   (Port 8081)           │    │   (Port 8082)           │
│                         │    │                         │
│   Node.js App           │    │   Node.js App           │
│   • /version            │    │   • /version            │
│   • /healthz            │    │   • /healthz            │
│   • /chaos/*            │    │   • /chaos/*            │
└─────────────────────────┘    └─────────────────────────┘
```

### Failover Flow

```
1. Normal State
   Client → Nginx → Blue (200 OK)
   
2. Blue Fails
   Client → Nginx → Blue (timeout/5xx)
   
3. Automatic Retry
   Client → Nginx → Green (200 OK)
   
4. Result
   Client receives 200 OK (never sees the failure)
```

---

## ✅ Prerequisites

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **curl**: For testing endpoints
- **Git**: For cloning the repository

### Installation Check

```bash
# Check Docker
docker --version

# Check Docker Compose
docker-compose --version

# Check curl
curl --version
```

---

## 📁 Project Structure

```
stage2-bluegreen-nginx/
├── docker-compose.yml          # Service orchestration
├── entrypoint.sh              # Dynamic nginx config generator
├── .env                       # Environment variables
├── .gitignore                 # Git ignore rules
├── README.md                  # This file
├── SUMMARY.md                 # Project summary
└── BACKEND_IM_RESEARCH.md     # Technical deep-dive
```

---

## 🚀 Setup Instructions

### Step 1: Clone the Repository

```bash
git clone <your-repo-url>
cd stage2-bluegreen-nginx
```

### Step 2: Make Entrypoint Executable

```bash
chmod +x entrypoint.sh
```

### Step 3: Pull Docker Images

```bash
docker pull yimikaade/wonderful:devops-stage-two
```

### Step 4: Configure Environment

The `.env` file contains:

```bash
# Application Images
BLUE_IMAGE=yimikaade/wonderful:devops-stage-two
GREEN_IMAGE=yimikaade/wonderful:devops-stage-two

# Active Pool Configuration
ACTIVE_POOL=blue

# Release Identifiers
RELEASE_ID_BLUE=v1.0.0-blue
RELEASE_ID_GREEN=v1.0.0-green
```

### Step 5: Start Services

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

### Expected Output

```
NAME                IMAGE                                    STATUS
app_blue            yimikaade/wonderful:devops-stage-two     Up (healthy)
app_green           yimikaade/wonderful:devops-stage-two     Up (healthy)
nginx_lb            nginx:alpine                             Up
```

---

## 🧪 Testing Guide

### Test 1: Basic Connectivity

```bash
# Test main endpoint
curl http://localhost:8080/version

# Expected output:
# {"status":"OK","message":"Application version in header"}

# View headers
curl -i http://localhost:8080/version

# Should see:
# X-App-Pool: blue
# X-Release-Id: v1.0.0-blue
```

### Test 2: Verify Blue is Active

```bash
# Make 5 requests
for i in {1..5}; do
  echo "Request $i:"
  curl -v http://localhost:8080/version 2>&1 | grep "X-App-Pool"
  sleep 1
done

# All should show: X-App-Pool: blue
```

### Test 3: Direct Container Access

```bash
# Access Blue directly (bypass nginx)
curl http://localhost:8081/version

# Access Green directly (bypass nginx)
curl http://localhost:8082/version

# Both should respond with 200 OK
```

### Test 4: Trigger Failover (Critical Test!)

```bash
# Step 1: Simulate failure on Blue
curl -X POST http://localhost:8081/chaos/start?mode=error

# Step 2: Test through nginx (should auto-switch to Green)
curl -i http://localhost:8080/version

# Should now show:
# X-App-Pool: green
# X-Release-Id: v1.0.0-green

# Step 3: Make multiple requests
for i in {1..10}; do
  echo "Request $i:"
  curl -v http://localhost:8080/version 2>&1 | grep "X-App-Pool"
  sleep 1
done

# All should show: X-App-Pool: green
```

### Test 5: Recovery Test

```bash
# Step 1: Stop chaos on Blue
curl -X POST http://localhost:8081/chaos/stop

# Step 2: Wait for Blue to recover
sleep 10

# Step 3: Verify Blue is active again
curl -i http://localhost:8080/version

# Should show: X-App-Pool: blue
```

### Test 6: Zero-Downtime Verification

Run this in one terminal:

```bash
# Monitor for failures
while true; do 
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/version)
  TIMESTAMP=$(date '+%H:%M:%S')
  if [ "$STATUS" != "200" ]; then 
    echo "$TIMESTAMP - ❌ FAILED: Got status $STATUS"
  else
    echo "$TIMESTAMP - ✅ OK: $STATUS"
  fi
  sleep 0.5
done
```

In another terminal, trigger chaos:

```bash
curl -X POST http://localhost:8081/chaos/start?mode=error
```

**Expected Result**: Zero failures (all responses should be 200)

### Complete Automated Test Script

```bash
#!/bin/bash

echo "========================================="
echo "BLUE-GREEN DEPLOYMENT TEST"
echo "========================================="
echo ""

echo "1. ✓ Checking container status..."
docker-compose ps
echo ""

echo "2. ✓ Testing normal operation (Blue active)..."
curl -v http://localhost:8080/version 2>&1 | grep -E "X-App-Pool|X-Release-Id"
echo ""

echo "3. ✓ Making 3 baseline requests..."
for i in {1..3}; do
  POOL=$(curl -s -v http://localhost:8080/version 2>&1 | grep "X-App-Pool" | awk '{print $3}')
  echo "   Request $i: Pool = $POOL"
  sleep 1
done
echo ""

echo "4. ✓ Triggering chaos on Blue..."
curl -s -X POST http://localhost:8081/chaos/start?mode=error > /dev/null
sleep 2
echo ""

echo "5. ✓ Testing automatic failover to Green..."
for i in {1..5}; do
  POOL=$(curl -s -v http://localhost:8080/version 2>&1 | grep "X-App-Pool" | awk '{print $3}')
  echo "   Request $i: Pool = $POOL"
  sleep 1
done
echo ""

echo "6. ✓ Stopping chaos..."
curl -s -X POST http://localhost:8081/chaos/stop > /dev/null
echo "   Waiting 10 seconds for Blue to recover..."
sleep 10
echo ""

echo "7. ✓ Verifying Blue recovery..."
curl -v http://localhost:8080/version 2>&1 | grep -E "X-App-Pool|X-Release-Id"
echo ""

echo "========================================="
echo "✅ TEST COMPLETE!"
echo "========================================="
```

---

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BLUE_IMAGE` | Docker image for Blue service | `yimikaade/wonderful:devops-stage-two` |
| `GREEN_IMAGE` | Docker image for Green service | `yimikaade/wonderful:devops-stage-two` |
| `ACTIVE_POOL` | Primary pool (blue or green) | `blue` |
| `RELEASE_ID_BLUE` | Blue release identifier | `v1.0.0-blue` |
| `RELEASE_ID_GREEN` | Green release identifier | `v1.0.0-green` |

### Nginx Timeout Configuration

```nginx
proxy_connect_timeout 2s;    # Connection timeout
proxy_send_timeout 3s;       # Send timeout
proxy_read_timeout 3s;       # Read timeout
```

### Upstream Configuration

```nginx
upstream backend {
    server app_blue:3000 max_fails=1 fail_timeout=5s;
    server app_green:3000 backup;
}
```

### Health Check Configuration

```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/healthz"]
  interval: 5s
  timeout: 3s
  retries: 3
  start_period: 10s
```

---

## 🔧 Troubleshooting

### Issue: Container Unhealthy

```bash
# Check logs
docker-compose logs app_blue
docker-compose logs app_green

# Check health status
docker inspect app_blue --format='{{.State.Health.Status}}'

# Restart unhealthy container
docker-compose restart app_blue
```

### Issue: Nginx Not Forwarding Requests

```bash
# View nginx configuration
docker exec nginx_lb cat /etc/nginx/conf.d/default.conf

# Test nginx config
docker exec nginx_lb nginx -t

# Reload nginx
docker exec nginx_lb nginx -s reload
```

### Issue: Failover Not Working

```bash
# Check if chaos is active
curl http://localhost:8081/version

# Verify nginx upstream config
docker exec nginx_lb cat /etc/nginx/conf.d/default.conf | grep -A 5 "upstream backend"

# Check nginx error logs
docker-compose logs nginx_lb | grep error
```

### Issue: Port Already in Use

```bash
# Find process using port
sudo lsof -i :8080
sudo lsof -i :8081
sudo lsof -i :8082

# Kill process or change ports in docker-compose.yml
```

---

## 📊 Technical Specifications

### Service Ports

| Service | Internal Port | External Port | Purpose |
|---------|--------------|---------------|---------|
| Blue | 3000 | 8081 | Primary application |
| Green | 3000 | 8082 | Backup application |
| Nginx | 80 | 8080 | Load balancer |

### Failover Metrics

- **Detection Time**: 2-3 seconds
- **Switchover Time**: < 1 second
- **Total Failover Time**: < 5 seconds
- **Max Fails Before Failover**: 1
- **Fail Timeout**: 5 seconds

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/version` | GET | Returns app version and headers |
| `/healthz` | GET | Health check endpoint |
| `/chaos/start?mode=error` | POST | Trigger 500 errors |
| `/chaos/start?mode=timeout` | POST | Trigger timeouts |
| `/chaos/stop` | POST | Stop chaos mode |
| `/nginx-health` | GET | Nginx health status |

---

## ✅ Success Criteria

The deployment is considered successful if:

1. ✅ All containers start and become healthy
2. ✅ Normal requests go to Blue (primary pool)
3. ✅ Zero non-200 responses during failover
4. ✅ Automatic switch to Green within 5 seconds of Blue failure
5. ✅ All responses contain correct `X-App-Pool` header
6. ✅ All responses contain correct `X-Release-Id` header
7. ✅ ≥95% of requests served by Green during Blue failure
8. ✅ Blue recovers and becomes active after chaos stops

---

## 🎓 Learning Outcomes

This project demonstrates:

- Docker containerization and orchestration
- Nginx reverse proxy configuration
- High availability patterns (blue-green deployment)
- Health checks and monitoring
- Automatic failover mechanisms
- Zero-downtime deployment strategies
- Production-ready DevOps practices

---

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Blue-Green Deployment Pattern](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [HNG Internship](https://hng.tech/)

---

## 👤 Author

**Ologbon Damilola (Damien)**  
DevOps Track - HNG13 Internship  
Stage 2 - Blue-Green Deployment

---

## 📝 License

This project is created for educational purposes as part of the HNG Internship program.

---

**Last Updated**: October 29, 2025
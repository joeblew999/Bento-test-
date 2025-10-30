# Deploying Bento to Fly.io

This guide covers deploying Bento stream processor to Fly.io, which provides a more traditional container deployment model compared to Cloudflare.

## Why Fly.io?

Unlike Cloudflare Containers, Fly.io offers:
- **Direct container access** - No Worker proxy required
- **Traditional networking** - Containers get direct HTTP/HTTPS access
- **Simpler architecture** - Deploy and access like any container platform
- **Multiple regions** - Deploy globally with automatic routing
- **Built-in load balancing** - Automatic traffic distribution

## Prerequisites

1. **Fly.io Account** (Free tier available!)
   - Sign up at https://fly.io/app/sign-up
   - Free tier includes: 3 shared-cpu-1x VMs, 3GB storage

2. **Fly CLI** installed
   ```bash
   # macOS
   brew install flyctl

   # Linux
   curl -L https://fly.io/install.sh | sh

   # Windows
   iwr https://fly.io/install.ps1 -useb | iex
   ```

3. **Docker** installed (Fly.io builds use Docker)
   ```bash
   docker --version
   ```

4. **Fly CLI Authentication**
   ```bash
   flyctl auth login
   ```

## Quick Start

### 1. Initialize Fly.io App

```bash
# Create new Fly.io app (auto-generates fly.toml)
flyctl launch --no-deploy

# Or use the included fly.toml
flyctl launch --config fly.toml --no-deploy
```

During `flyctl launch`, you'll be asked:
- **App name:** e.g., `bento-fly` (must be globally unique)
- **Region:** Choose closest to your users (e.g., `iad` for US East)
- **Database:** Select "No" (Bento doesn't need a database)

### 2. Deploy

```bash
# Deploy to Fly.io
flyctl deploy

# Watch deployment progress
flyctl logs
```

### 3. Test

```bash
# Get your app URL
flyctl status

# Test the deployment
curl https://bento-fly.fly.dev/ping

# Process data
curl -X POST https://bento-fly.fly.dev/process \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from Fly.io!"}'
```

## Configuration

### Fly.io Configuration (fly.toml)

The included `fly.toml` is pre-configured for Bento:

```toml
app = "bento-fly"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[[services]]
  protocol = "tcp"
  internal_port = 8080
  auto_stop_machines = true   # Scale to zero
  auto_start_machines = true
  min_machines_running = 0

[vm]
  cpus = 1
  memory_mb = 1024  # 1 GB RAM
```

### Key Settings Explained

**Auto-scaling:**
- `auto_stop_machines = true` - Stops machines when idle (saves money)
- `auto_start_machines = true` - Starts on new requests
- `min_machines_running = 0` - Scale to zero (like Cloudflare)

**Resources:**
- `cpus = 1` - 1 shared CPU
- `memory_mb = 1024` - 1 GB RAM (comparable to Cloudflare "basic")

**Health Checks:**
- Uses Bento's `/ping` endpoint
- Checks every 15 seconds
- Ensures container is healthy

### Bento Configuration

Uses the same `bento.yaml` as Cloudflare deployment. No changes needed!

## Key Differences from Cloudflare

### Architecture Comparison

**Cloudflare:**
```
Internet → Worker (proxy) → Container → Bento
```

**Fly.io:**
```
Internet → Bento Container (direct)
```

### Access Pattern

**Cloudflare:**
- Must proxy ALL requests through Worker
- Container is private by default
- Worker code required

**Fly.io:**
- Direct HTTP/HTTPS access to container
- Public by default (with HTTPS)
- No proxy code needed

### Example Requests

**Cloudflare:**
```bash
# Must go through Worker URL
curl https://bento-cloudflare.workers.dev/bentows/ping
```

**Fly.io:**
```bash
# Direct to container
curl https://bento-fly.fly.dev/ping
```

## Deployment Commands

### Initial Deployment

```bash
# Deploy
flyctl deploy

# Deploy with custom name
flyctl deploy --app bento-custom-name

# Deploy to specific region
flyctl deploy --region sjc  # San Jose, CA
```

### Managing Deployments

```bash
# Check status
flyctl status

# View logs (live tail)
flyctl logs

# SSH into container
flyctl ssh console

# Scale manually
flyctl scale count 2  # Run 2 instances

# Scale to zero
flyctl scale count 0
```

### Regions and Scaling

```bash
# List available regions
flyctl platform regions

# Add region (multi-region deployment)
flyctl regions add lhr  # Add London

# Set backup regions
flyctl regions set iad lhr sjc  # US East, London, San Jose

# View current regions
flyctl regions list
```

## Testing Your Deployment

### Test 1: Basic Health Check

```bash
flyctl status

# Or via curl
curl https://YOUR-APP.fly.dev/ping
```

### Test 2: Process Data

```bash
curl -X POST https://YOUR-APP.fly.dev/process \
  -H "Content-Type: application/json" \
  -d '{
    "user": "test",
    "message": "Hello Bento on Fly.io!"
  }'
```

### Test 3: View Metrics

```bash
curl https://YOUR-APP.fly.dev/metrics
```

### Test 4: Load Test

```bash
# Install hey (HTTP load generator)
# macOS: brew install hey
# Linux: go install github.com/rakyll/hey@latest

# Run load test
hey -n 1000 -c 10 -m POST \
  -H "Content-Type: application/json" \
  -d '{"test": true}' \
  https://YOUR-APP.fly.dev/process
```

## Monitoring and Debugging

### View Logs

```bash
# Tail logs
flyctl logs

# Search logs
flyctl logs --search "error"

# Logs from specific instance
flyctl logs --instance <instance-id>
```

### Metrics

```bash
# View app metrics
flyctl dashboard

# Or open in browser
flyctl dashboard --open
```

### SSH Access

```bash
# SSH into running container
flyctl ssh console

# Run commands
flyctl ssh console -C "bento --version"

# Run interactive shell
flyctl ssh console -C "/bin/sh"
```

### Debugging

```bash
# Check machine status
flyctl machine list

# View machine details
flyctl machine status <machine-id>

# Restart machine
flyctl machine restart <machine-id>

# View VM events
flyctl machine events <machine-id>
```

## Cost Comparison

### Fly.io Pricing

**Free Tier:**
- 3 shared-cpu-1x VMs (256 MB RAM each)
- 3 GB persistent storage
- 160 GB outbound transfer

**Paid Usage (beyond free tier):**
- **shared-cpu-1x (1GB RAM):** ~$1.94/month (always-on)
- **Scale-to-zero:** Only pay when running
- **Bandwidth:** $0.02/GB after free tier

### Example Costs

**Scenario 1: Always-On (1 instance, 1GB RAM)**
- Cost: ~$1.94/month
- Cheaper than Cloudflare ($5-10/month)

**Scenario 2: Scale-to-Zero (intermittent use)**
- Cost: Minimal, only pay for runtime
- Similar to Cloudflare scale-to-zero model

**Scenario 3: Multi-Region (3 instances)**
- Cost: ~$5.82/month
- High availability across continents

### Cloudflare vs Fly.io Cost

| Feature | Cloudflare | Fly.io |
|---------|-----------|--------|
| **Base Plan** | $5/month | Free tier available |
| **1GB Always-On** | ~$9.50/month | ~$1.94/month |
| **Scale-to-Zero** | ✅ Yes | ✅ Yes |
| **Multi-Region** | Automatic (300+ locations) | Manual (30+ regions) |

**Winner for cost:** Fly.io for always-on, Cloudflare for global edge

## Production Configuration

### 1. Custom Domain

```bash
# Add custom domain
flyctl certs add bento.yourdomain.com

# Verify DNS
flyctl certs show bento.yourdomain.com
```

Add this DNS record:
```
CNAME bento.yourdomain.com -> YOUR-APP.fly.dev
```

### 2. Secrets Management

```bash
# Set secrets
flyctl secrets set API_KEY=your-secret-key

# List secrets (values hidden)
flyctl secrets list

# Remove secret
flyctl secrets unset API_KEY
```

Update `bento.yaml` to use secrets:
```yaml
input:
  http_server:
    auth:
      basic:
        username: ${API_USERNAME}
        password: ${API_PASSWORD}
```

### 3. Persistent Storage (if needed)

```bash
# Create volume
flyctl volumes create bento_data --size 1

# Update fly.toml
[mounts]
  source = "bento_data"
  destination = "/data"
```

### 4. Multi-Region Deployment

```toml
# In fly.toml
[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0

# Set backup regions
[backup_regions]
  regions = ["iad", "lhr", "sjc"]
```

Deploy:
```bash
flyctl regions set iad lhr sjc
flyctl scale count 3
```

### 5. Advanced Health Checks

Update `fly.toml`:
```toml
[[services.http_checks]]
  interval = "10s"
  timeout = "5s"
  method = "GET"
  path = "/ready"
  protocol = "http"

  [services.http_checks.headers]
    X-Health-Check = "fly-health"
```

## Troubleshooting

### Issue: "failed to fetch an image"

**Solution:**
```bash
# Build locally and push
flyctl deploy --local-only
```

### Issue: "health checks failing"

**Solution:**
```bash
# Check logs
flyctl logs

# Verify Bento is listening
flyctl ssh console -C "netstat -ln | grep 8080"

# Test health endpoint locally
flyctl ssh console -C "wget -O- http://localhost:8080/ping"
```

### Issue: "app not responding"

**Solution:**
```bash
# Check machine status
flyctl machine list

# Restart machines
flyctl machine restart <machine-id>

# Or scale to force new machines
flyctl scale count 0
flyctl scale count 1
```

### Issue: "out of memory"

**Solution:**
```bash
# Increase memory
flyctl scale memory 2048  # 2 GB

# Or update fly.toml
[vm]
  memory_mb = 2048
```

## Advanced Features

### WebSocket Support

Fly.io supports WebSockets out of the box. Update `bento.yaml`:

```yaml
input:
  websocket:
    address: "0.0.0.0:8080"
    path: /ws

output:
  sync_response: {}
```

### Private Networking

Connect multiple Fly.io apps:

```bash
# Get internal address
flyctl ips private

# Use in other apps
# e.g., http://bento-fly.internal:8080
```

### Running Background Jobs

Add a background process:

```toml
[processes]
  web = "bento -c /config.yaml"
  worker = "bento -c /worker-config.yaml"
```

## Comparison: When to Use Fly.io vs Cloudflare

### Use Fly.io When:

✅ You want **direct container access**
✅ You need **traditional networking** (TCP/UDP)
✅ You want **simpler architecture** (no Worker proxy)
✅ You need **SSH access** to debug
✅ You want **lower costs** for always-on workloads
✅ You need **WebSocket support** without extra config
✅ You want **multi-region** control

### Use Cloudflare When:

✅ You want **edge processing** (300+ locations)
✅ You need **ultra-low latency** globally
✅ You're already using **Cloudflare Workers**
✅ You want **integrated DDoS protection**
✅ You need **scale-to-zero** with instant cold starts
✅ You prefer **serverless architecture**

## Next Steps

1. **Deploy to Production:**
   ```bash
   flyctl deploy --strategy immediate
   ```

2. **Set Up Monitoring:**
   - Configure alerts in Fly.io dashboard
   - Integrate with Sentry, Datadog, etc.

3. **Optimize Performance:**
   - Add more regions for geo-distribution
   - Tune `min_machines_running` for your load

4. **Secure Your App:**
   - Add authentication to Bento
   - Use Fly.io secrets for credentials
   - Configure firewall rules

## Resources

- **Fly.io Docs:** https://fly.io/docs/
- **Fly.io CLI Reference:** https://fly.io/docs/flyctl/
- **Bento Documentation:** https://warpstreamlabs.github.io/bento/
- **Comparison Report:** See `PLATFORM_COMPARISON.md`

---

**Ready to deploy?** Run `flyctl launch` and `flyctl deploy`! 🚀

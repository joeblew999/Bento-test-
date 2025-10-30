# Bento on Cloudflare Containers & Fly.io

Deploy [Bento](https://github.com/warpstreamlabs/bento) stream processor to modern container platforms: Cloudflare Containers and Fly.io.

## What's Inside

This repository contains everything you need to deploy Bento to two different container platforms, with complete configuration examples and deployment guides.

### What is Bento?

[Bento](https://warpstreamlabs.github.io/bento/) is a fancy stream processing tool that makes operationally mundane tasks simple. It's written in Go and can:
- Transform data between various sources and sinks
- Process streams with powerful transformations (Bloblang)
- Connect to Kafka, databases, APIs, cloud services, and more
- Run as a lightweight Docker container

## Quick Start

### Option 1: Deploy to Fly.io (Recommended for Testing)

```bash
# Install Fly CLI
brew install flyctl  # macOS
# or: curl -L https://fly.io/install.sh | sh

# Login
flyctl auth login

# Deploy
flyctl launch
flyctl deploy

# Test
curl https://YOUR-APP.fly.dev/ping
```

### Option 2: Deploy to Cloudflare Containers

```bash
# Install Wrangler
npm install -g wrangler

# Login
wrangler login

# Deploy
wrangler deploy

# Test
curl https://YOUR-WORKER.workers.dev/bentows/ping
```

## Project Structure

```
.
├── bento.yaml              # Bento stream processor config
├── Dockerfile              # Docker image for Bento
├── fly.toml                # Fly.io deployment config
├── wrangler.toml           # Cloudflare deployment config
├── src/
│   └── worker.js           # Cloudflare Worker (proxy to container)
├── test-requests.sh        # Test script for both platforms
├── DEPLOYMENT.md           # Cloudflare deployment guide
├── FLY_DEPLOYMENT.md       # Fly.io deployment guide
├── PLATFORM_COMPARISON.md  # Detailed comparison
└── CLOUDFLARE_DEPLOYMENT_FEASIBILITY.md  # Technical feasibility analysis
```

## Documentation

### Deployment Guides
- **[Cloudflare Deployment Guide](DEPLOYMENT.md)** - Deploy to Cloudflare Containers
- **[Fly.io Deployment Guide](FLY_DEPLOYMENT.md)** - Deploy to Fly.io
- **[Platform Comparison](PLATFORM_COMPARISON.md)** - Compare both platforms
- **[Feasibility Report](CLOUDFLARE_DEPLOYMENT_FEASIBILITY.md)** - Technical deep dive

### Configuration Files
- `bento.yaml` - Bento configuration (works on both platforms)
- `wrangler.toml` - Cloudflare Workers + Containers config
- `fly.toml` - Fly.io configuration
- `Dockerfile` - Docker image definition

## Platform Comparison

| Feature | Cloudflare | Fly.io |
|---------|-----------|--------|
| **Deployment Complexity** | Moderate (requires Worker) | Simple (standard Docker) |
| **Cost (1GB, 24/7)** | ~$9.50/month | ~$1.94/month |
| **Free Tier** | No ($5/month minimum) | Yes |
| **Direct Container Access** | No (via Worker) | Yes |
| **SSH Access** | No | Yes |
| **Global Edge Locations** | 300+ (automatic) | 30+ (manual) |
| **TCP/UDP Support** | No | Yes |
| **Best For** | Edge processing, serverless | Traditional containers, stream processing |

**See [PLATFORM_COMPARISON.md](PLATFORM_COMPARISON.md) for detailed comparison.**

## Use Cases

### This Setup Works Great For:

✅ **HTTP API Data Transformation**
```bash
curl -X POST https://your-app/process \
  -H "Content-Type: application/json" \
  -d '{"user": "alice", "action": "login"}'
```

✅ **Webhook Processing**
- Receive webhooks from external services
- Transform and forward to internal systems
- Global deployment for low latency

✅ **Stream Processing** (Fly.io only)
- Kafka consumers
- Message queue processing
- Continuous data pipelines

✅ **Edge Data Processing** (Cloudflare only)
- Process data close to users (300+ locations)
- Ultra-low latency transformations
- Integrated DDoS protection

### Architecture Differences

**Cloudflare:**
```
Internet → Worker (proxy) → Container → Bento
```
- Requires Worker proxy code
- Container is private
- Best for serverless patterns

**Fly.io:**
```
Internet → Container → Bento
```
- Direct access
- Standard Docker deployment
- Best for traditional services

## Testing

### Run Tests Against Both Platforms

```bash
# Make script executable
chmod +x test-requests.sh

# Test Cloudflare deployment
./test-requests.sh cloudflare

# Test Fly.io deployment
./test-requests.sh fly
```

### Manual Testing

**Health Check:**
```bash
# Fly.io
curl https://YOUR-APP.fly.dev/ping

# Cloudflare
curl https://YOUR-WORKER.workers.dev/bentows/ping
```

**Process Data:**
```bash
# Both platforms (adjust URL)
curl -X POST https://YOUR-URL/process \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello Bento!",
    "timestamp": "2025-10-30T12:00:00Z"
  }'
```

**Expected Response:**
```json
{
  "message": "Hello Bento!",
  "timestamp": "2025-10-30T12:00:00Z",
  "processed_by": "bento",
  "timestamp": 1730289600,
  "original_data": {
    "message": "Hello Bento!",
    "timestamp": "2025-10-30T12:00:00Z"
  }
}
```

## Customizing Bento

Edit `bento.yaml` to customize the stream processing pipeline:

```yaml
# Example: Transform and forward to webhook
input:
  http_server:
    path: /process

pipeline:
  processors:
    - bloblang: |
        root.user_id = this.user.id
        root.action = this.action.uppercase()
        root.processed_at = now().ts_unix()

output:
  http_client:
    url: https://your-webhook.example.com/events
    verb: POST
```

See [Bento documentation](https://warpstreamlabs.github.io/bento/) for more processors and configurations.

## Cost Estimates

### Fly.io (Recommended for Cost)
- **Development:** Free tier
- **Production (1GB RAM, always-on):** ~$1.94/month
- **Multi-region (3x1GB):** ~$5.82/month

### Cloudflare Containers
- **Development:** $5/month (minimum)
- **Production (1GB RAM, always-on):** ~$9.50/month
- **With scale-to-zero:** ~$5-7/month

**For most use cases, Fly.io is 5x cheaper.**

## When to Use Which?

### Use Fly.io When:
- You want to save money
- You need direct container access
- You're consuming from Kafka/message queues
- You need SSH access for debugging
- You prefer standard Docker workflows

### Use Cloudflare When:
- You need ultra-global distribution (300+ locations)
- You're building serverless applications
- You want integrated DDoS protection
- You're already using Cloudflare Workers/Pages
- You need extreme edge performance

## Prerequisites

### For Cloudflare:
- Cloudflare account with paid plan ($5/month minimum)
- Wrangler CLI: `npm install -g wrangler`
- Docker (for custom builds)

### For Fly.io:
- Fly.io account (free tier available)
- Fly CLI: `brew install flyctl` or see [installation docs](https://fly.io/docs/hands-on/install-flyctl/)
- Docker (for custom builds)

## Troubleshooting

### Cloudflare: Container not responding
```bash
# Check logs
wrangler tail

# Verify configuration
wrangler deployments list
```

### Fly.io: Container not starting
```bash
# Check logs
flyctl logs

# SSH into container
flyctl ssh console

# Check if Bento is running
ps aux | grep bento
```

### Both: Health checks failing
```bash
# Test Bento config locally
docker run --rm -v $(pwd)/bento.yaml:/config.yaml \
  ghcr.io/warpstreamlabs/bento:latest \
  bento -c /config.yaml lint
```

## Resources

### Bento
- [Bento Documentation](https://warpstreamlabs.github.io/bento/)
- [Bento GitHub](https://github.com/warpstreamlabs/bento)
- [Bloblang Language](https://warpstreamlabs.github.io/bento/docs/guides/bloblang/about/)

### Cloudflare
- [Cloudflare Containers Docs](https://developers.cloudflare.com/containers/)
- [Wrangler CLI Docs](https://developers.cloudflare.com/workers/wrangler/)
- [Cloudflare Workers](https://developers.cloudflare.com/workers/)

### Fly.io
- [Fly.io Documentation](https://fly.io/docs/)
- [Fly.io CLI Reference](https://fly.io/docs/flyctl/)
- [Fly.io Pricing](https://fly.io/docs/about/pricing/)

## Contributing

Found an issue or have a suggestion? Please open an issue or pull request!

## License

See [LICENSE](LICENSE) file for details.

---

Built with Bento, deployable to Cloudflare Containers and Fly.io.

# Deploying Bento to Cloudflare Containers

This guide walks you through deploying the Bento stream processor to Cloudflare Containers.

## Prerequisites

1. **Cloudflare Account** with a paid plan ($5/month Workers Paid plan minimum)
   - Containers are in beta and require a paid plan
   - Sign up at https://dash.cloudflare.com

2. **Wrangler CLI** installed
   ```bash
   npm install -g wrangler
   ```

3. **Docker** installed and running (for custom builds)
   ```bash
   docker --version
   ```

4. **Wrangler Authentication**
   ```bash
   wrangler login
   ```

## Project Structure

```
.
├── src/
│   └── worker.js          # Cloudflare Worker (proxy to container)
├── bento.yaml             # Bento configuration
├── wrangler.toml          # Wrangler configuration
├── Dockerfile             # Optional: custom Docker build
└── DEPLOYMENT.md          # This file
```

## Quick Start

### Option 1: Using Official Bento Image (Recommended)

This is the fastest way to get started - no Docker build required!

```bash
# 1. Deploy directly using the official image
wrangler deploy

# 2. Test the deployment
curl -X POST https://bento-cloudflare.YOUR-SUBDOMAIN.workers.dev/process \
  -H "Content-Type: application/json" \
  -d '{"test": "Hello from Bento!"}'
```

### Option 2: Using Custom Docker Image

Build a custom image with your configuration baked in:

```bash
# 1. Build the Docker image
docker build -t bento-cloudflare:latest .

# 2. Update wrangler.toml to use your custom image
# Change: image = "ghcr.io/warpstreamlabs/bento:latest"
# To:     image = "bento-cloudflare:latest"

# 3. Deploy
wrangler deploy
```

## Configuration

### Bento Configuration (bento.yaml)

The included config sets up a simple HTTP processor:

- **Input:** HTTP server on `/process` endpoint
- **Processing:** Adds metadata (timestamp, processed_by flag)
- **Output:** Returns processed JSON as HTTP response

Modify `bento.yaml` to customize the pipeline for your use case.

### Worker Configuration (wrangler.toml)

Key settings:

```toml
[[containers]]
binding = "BENTO"                              # Binding name in Worker
image = "ghcr.io/warpstreamlabs/bento:latest"  # Docker image
default_port = 8080                            # Bento HTTP port
sleep_after = 300                              # Idle timeout (seconds)
size = "basic"                                 # Container size
```

**Container Sizes:**
- `dev`: 256 MiB RAM, 1/16 vCPU (development only)
- `basic`: 1 GiB RAM, 1/4 vCPU (recommended)
- `standard`: 4 GiB RAM, 1/2 vCPU (for heavy workloads)

## Deployment Steps

### 1. Configure Wrangler

Ensure you're logged in and have selected your account:

```bash
wrangler whoami
```

### 2. Deploy to Cloudflare

```bash
# Deploy to production
wrangler deploy

# Or deploy to staging
wrangler deploy --env staging
```

### 3. Verify Deployment

Check the deployment status:

```bash
wrangler deployments list
```

## Testing Your Deployment

### Test 1: Worker Health Check

```bash
curl https://bento-cloudflare.YOUR-SUBDOMAIN.workers.dev/health
```

Expected response:
```json
{
  "status": "ok",
  "service": "bento-worker",
  "timestamp": "2025-10-30T12:00:00.000Z"
}
```

### Test 2: Bento Processing Endpoint

```bash
curl -X POST https://bento-cloudflare.YOUR-SUBDOMAIN.workers.dev/process \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello Bento!", "value": 42}'
```

Expected response:
```json
{
  "message": "Hello Bento!",
  "value": 42,
  "processed_by": "bento",
  "timestamp": 1730289600,
  "original_data": {
    "message": "Hello Bento!",
    "value": 42
  }
}
```

### Test 3: Bento Health/Metrics (via Worker)

```bash
# Ping endpoint
curl https://bento-cloudflare.YOUR-SUBDOMAIN.workers.dev/bentows/ping

# Metrics endpoint
curl https://bento-cloudflare.YOUR-SUBDOMAIN.workers.dev/bentows/metrics
```

## Local Development

### Testing Worker Locally

```bash
# Start local development server
wrangler dev

# In another terminal, test locally
curl http://localhost:8787/health
```

**Note:** Local development with containers requires Docker running locally.

### Testing Bento Locally (without Cloudflare)

```bash
# Run Bento directly
docker run --rm -p 8080:8080 \
  -v $(pwd)/bento.yaml:/config.yaml \
  ghcr.io/warpstreamlabs/bento:latest \
  bento -c /config.yaml

# Test in another terminal
curl -X POST http://localhost:8080/process \
  -H "Content-Type: application/json" \
  -d '{"test": "local"}'
```

## Monitoring and Logs

### View Logs

```bash
# Tail live logs
wrangler tail

# Filter for errors only
wrangler tail --status error
```

### Metrics

Access Cloudflare dashboard for detailed metrics:
- https://dash.cloudflare.com/
- Navigate to: Workers & Pages > Your Worker > Metrics

Key metrics to monitor:
- Request count
- Error rate
- CPU time
- Duration (including cold starts)

## Cost Estimation

### Cloudflare Containers Pricing (Workers Paid Plan)

**Base:** $5/month includes:
- 25 GB-hours of RAM
- 375 vCPU minutes
- 200 GB-hours of disk

**Example (Basic instance, 1 GiB RAM):**
- Always-on (24/7): ~720 GB-hours/month = ~$5-10/month
- Intermittent use: Scales to zero, minimal costs

**Billing:** Per 10ms of active runtime

### Monitor Your Usage

```bash
# Check current usage
wrangler deployments list

# View billing in dashboard
# https://dash.cloudflare.com/ > Account > Billing
```

## Troubleshooting

### Issue: "Container failed to start"

**Cause:** Port mismatch or invalid config

**Solution:**
1. Verify `bento.yaml` has `http.address: "0.0.0.0:8080"`
2. Verify `wrangler.toml` has `default_port = 8080`
3. Test Bento config locally first

### Issue: "502 Bad Gateway"

**Cause:** Container is starting (cold start)

**Solution:**
- Wait 2-3 seconds and retry
- Increase `sleep_after` to keep container warm longer
- Consider using a "keep-warm" ping service

### Issue: "429 Too Many Requests"

**Cause:** Exceeded free tier limits

**Solution:**
- Check your usage in Cloudflare dashboard
- Upgrade to paid plan if on free tier
- Review rate limits in your plan

### Issue: "Container exits immediately"

**Cause:** Bento config error

**Solution:**
1. Test config locally:
   ```bash
   docker run --rm -v $(pwd)/bento.yaml:/config.yaml \
     ghcr.io/warpstreamlabs/bento:latest \
     bento -c /config.yaml lint
   ```
2. Check logs: `wrangler tail`
3. Validate YAML syntax

### Issue: Can't access Bento directly

**This is expected!** Containers are private by default.

**Solution:**
- Always access through the Worker URL
- All requests must go through: `https://YOUR-WORKER.workers.dev/...`

## Advanced Configuration

### Custom Ports

If you need to expose multiple ports:

```toml
[[containers]]
binding = "BENTO"
image = "ghcr.io/warpstreamlabs/bento:latest"
default_port = 8080

# Additional ports
[[containers.ports]]
port = 9090
protocol = "HTTP"
```

### Environment Variables

Add environment variables to your container:

```toml
[containers.env]
BENTO_ENV = "production"
LOG_LEVEL = "info"
CUSTOM_VAR = "value"
```

### Multiple Container Instances

Scale with multiple named instances:

```javascript
// In worker.js
const containerIds = ['bento-1', 'bento-2', 'bento-3'];
const selectedId = containerIds[Math.floor(Math.random() * containerIds.length)];
const container = env.BENTO.get(env.BENTO.idFromName(selectedId));
```

### Persistent State with Durable Objects

For stateful processing, combine with Durable Objects:

```javascript
export class BentoProcessor {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request) {
    // State management logic
    const container = await this.env.BENTO.get(this.state.id);
    return await container.fetch(request);
  }
}
```

## Production Checklist

Before going to production:

- [ ] Test locally with realistic payloads
- [ ] Configure appropriate `size` (basic/standard)
- [ ] Set reasonable `sleep_after` timeout
- [ ] Set up monitoring and alerting
- [ ] Configure custom domain (optional)
- [ ] Review Bento config for production settings
- [ ] Test error handling and edge cases
- [ ] Document your specific pipeline logic
- [ ] Set up logging aggregation
- [ ] Load test to understand costs

## Next Steps

1. **Customize Bento Pipeline:** Modify `bento.yaml` for your use case
2. **Add More Endpoints:** Extend `worker.js` with additional routes
3. **Integrate External Services:** Connect Bento to databases, APIs, etc.
4. **Set Up Monitoring:** Use Cloudflare Analytics and logging
5. **Optimize for Cost:** Adjust `sleep_after` and instance `size`

## Resources

- **Cloudflare Containers Docs:** https://developers.cloudflare.com/containers/
- **Bento Documentation:** https://warpstreamlabs.github.io/bento/
- **Wrangler CLI Docs:** https://developers.cloudflare.com/workers/wrangler/
- **Feasibility Report:** See `CLOUDFLARE_DEPLOYMENT_FEASIBILITY.md`

## Support

- **Cloudflare Community:** https://community.cloudflare.com/
- **Bento GitHub:** https://github.com/warpstreamlabs/bento
- **Bento Discord:** Check GitHub README for invite link

---

**Ready to deploy?** Run `wrangler deploy` and start processing! 🚀

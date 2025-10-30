# Feasibility Report: Deploying Bento Docker to Cloudflare Containers

**Date:** October 30, 2025
**Subject:** WarpStream Labs Bento Stream Processor on Cloudflare Containers
**Status:** Technically Possible with Significant Architectural Constraints

---

## Executive Summary

**YES**, it is technically possible to deploy Bento Docker containers to Cloudflare Containers (currently in public beta as of June 2025). Cloudflare now supports running containers in any language, including Go-based applications like Bento.

**HOWEVER**, there are significant architectural constraints and limitations that fundamentally change how Bento would operate compared to traditional container deployments.

---

## 1. Cloudflare Containers Overview (2025)

### Current Status
- **Public Beta:** Launched June 24, 2025
- **Availability:** All paid plans ($5/month minimum)
- **Global Deployment:** 300+ edge locations

### Key Features
- Run Docker images in any programming language
- Scale-to-zero pricing model (billed per 10ms of active runtime)
- Worker-controlled lifecycle
- Global deployment to "Region: Earth"

### Instance Sizes (Beta)
| Type | RAM | vCPU | Use Case |
|------|-----|------|----------|
| Dev | 256 MiB | 1/16 | Development/testing |
| Basic | 1 GiB | 1/4 | Small workloads |
| Standard | 4 GiB | 1/2 | Standard workloads |

### Pricing (Workers Standard Plan)
- **Base:** $5/month includes:
  - 25 GB-hours of RAM
  - 375 vCPU minutes
  - 200 GB-hours of disk
- **Overage:** Pay-as-you-go
  - vCPU: ~$51.84/vCPU/month
  - RAM: ~$6.48/GB/month
- **Storage:** 50 GB total image storage per account

---

## 2. Bento Requirements Analysis

### Docker Image
- **Official Image:** `ghcr.io/warpstreamlabs/bento`
- **Type:** Lightweight Go binary built from scratch
- **Size:** Minimal (multi-stage build)

### Runtime Requirements
- **Port:** Default HTTP server on port 4195
- **Health Endpoints:**
  - `/ping` - Liveness probe (always returns 200)
  - `/ready` - Readiness probe (returns 200 when connected)
- **State:** No disk-persisted state required (in-process transactions)
- **Configuration:** Single YAML config file

### Operational Characteristics
- Stream processing pipeline (input → pipeline → output)
- Connects to external services (Kafka, databases, cloud services, message brokers)
- HTTP server for management, metrics, and health checks
- Metrics export (Statsd, Prometheus, JSON)
- OpenTelemetry tracing support

---

## 3. Compatibility Analysis

### ✅ Compatible Aspects

#### Language & Runtime Support
- **Go Binary:** Fully supported - Cloudflare Containers run any Docker image
- **Resource Requirements:** Bento's lightweight nature fits well within instance limits
- **Stateless Design:** Bento's no-persistent-state model aligns with ephemeral containers

#### Configuration
- **Config File Mounting:** Supported via volume mounts in container definition
- **Environment Variables:** Fully supported

#### Health Checks
- **Readiness Probe:** Container default port blocks until service is listening
- **HTTP Endpoints:** Can expose `/ping` and `/ready` endpoints

### ⚠️ Critical Constraints

#### 1. **No Direct Inbound Connections**
**Limitation:** End-users cannot make direct TCP/UDP requests to containers.

**Impact:**
- Containers are **private by default**
- **All requests MUST go through a Cloudflare Worker**
- Workers proxy requests to container ports
- No direct external access to Bento's HTTP server

**Architecture Change Required:**
```
Traditional:
Client → Bento Container (port 4195)

Cloudflare:
Client → Cloudflare Worker → Container Instance (any port)
```

#### 2. **Worker-Controlled Lifecycle**
**Limitation:** Containers are not standalone services; they're invoked by Workers.

**Impact:**
- Containers are **on-demand** and **ephemeral**
- Cold start latency: ~2-3 seconds (beta)
- Containers sleep after idle period (configurable via `sleepAfter`)
- Not designed for long-running, always-on stream processors

**Implications for Bento:**
- Cannot run as traditional "always-on" stream processor
- Best suited for request/response patterns, not continuous streaming
- May require rearchitecting for event-driven invocations

#### 3. **Networking Model**
**Limitation:** Container networking is Worker-mediated.

**Impact:**
- **HTTP/WebSocket only** for Worker-to-Container communication
- Default port (e.g., 8080, 4195) must be declared
- No direct TCP/UDP socket access for end users
- TLS is handled by Cloudflare network (no need for certs in container)

**Bento Connections:**
- **Outbound:** Bento can still connect to external services (Kafka, databases)
- **Inbound:** Must be proxied through Worker

#### 4. **Scale Limits (Beta)**
- Max 40 GB RAM / 40 vCPU per account
- No built-in autoscaling or load balancing (manual scaling in code)
- No support for persistent containers

---

## 4. Deployment Patterns

### Pattern 1: Request-Driven Processing (RECOMMENDED)

**Architecture:**
```javascript
// Worker handles HTTP requests and invokes container
export default {
  async fetch(request, env) {
    const container = await env.MY_BENTO.get("instance-1");
    const response = await container.fetch(request);
    return response;
  }
}
```

**Bento Use Case:**
- HTTP-triggered data transformations
- API-driven data pipelines
- On-demand stream processing jobs

**Pros:**
- Aligns with Cloudflare's programming model
- Scale-to-zero cost efficiency
- Global edge deployment

**Cons:**
- Not suitable for continuous streaming
- Cold start latency on first request
- Requires Worker proxy layer

### Pattern 2: Event-Driven Processing

**Architecture:**
- Use Cloudflare Queues or Durable Objects to trigger container
- Worker receives events and invokes Bento container
- Bento processes batch of messages

**Bento Use Case:**
- Batch message processing
- Queue-based transformations
- Periodic data jobs

**Pros:**
- Better suited for intermittent workloads
- Can process batches efficiently

**Cons:**
- Still not continuous streaming
- Additional complexity with queue management

### Pattern 3: Durable Object + Container (ADVANCED)

**Architecture:**
- Each Durable Object manages a container instance
- Provides state management and coordination
- Container processes data streams

**Bento Use Case:**
- Per-tenant stream processing
- Stateful transformations
- WebSocket-based streaming

**Pros:**
- Closest to traditional streaming model
- State management via Durable Objects
- Long-lived connections possible

**Cons:**
- Complex architecture
- Higher costs (Durable Object + Container)
- Still limited by container lifecycle

---

## 5. Limitations for Stream Processing

### Critical Limitations

1. **Not Designed for Continuous Streams**
   - Containers are ephemeral and Worker-invoked
   - Sleep after idle period
   - Best for request/response, not 24/7 streaming

2. **No Always-On Guarantee**
   - Unlike Kubernetes or ECS, containers aren't "always running"
   - Cold starts introduce latency

3. **Network Architecture**
   - Cannot accept direct connections from Kafka, message brokers, etc.
   - All inbound traffic must be Worker-mediated

4. **Autoscaling Limitations (Beta)**
   - No built-in autoscaling
   - Manual scaling via code
   - Limited to beta scale caps

### What Bento CAN Do on Cloudflare

✅ **HTTP-triggered transformations**
✅ **API endpoints for data processing**
✅ **Batch job processing**
✅ **On-demand pipeline execution**
✅ **Edge data transformations**

### What Bento CANNOT Do (Without Workarounds)

❌ **Continuous Kafka consumption** (no direct inbound)
❌ **Always-on stream processing** (ephemeral lifecycle)
❌ **Direct message broker connections** (Worker proxy required)
❌ **Long-running stateful streams** (scale-to-zero model)

---

## 6. Practical Deployment Example

### Minimal Deployment Setup

**1. Dockerfile (if not using official image):**
```dockerfile
FROM ghcr.io/warpstreamlabs/bento:latest
COPY bento.yaml /config.yaml
EXPOSE 8080
CMD ["bento", "-c", "/config.yaml"]
```

**2. Wrangler Configuration (wrangler.toml):**
```toml
name = "bento-processor"
main = "src/worker.js"
compatibility_date = "2025-10-30"

[[containers]]
binding = "BENTO"
image = "ghcr.io/warpstreamlabs/bento:latest"
default_port = 8080
```

**3. Worker Proxy (src/worker.js):**
```javascript
export default {
  async fetch(request, env) {
    // Get or create container instance
    const container = await env.BENTO.get("processor-1");

    // Forward request to Bento container
    const response = await container.fetch(request);

    return response;
  }
}
```

**4. Bento Config (bento.yaml):**
```yaml
http:
  address: "0.0.0.0:8080"

input:
  http_server:
    path: /process

pipeline:
  processors:
    - bloblang: |
        root = this
        root.processed = true

output:
  http_client:
    url: https://api.example.com/webhook
    verb: POST
```

**5. Deploy:**
```bash
docker build -t bento-processor .
wrangler deploy
```

---

## 7. Cost Comparison

### Cloudflare Containers
- **Base:** $5/month (25 GB-hours RAM, 375 vCPU min)
- **Example:** 1 GB container running 24/7:
  - RAM: 720 GB-hours/month (need to buy ~695 additional)
  - Cost: ~$5 + $4.50 = **~$9.50/month** (approximate)

### Traditional Alternatives
- **AWS Fargate:** ~$30-50/month (similar specs, always-on)
- **Google Cloud Run:** ~$20-40/month (request-based)
- **Kubernetes (managed):** $70-100+/month (cluster + node costs)

**Note:** Cloudflare is cost-effective for intermittent workloads due to scale-to-zero, but can be expensive for always-on services.

---

## 8. Recommendations

### ✅ Deploy Bento on Cloudflare IF:

1. **Request/Response Pattern**
   - Your use case is HTTP API-driven
   - Processing happens on-demand, not continuously

2. **Edge Processing Benefits**
   - You need global distribution
   - Low-latency edge transformations are valuable

3. **Intermittent Workloads**
   - Sporadic processing jobs
   - Scale-to-zero cost savings matter

4. **Simple Pipelines**
   - Input: HTTP → Process → Output: HTTP/Webhook
   - Not complex multi-source streaming

### ❌ DO NOT Deploy Bento on Cloudflare IF:

1. **Continuous Stream Processing**
   - 24/7 Kafka consumer
   - Always-on message broker connections
   - Real-time data pipelines

2. **Direct Network Access Required**
   - Need to accept TCP connections
   - Direct database streaming
   - Custom protocol requirements

3. **Complex State Management**
   - Long-running stateful streams
   - Multi-hour processing jobs
   - Large in-memory state

4. **Traditional Microservice**
   - You want a standard containerized service
   - No need for edge distribution

### Alternative Cloudflare-Compatible Architectures

1. **Hybrid Model:**
   - Run Bento on traditional container platform (ECS, GKE)
   - Use Cloudflare Workers for edge routing/caching
   - Best of both worlds

2. **Serverless Functions:**
   - Rewrite Bento logic as Cloudflare Workers
   - Native Cloudflare integration
   - No container overhead

3. **Queue-Based Processing:**
   - Cloudflare Queues → Bento container invocations
   - Batch processing model
   - Better fit for Cloudflare's architecture

---

## 9. Proof of Concept Steps

To test Bento on Cloudflare Containers:

### Phase 1: Simple HTTP Echo (1-2 hours)
1. Deploy official Bento image
2. Configure simple HTTP input → output
3. Test via Worker proxy
4. Measure cold start times

### Phase 2: Data Transformation (2-4 hours)
1. Add Bloblang transformation pipeline
2. Test with realistic payloads
3. Monitor performance and costs

### Phase 3: External Integration (4-8 hours)
1. Connect to external service (e.g., webhook output)
2. Test error handling and retries
3. Evaluate networking constraints

### Phase 4: Production Readiness (1-2 days)
1. Implement monitoring (metrics, logs)
2. Load testing
3. Cost analysis with production volumes
4. Document operational procedures

---

## 10. Conclusion

**VERDICT: Technically Feasible, Architecturally Constrained**

Deploying Bento Docker to Cloudflare Containers is **possible** thanks to Cloudflare's June 2025 container support. However, it requires **significant architectural adaptation**:

### Key Takeaways:

1. **Yes, it runs:** Bento's Go binary will execute in Cloudflare Containers
2. **No direct access:** All traffic must flow through Workers
3. **Not for continuous streaming:** Best for request-driven, event-based processing
4. **Cost-effective for intermittent:** Scale-to-zero great for sporadic workloads
5. **Edge benefits:** Global distribution if that matches your use case

### Recommended Next Steps:

1. **Define Your Use Case Precisely:**
   - Is it request/response or continuous streaming?
   - What are your connectivity requirements?

2. **Build POC:**
   - Start with simple HTTP echo test
   - Validate networking model works for your needs

3. **Evaluate Alternatives:**
   - Consider if Cloudflare Workers (without containers) could work
   - Compare with traditional container platforms

4. **Decision Point:**
   - If request-driven: Cloudflare Containers could be excellent
   - If continuous streaming: Traditional platforms (ECS, GKE, K8s) are better suited

---

## 11. Additional Resources

- **Cloudflare Containers Docs:** https://developers.cloudflare.com/containers/
- **Bento Documentation:** https://warpstreamlabs.github.io/bento/
- **Bento Docker Image:** https://github.com/warpstreamlabs/bento
- **Cloudflare Containers Blog:** https://blog.cloudflare.com/containers-are-available-in-public-beta-for-simple-global-and-programmable/
- **Pricing Details:** https://developers.cloudflare.com/containers/pricing/

---

**Report Prepared For:** Bento-test- Repository
**Technology Stack:** WarpStream Labs Bento + Cloudflare Containers
**Recommendation:** Feasible for specific use cases (HTTP-driven, edge processing) but not recommended for traditional stream processing workloads.

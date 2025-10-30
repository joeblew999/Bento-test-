#!/bin/bash
# Test script for Bento deployment
# Works for both Cloudflare and Fly.io deployments

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLOUDFLARE_URL="${CLOUDFLARE_URL:-https://bento-cloudflare.YOUR-SUBDOMAIN.workers.dev}"
FLY_URL="${FLY_URL:-https://bento-fly.fly.dev}"

# Choose which deployment to test
DEPLOYMENT="${1:-cloudflare}"

if [ "$DEPLOYMENT" = "cloudflare" ]; then
    BASE_URL="$CLOUDFLARE_URL"
    echo -e "${YELLOW}Testing Cloudflare deployment at: $BASE_URL${NC}"
elif [ "$DEPLOYMENT" = "fly" ]; then
    BASE_URL="$FLY_URL"
    echo -e "${YELLOW}Testing Fly.io deployment at: $BASE_URL${NC}"
else
    echo -e "${RED}Usage: $0 [cloudflare|fly]${NC}"
    exit 1
fi

echo ""

# Test 1: Worker/App Health Check (Cloudflare only)
if [ "$DEPLOYMENT" = "cloudflare" ]; then
    echo -e "${YELLOW}Test 1: Worker Health Check${NC}"
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/health")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Health check passed${NC}"
        echo "$body" | jq .
    else
        echo -e "${RED}✗ Health check failed (HTTP $http_code)${NC}"
        echo "$body"
    fi
    echo ""
fi

# Test 2: Bento Ping Endpoint
echo -e "${YELLOW}Test 2: Bento Ping Endpoint${NC}"
if [ "$DEPLOYMENT" = "cloudflare" ]; then
    ping_url="$BASE_URL/bentows/ping"
else
    ping_url="$BASE_URL/ping"
fi

response=$(curl -s -w "\n%{http_code}" "$ping_url")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Bento ping successful${NC}"
    echo "$body"
else
    echo -e "${RED}✗ Bento ping failed (HTTP $http_code)${NC}"
    echo "$body"
fi
echo ""

# Test 3: Bento Ready Endpoint
echo -e "${YELLOW}Test 3: Bento Ready Endpoint${NC}"
if [ "$DEPLOYMENT" = "cloudflare" ]; then
    ready_url="$BASE_URL/bentows/ready"
else
    ready_url="$BASE_URL/ready"
fi

response=$(curl -s -w "\n%{http_code}" "$ready_url")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Bento is ready${NC}"
    echo "$body"
else
    echo -e "${RED}✗ Bento not ready (HTTP $http_code)${NC}"
    echo "$body"
fi
echo ""

# Test 4: Process Simple JSON
echo -e "${YELLOW}Test 4: Process Simple JSON${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/process" \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello Bento!", "value": 42}')

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ JSON processing successful${NC}"
    echo "$body" | jq .
else
    echo -e "${RED}✗ JSON processing failed (HTTP $http_code)${NC}"
    echo "$body"
fi
echo ""

# Test 5: Process Complex Nested JSON
echo -e "${YELLOW}Test 5: Process Complex Nested JSON${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/process" \
    -H "Content-Type: application/json" \
    -d '{
        "user": {
            "id": 123,
            "name": "John Doe",
            "email": "john@example.com"
        },
        "action": "purchase",
        "items": [
            {"id": 1, "name": "Widget", "price": 9.99},
            {"id": 2, "name": "Gadget", "price": 19.99}
        ],
        "timestamp": "2025-10-30T12:00:00Z"
    }')

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Complex JSON processing successful${NC}"
    echo "$body" | jq .
else
    echo -e "${RED}✗ Complex JSON processing failed (HTTP $http_code)${NC}"
    echo "$body"
fi
echo ""

# Test 6: GET Request (should also work)
echo -e "${YELLOW}Test 6: GET Request${NC}"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/process")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ GET request successful${NC}"
    echo "$body" | jq .
else
    echo -e "${RED}✗ GET request failed (HTTP $http_code)${NC}"
    echo "$body"
fi
echo ""

# Test 7: Metrics Endpoint
echo -e "${YELLOW}Test 7: Prometheus Metrics${NC}"
if [ "$DEPLOYMENT" = "cloudflare" ]; then
    metrics_url="$BASE_URL/bentows/metrics"
else
    metrics_url="$BASE_URL/metrics"
fi

response=$(curl -s -w "\n%{http_code}" "$metrics_url")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Metrics endpoint accessible${NC}"
    echo "$body" | head -n 20
    echo "... (truncated)"
else
    echo -e "${RED}✗ Metrics endpoint failed (HTTP $http_code)${NC}"
    echo "$body"
fi
echo ""

# Summary
echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}================================${NC}"
echo -e "Deployment: ${GREEN}$DEPLOYMENT${NC}"
echo -e "Base URL: ${GREEN}$BASE_URL${NC}"
echo ""
echo "All tests completed!"
echo ""
echo "To test the other deployment, run:"
if [ "$DEPLOYMENT" = "cloudflare" ]; then
    echo "  $0 fly"
else
    echo "  $0 cloudflare"
fi

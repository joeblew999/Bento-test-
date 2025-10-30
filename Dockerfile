# Dockerfile for Bento on Cloudflare Containers
# This is optional - you can also use the official image directly

FROM ghcr.io/warpstreamlabs/bento:latest

# Copy the Bento configuration
COPY bento.yaml /config.yaml

# Expose the port Bento will listen on
EXPOSE 8080

# Health check (optional but recommended)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ping || exit 1

# Start Bento with the config
CMD ["bento", "-c", "/config.yaml"]

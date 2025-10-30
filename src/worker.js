/**
 * Cloudflare Worker that proxies requests to Bento container
 *
 * This worker acts as the entry point for all requests to Bento.
 * Since Cloudflare Containers cannot be accessed directly, this worker
 * forwards incoming HTTP requests to the Bento container instance.
 */

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Health check endpoint (doesn't hit container)
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({
        status: 'ok',
        service: 'bento-worker',
        timestamp: new Date().toISOString()
      }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    try {
      // Get or create a container instance
      // Using a fixed ID for simplicity - in production you might want dynamic IDs
      const containerId = env.BENTO.idFromName('bento-processor-1');
      const container = env.BENTO.get(containerId);

      // Forward the request to the Bento container
      // The container will receive the request on port 8080 (configured in wrangler.toml)
      const response = await container.fetch(request);

      // Add custom headers to identify it came through our worker
      const modifiedResponse = new Response(response.body, response);
      modifiedResponse.headers.set('X-Processed-By', 'Cloudflare-Bento-Worker');
      modifiedResponse.headers.set('X-Container-Id', containerId.toString());

      return modifiedResponse;

    } catch (error) {
      // Error handling
      console.error('Error forwarding to Bento container:', error);

      return new Response(JSON.stringify({
        error: 'Failed to process request',
        message: error.message,
        timestamp: new Date().toISOString()
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }
};

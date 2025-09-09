# Light RAG in docker container

## Caddy

```bash
# Validate configuration
docker run --rm \
    -v "$(pwd)/etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
    lucaslorentz/caddy-docker-proxy:latest \
    validate \
    --config /etc/caddy/Caddyfile

# Examine logs
docker compose logs proxy

# Test URL
curl -s http://localhost/debug
curl -s http://localhost/health
curl -s http://localhost/
```
---
trigger: always_on
---

# Major purpose

Create minimalistic configuration of LightRAG with LLM Chat integration. That should allow to solve:

1. Production scalable solution, that can be executed locally and with minimalistic changes be scaled on cloud platforms (Azure, AWS, GoogleCloud, etc)
2. Use docker-compose (or docker swarm) for self-hosting execution on smallest scale. Play locally before you are ready for scaling.
3. Allows to test RAG and it capabilities with different LLM providers (OpenAI, Ollama, OpenRouter.ai)
4. Setup security, so we have protection of our data on all levels (storage, communication, processing)
5. Make data transfarable from local to cloud solutions (initial RAG fill can be executed on self-hosted local setup and later imported/exported to cloud hosted instance)
6. Lightweight solution (minimalistic resource usage, but keep performance on high-end side)

## Technological Stack

- MISE - environemnt management, secrtes injection, required tools installation/setup (file: mise.toml, ref: https://mise.jdx.dev/)
- Storages:
  - Key/Value: Redis (ref: https://redis.io/)
  - Graph Database: Memgraph (ref: https://memgraph.com/)
  - Embedding Vectors Database: Qdrant (ref: https://qdrant.tech/)
- Monitoring: will-moss/isaiah (also known as lazydocker with web ui. ref: https://github.com/will-moss/isaiah)
- UI:
  - Memgraph Lab: https://memgraph.com/lab
  - LobeChat: https://github.com/lobehub/lobe-chat
  - (Optional). Redis Insight: https://hub.docker.com/r/redis/redisinsight
- Self Signed Certificates:
  - Mkcert - used for creating a wildcard ssl certificates (dir: docker/ssl)
- Caddy reverse proxy - used for publishing each service in own subdomain
  - hostctl - used for managing sub-domains publishing
  - Docker confiurations via labels - https://github.com/lucaslorentz/caddy-docker-proxy

## Alternatives

- Neo4J as graph database
- Valkey instead of Redis
- https://github.com/qishibo/AnotherRedisDesktopManager/ instead of Redis Insight

## Takeaways / Outcomes

1. Documentation on how to run the solution locally
2. Documentation how to verify each service (security, api, data, logs)
3. Documentation how to configure services integration (setup, verify, troubleshooting)
4. Verification Script, for automated verification (file: bin/verify.configuration.sh)
5. Documentation how to import/export data
6. Documentation how to verify LLM answers quality (manual or automation)
7. Diagnostics scripts (file: bin/diag.wsl2.sh)

## LLM Response Standards

1. Reply should contain the description of changes (midium size, 1 paragraph maximum)
2. Reply should contain the way to verify the changes (bash script expected, and if it required WSL hosting machine configuration expected CMD code with fallback to powershell)
3. Expected that solution is executed/hosted on Windows 11 Host machine with docker engine installed on Ubuntu WSL2 (default: Docker Desktop for Business, fallback: No Docker Desktop is available - only lazydocker and docker cli)
4. Give a preference to SCOOP tool if required installation of something on Windows Host side
5. Give a preference to BREW and MISE if requried installation of something on Ubuntu side (WSL2)
6. Any change to the project configuration should be verifiable (or tracked in the documentation, so we have a clear business purpose of such change)
7. Changes should provided with potential git commit message that summarise the changes in a short "conventional commit message" (ref: https://www.conventionalcommits.org/en/v1.0.0/)
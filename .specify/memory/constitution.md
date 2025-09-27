<!--
Sync Impact Report - Constitution Update v1.0.0

Version change: 0.0.0 → 1.0.0 (MAJOR - Initial project constitution with comprehensive principles)
Principles added:
  - I. Production-First Architecture (NEW)
  - II. Multi-Provider LLM Integration (NEW)
  - III. Security-First Design (NEW)
  - IV. Data Portability & Transferability (NEW)
  - V. Lightweight Performance Optimization (NEW)
  - VI. Comprehensive Testing & Verification (NEW)
  - VII. Developer Experience Excellence (NEW)

Sections added:
  - Infrastructure Standards (NEW)
  - Development Workflow (NEW)
  - Governance (NEW)

Templates requiring updates:
  - ✅ .specify/templates/plan-template.md - May need constitution alignment
  - ✅ .specify/templates/spec-template.md - Should reference new principles
  - ✅ .specify/templates/tasks-template.md - Should include principle-driven tasks
  - ⚠️ .specify/templates/commands/*.md - Review for principle alignment needed

Follow-up TODOs:
  - Validate constitution compliance across all templates
  - Update existing documentation to reference new principles
  - Create constitution compliance checklist for new features
-->

# LightRAG Infrastructure Constitution

## Core Principles

### I. Production-First Architecture
Every component MUST be designed for production scalability from day one. All services MUST support horizontal scaling across cloud platforms (Azure, AWS, Google Cloud) while maintaining the ability to run locally. Containerization with Docker Compose MUST be the primary deployment method, ensuring consistent behavior across all environments.

### II. Multi-Provider LLM Integration
The system MUST support multiple LLM providers (OpenAI, Ollama, OpenRouter.ai) through a unified API interface. Provider switching MUST be configuration-only with no code changes required. All providers MUST support the same feature set including embeddings, chat completion, and streaming responses.

### III. Security-First Design
Security MUST be implemented at all levels: storage (Redis, Memgraph, Qdrant), communication (SSL/TLS with self-signed certificates), processing (API key management), and access control (CORS policies, authentication). Self-signed certificates using mkcert MUST be the default for development with clear paths to production certificates.

### IV. Data Portability & Transferability
All data stores (Redis KV, Memgraph graphs, Qdrant vectors) MUST support import/export operations. Initial RAG population MUST be executable on local/self-hosted setups and transferable to cloud instances. Data formats MUST be standardized and versioned.

### V. Lightweight Performance Optimization
Resource usage MUST be minimized while maintaining high performance. Docker resource limits MUST be enforced with clear tiers (small/medium/large). Performance monitoring and benchmarking MUST be built-in with automated validation scripts.

### VI. Comprehensive Testing & Verification
Test-Driven Development (TDD) MUST be mandatory for all components. GIVEN/WHEN/THEN testing patterns MUST be used throughout. Automated verification scripts MUST validate security, connectivity, data integrity, and performance across all services.

### VII. Developer Experience Excellence
Environment management MUST use Mise for tool installation and secret management. DNS configuration MUST use hostctl for cross-platform support. Documentation MUST include verification scripts for each configuration step with Windows/WSL2/Linux compatibility.

## Infrastructure Standards

### Technology Stack Requirements
- **Environment Management**: Mise (mise.jdx.dev) for tool installation and secret injection
- **Container Orchestration**: Docker Compose with Docker Swarm compatibility
- **Key/Value Storage**: Redis with authentication and persistence
- **Graph Database**: Memgraph with MAGE extension support
- **Vector Database**: Qdrant with snapshot and backup capabilities
- **Reverse Proxy**: Caddy with Docker proxy integration and automatic SSL
- **Monitoring**: Isaiah (lazydocker web UI) for container fleet management
- **UI Components**: LobeChat for chat interface, Memgraph Lab for graph visualization

### Performance Standards
- **Memory Usage**: Must operate within allocated Docker limits (1G/4G/8G tiers)
- **Response Times**: LLM API calls must complete within 120 seconds
- **Concurrent Operations**: Must support multiple parallel document insertions
- **Resource Efficiency**: Must minimize CPU and memory footprint while maintaining performance

### Security Standards
- **Certificate Management**: Self-signed certificates using mkcert with Windows CA integration
- **Secret Management**: SOPS with Age encryption for all sensitive configuration
- **Network Security**: Internal backend network isolation with frontend exposure only
- **Access Control**: Basic authentication for monitoring interfaces

## Development Workflow

### Quality Gates
- All code changes MUST pass automated verification scripts
- Security checks MUST pass before deployment
- Performance benchmarks MUST meet established criteria
- Documentation MUST be updated with configuration changes

### Review Process
- All infrastructure changes MUST include verification commands
- Performance impact MUST be documented and validated
- Security implications MUST be assessed for all changes
- Cross-platform compatibility MUST be tested (Windows/WSL2/Linux)

### Deployment Standards
- Docker images MUST be tagged with semantic versions
- Environment variables MUST be documented and validated
- Health checks MUST be implemented for all services
- Rollback procedures MUST be documented

## Governance

This constitution establishes the foundational principles for the LightRAG infrastructure project. All development, deployment, and operational decisions must align with these principles.

### Amendment Process
- Constitution changes require documentation of rationale and impact
- All amendments must include migration instructions
- Version bumps follow semantic versioning rules
- Changes must be validated across all supported platforms

### Compliance Requirements
- All pull requests must verify constitution compliance
- Automated checks must validate principle adherence
- Documentation must reference relevant constitutional principles
- Architecture decisions must be justifiable against constitutional standards

**Version**: 1.0.0 | **Ratified**: 2025-09-27 | **Last Amended**: 2025-09-27
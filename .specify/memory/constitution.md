<!--
Sync Impact Report:
- Version change: template → 1.0.0
- Initial constitution creation for LightRAG project
- Added sections: Container-First Architecture, Multi-LLM Provider Support, Test-Driven Development, Security-First Design, Lightweight & Performance
- Templates requiring updates: ✅ plan-template.md (already references constitution)
- Follow-up TODOs: None - all placeholders filled
-->

# LightRAG Constitution

## Core Principles

### I. Container-First Architecture
All components MUST be containerized using Docker and orchestrated via docker-compose for local development. The solution MUST be designed for seamless scaling from local docker-compose to cloud platforms (Azure, AWS, Google Cloud) with minimal configuration changes. Self-hosting on the smallest scale is the primary deployment target, with cloud scaling as a secondary consideration.

**Rationale**: Ensures consistent environments across development, testing, and production while maintaining portability and scalability options.

### II. Multi-LLM Provider Support
The system MUST support multiple LLM providers including OpenAI, Ollama, and OpenRouter.ai through a unified interface. Provider switching MUST be configurable without code changes, using environment variables or configuration files managed by MISE.

**Rationale**: Provides flexibility in LLM selection based on cost, performance, privacy, and availability requirements while avoiding vendor lock-in.

### III. Test-Driven Development (NON-NEGOTIABLE)
TDD is mandatory following the red-green-refactor cycle. All tests MUST use GIVEN/WHEN/THEN structure with clear comments explaining business purpose and test scenarios. Each test MUST be tagged with clear messages describing the test purpose. Use `AND: {purpose}` for additional steps within test sections.

**Rationale**: Ensures code quality, maintainability, and clear documentation of business requirements through executable specifications.

### IV. Security-First Design
Data protection MUST be implemented at all levels: storage (encrypted at rest), communication (TLS/SSL for all connections), and processing (secure secrets management via MISE). Self-signed certificates using mkcert for local development, with proper certificate management for production deployments.

**Rationale**: Protects sensitive data and maintains trust in the RAG system, especially important for enterprise and production deployments.

### V. Lightweight & Performance
The solution MUST minimize resource usage while maintaining high-end performance. All services MUST be optimized for minimal memory and CPU footprint. Performance monitoring and benchmarking MUST be integrated to ensure efficiency targets are met.

**Rationale**: Enables deployment on resource-constrained environments while ensuring scalability and cost-effectiveness.

## Technology Stack Requirements

**Environment Management**: MISE for environment management, secrets injection, and required tools installation/setup (mise.toml)

**Storage Stack**:
- Key/Value: Redis (with Valkey as alternative)
- Graph Database: Memgraph (with Neo4J as alternative) 
- Embedding Vectors: Qdrant

**Infrastructure**:
- Reverse Proxy: Caddy for subdomain routing and SSL termination
- Monitoring: will-moss/isaiah (lazydocker with web UI)
- Host Management: hostctl for subdomain management

**User Interfaces**:
- Chat Interface: LobeChat
- Graph Visualization: Memgraph Lab
- Optional: Redis Insight for Redis management

**Development Tools**:
- Preferred Package Managers: SCOOP (Windows host), BREW and MISE (Ubuntu WSL2)
- Certificate Management: mkcert for wildcard SSL certificates
- Target Platform: Windows 11 host with Docker on Ubuntu WSL2

## Development & Deployment Standards

**Documentation Requirements**:
- Local execution documentation with step-by-step setup
- Service verification procedures (security, API, data, logs)
- Integration configuration guides with troubleshooting
- Data import/export procedures
- LLM answer quality verification methods

**Verification & Diagnostics**:
- Automated verification script: `bin/verify.configuration.sh`
- WSL2 diagnostics script: `bin/diag.wsl2.sh`
- All configuration changes MUST be verifiable and documented

**Response Standards**:
- All changes MUST include description (max 1 paragraph)
- Verification procedures MUST be provided as bash scripts
- Windows host configuration MUST include CMD/PowerShell fallbacks
- All changes MUST include conventional commit messages
- Business purpose MUST be documented for all configuration changes

**Data Portability**:
- RAG data MUST be transferable between local and cloud deployments
- Initial RAG population can be performed locally and exported to cloud instances
- Import/export procedures MUST be documented and automated where possible

## Governance

This constitution supersedes all other development practices and guidelines. All pull requests and code reviews MUST verify compliance with these principles. Any deviation from constitutional principles MUST be explicitly justified and documented in the Complexity Tracking section of implementation plans.

**Amendment Process**: Constitutional changes require documentation of rationale, impact assessment, and migration plan. Version increments follow semantic versioning: MAJOR for backward-incompatible changes, MINOR for new principles/sections, PATCH for clarifications.

**Compliance Review**: All development artifacts (specs, plans, tasks, implementations) MUST demonstrate adherence to constitutional principles. Use this constitution as the primary reference for all development decisions.

**Version**: 1.0.0 | **Ratified**: 2025-09-22 | **Last Amended**: 2025-09-22
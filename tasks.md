# Tasks: Add LobeChat to Existing LightRAG Stack

**Input**: Design documents from project root
**Prerequisites**: plan.md (available), docker-compose.yaml (available)

## 🎯 **CURRENT STATUS SUMMARY**
- ⚠️ **Setup Phase (T001-T005b)**: MOSTLY DONE - **WSL2 networking issue detected**
- 🚨 **CRITICAL**: Current `.etchosts` uses `127.0.0.1` but WSL2 needs `192.168.1.103` (Windows LAN IP)
- ⚠️ **Tests Phase (T006-T010)**: PARTIALLY DONE - Basic tests exist, need validation
- ✅ **Environment (T011-T012)**: COMPLETED - Configuration files ready
- 🔧 **NEXT PRIORITY**: Fix WSL2 networking (T005b) before deployment
- 🚀 **THEN DEPLOY**: T013 `docker compose up -d lobechat`
- 📋 **Remaining Work**: Fix networking + deploy service + validate integration + polish tasks

## Execution Flow (main)
```
1. Load plan.md from project root
   → Extract: Docker services, environment setup, verification steps
   → Validate: Solution is partly implemented but not reflected in the documentation, review what is actually implemented and what is not
2. Load docker-compose.yaml: 
   → Extract: service dependencies, network configuration, volumes
3. Generate tasks by category:
   → Setup: environment files, directories, SSL certificates
   → Tests: service health checks, integration tests, API tests
   → Core: LobeChat service deployment, configuration
   → Integration: service connectivity, proxy configuration
   → Polish: performance tests, documentation updates
4. Apply TDD approach with failing tests first
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Phase 3.1: Setup ⚠️ **NEEDS WSL2 FIX**
- [x] T001 Create required directory structure: `./docker/data/lobechat` with proper permissions ✅ **DONE**
- [x] T002 [P] Verify SSL certificates exist in `./docker/ssl/` (dev.localhost.pem, dev.localhost-key.pem) ✅ **DONE**
- [x] T003 [P] Update `.gitignore` to exclude `docker/data/lobechat/*` runtime data ✅ **DONE**
- [x] T004 [P] Update `mise.toml` setup task to include lobechat directory creation ✅ **DONE**
- [x] T005 [P] Update `.etchosts` with lobechat.dev.localhost subdomain entry ✅ **DONE**
- [ ] T005b **NEW** Generate WSL2-specific `.etchosts.windows` using Windows LAN IP (192.168.1.103) from `bin/diag.wsl2.sh` 🚨 **CRITICAL FOR WSL2**
  Instead of running `bin/diag.wsl2.sh` (which is slow), do only one required call to capture the required IP address.
  Make script for generating `.etchosts.windows` file in `bin/make.etchosts.windows.sh`.
  ```bash
  # GIVEN: WSL2 environment detected with Windows LAN IP 192.168.1.103
  # WHEN: Creating .etchosts file for WSL2 networking
  # THEN: All dev.localhost subdomains should point to Windows host IP
  # 
  # Current (incorrect): 127.0.0.1 dev.localhost
  # Required (WSL2):     192.168.1.103 dev.localhost
  #
  # Use bin/diag.wsl2.sh to detect Windows LAN IP automatically
  # Create/Update .etchosts.windows with all service subdomains using correct IP
  ```

## Phase 3.2: Tests First (TDD) ⚠️ **PARTIALLY IMPLEMENTED**
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [x] T006 [P] Service health test for LobeChat container in `bin/test.suite.sh` ✅ **DONE** (line 193)
- [x] T007 [P] Integration test LobeChat → LightRAG connectivity in `bin/test.suite.sh` ✅ **DONE** (line 250)
- [ ] T008 [P] Integration test LobeChat → Redis connectivity in `bin/test.suite.sh` ⚠️ **NEEDS VALIDATION**
- [ ] T009 [P] API endpoint test for LobeChat web interface in `bin/test.suite.sh` ⚠️ **NEEDS VALIDATION**
- [ ] T010 [P] SSL/TLS test for https://lobechat.dev.localhost in `bin/test.suite.sh` ⚠️ **NEEDS VALIDATION**

## Phase 3.3: Core Implementation ⚠️ **READY FOR DEPLOYMENT**
- [x] T011 Verify `.env.lobechat` configuration matches plan.md requirements ✅ **DONE**
- [x] T012 Update LightRAG whitelist paths in `.env.lightrag` to include `/v1/*` ✅ **DONE**
- [ ] T013 Deploy LobeChat service using `docker compose up -d lobechat` 🚀 **READY TO EXECUTE**
- [ ] T014 Verify LobeChat container startup and health check status
- [ ] T015 Test internal service connectivity (LobeChat → RAG, Redis, Proxy)

## Phase 3.4: Integration ✅ **MOSTLY CONFIGURED**
- [x] T016 Configure Caddy reverse proxy labels for LobeChat service ✅ **DONE** (docker-compose.yaml lines 297-299)
- [ ] T017 Test HTTPS access via https://lobechat.dev.localhost ⚠️ **NEEDS SERVICE RUNNING**
- [ ] T018 Verify LobeChat can access LightRAG API endpoints ⚠️ **NEEDS SERVICE RUNNING**
- [ ] T019 Test Redis database separation (DB 2 and 3 for LobeChat) ⚠️ **NEEDS SERVICE RUNNING**
- [ ] T020 Validate OpenAI-compatible API proxy through LightRAG ⚠️ **NEEDS SERVICE RUNNING**

## Phase 3.5: Polish ✅ **PARTIALLY IMPLEMENTED**
- [x] T021 [P] Update `bin/verify.configuration.sh` to include LobeChat service checks ✅ **DONE** (check_lobechat_ui function exists)
- [ ] T022 [P] Performance test: LobeChat response times (<2s for UI, <5s for API) ⚠️ **NEEDS IMPLEMENTATION**
- [ ] T023 [P] Update project README.md with LobeChat access instructions ⚠️ **NEEDS IMPLEMENTATION**
- [ ] T024 [P] Create functional test scenarios for LightRAG query modes (/global, /local, /hybrid) ⚠️ **NEEDS IMPLEMENTATION**
- [ ] T025 Run complete verification suite and document any issues ⚠️ **NEEDS SERVICE RUNNING**

## Dependencies ⚠️ **UPDATED WITH WSL2 CRITICAL FIX**
- ⚠️ Setup tasks (T001-T005) **COMPLETED** but T005b **CRITICAL FOR WSL2**
- 🚨 **BLOCKING**: T005b (WSL2 networking) must complete before T013 (deployment)
- ⚠️ Tests (T006-T010) **PARTIALLY DONE** - T006-T007 exist, T008-T010 need validation
- ✅ T011-T012 **COMPLETED** (environment ready)
- 🔧 **NEXT**: T005b (fix WSL2 networking) then T013 (deploy service)
- T005b before T013 (correct networking before deployment)
- T013-T014 before T015 (deployment before connectivity)
- T015 before integration tasks (T016-T020)
- Integration (T016-T020) before polish (T021-T025)

## Parallel Example
```bash
# Launch T006-T010 together (test creation):
Task: "Service health test for LobeChat container in bin/test.suite.sh"
Task: "Integration test LobeChat → LightRAG connectivity in bin/test.suite.sh"
Task: "Integration test LobeChat → Redis connectivity in bin/test.suite.sh"
Task: "API endpoint test for LobeChat web interface in bin/test.suite.sh"
Task: "SSL/TLS test for https://lobechat.dev.localhost in bin/test.suite.sh"

# Launch T002-T005 together (setup files):
Task: "Verify SSL certificates exist in ./docker/ssl/"
Task: "Update .gitignore to exclude docker/data/lobechat/*"
Task: "Update mise.toml setup task to include lobechat directory creation"
Task: "Update .etchosts with lobechat.dev.localhost subdomain entry"
```

## Notes
- [P] tasks = different files, no dependencies
- Follow TDD: Write failing tests before implementation
- Verify each service integration step before proceeding
- Use existing verification patterns from `bin/verify.configuration.sh`
- All HTTPS endpoints must use existing SSL certificates
- LobeChat uses Redis databases 2 and 3 (separate from other services)
- 🚨 **WSL2 CRITICAL**: Current `.etchosts` uses `127.0.0.1` but WSL2 requires Windows LAN IP (`192.168.1.103`)
- Use `bin/diag.wsl2.sh` to detect correct Windows host IP for WSL2 networking
- Windows hosts file already configured correctly with `192.168.1.103` entries

## Task Generation Rules Applied
1. **From Implementation Plan**:
   - Each setup step → setup task [P] where files don't conflict
   - Each verification step → test task [P]
   - Each deployment step → implementation task

2. **From Docker Compose**:
   - Service dependencies → integration tasks
   - Health checks → test tasks
   - Volume mounts → setup tasks

3. **From TDD Requirements**:
   - All tests before implementation
   - Health checks before functionality tests
   - Service connectivity before API tests

## Validation Checklist
- [x] All setup tasks have corresponding tests
- [x] All tests come before implementation
- [x] Parallel tasks are truly independent (different files)
- [x] Each task specifies exact file path
- [x] Dependencies properly ordered
- [x] TDD approach enforced (tests fail first)

## Success Criteria
- LobeChat service running and healthy in Docker
- HTTPS access via https://lobechat.dev.localhost
- LobeChat can query LightRAG with /global, /local, /hybrid modes
- All verification scripts pass
- Performance within acceptable limits
- Documentation updated with access instructions

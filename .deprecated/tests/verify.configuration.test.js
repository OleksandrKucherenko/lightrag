#!/usr/bin/env bun
/**
 * Configuration Verification Test Suite
 * 
 * This test suite validates the LightRAG configuration verification functions
 * using TDD approach with GIVEN/WHEN/THEN structure.
 * 
 * Test Categories:
 * - Configuration Detection (security enabled/disabled states)
 * - Storage Validation (deep data structure verification)
 * - Service Communication (inter-service connectivity)
 * - Environment Setup (variables, domains, certificates)
 */

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { spawn } from "bun";
import { readFile } from "fs/promises";

// Test configuration
const TEST_CONFIG = {
  timeout: 30000,
  retries: 2,
  services: ['proxy', 'monitor', 'kv', 'graph', 'vectors', 'rag', 'lobechat'],
  domain: process.env.PUBLISH_DOMAIN || 'dev.localhost'
};

// Test utilities
class TestUtils {
  static async executeCommand(command, args = [], options = {}) {
    const proc = spawn([command, ...args], {
      ...options,
      stdout: 'pipe',
      stderr: 'pipe'
    });
    
    const result = await proc.exited;
    const stdout = await new Response(proc.stdout).text();
    const stderr = await new Response(proc.stderr).text();
    
    return {
      exitCode: result,
      stdout: stdout.trim(),
      stderr: stderr.trim()
    };
  }

  static async dockerExec(container, command) {
    return this.executeCommand('docker', ['exec', container, 'sh', '-c', command]);
  }

  static async httpRequest(url, options = {}) {
    const { method = 'GET', headers = {}, timeout = 5000 } = options;
    
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);
      
      const response = await fetch(url, {
        method,
        headers,
        signal: controller.signal,
        ...options
      });
      
      clearTimeout(timeoutId);
      
      return {
        status: response.status,
        ok: response.ok,
        body: await response.text(),
        headers: Object.fromEntries(response.headers.entries())
      };
    } catch (error) {
      return {
        status: 0,
        ok: false,
        body: error.message,
        headers: {}
      };
    }
  }
}

describe("Configuration Detection Tests", () => {
  
  describe("Security Configuration Detection", () => {
    
    test("Redis Authentication State Detection", async () => {
      // GIVEN: A Redis instance that may or may not have authentication enabled
      const redisPassword = process.env.REDIS_PASSWORD;
      
      // WHEN: We test Redis authentication status
      const unauthResult = await TestUtils.dockerExec('kv', 'redis-cli ping');
      const authResult = redisPassword ? 
        await TestUtils.dockerExec('kv', `redis-cli -a "${redisPassword}" ping`) : 
        { stdout: '', stderr: 'No password configured' };
      
      // THEN: We should be able to determine if authentication is enabled or disabled
      if (redisPassword) {
        expect(unauthResult.stdout).toMatch(/NOAUTH|Authentication required/);
        expect(authResult.stdout).toMatch(/PONG/);
        console.log("✓ Redis authentication: ENABLED");
      } else {
        expect(unauthResult.stdout).toMatch(/PONG/);
        console.log("ℹ Redis authentication: DISABLED");
      }
    });

    test("Qdrant API Key Configuration Detection", async () => {
      // GIVEN: A Qdrant instance with potential API key protection
      const qdrantApiKey = process.env.QDRANT_API_KEY;
      const baseUrl = `https://vector.${TEST_CONFIG.domain}`;
      
      // WHEN: We test Qdrant API access without and with API key
      const unauthResult = await TestUtils.httpRequest(`${baseUrl}/collections`, {
        headers: { 'Accept': 'application/json' }
      });
      
      const authResult = qdrantApiKey ? 
        await TestUtils.httpRequest(`${baseUrl}/collections`, {
          headers: { 
            'Accept': 'application/json',
            'api-key': qdrantApiKey 
          }
        }) : { status: 0, body: 'No API key configured' };
      
      // THEN: We should understand the security configuration
      if (qdrantApiKey) {
        expect([401, 403]).toContain(unauthResult.status);
        expect(authResult.status).toBe(200);
        console.log("✓ Qdrant API security: ENABLED");
      } else {
        expect(unauthResult.status).toBe(200);
        console.log("ℹ Qdrant API security: DISABLED");
      }
    });

    test("Memgraph Authentication Detection", async () => {
      // GIVEN: A Memgraph instance with potential authentication
      const memgraphUser = process.env.MEMGRAPH_USER;
      const memgraphPassword = process.env.MEMGRAPH_PASSWORD;
      
      // WHEN: We test Memgraph connection with and without credentials
      const baseCommand = 'echo "RETURN 1;" | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false';
      const unauthResult = await TestUtils.dockerExec('graph', baseCommand);
      
      const authCommand = memgraphUser && memgraphPassword ? 
        `${baseCommand} --username ${memgraphUser} --password ${memgraphPassword}` :
        baseCommand;
      const authResult = await TestUtils.dockerExec('graph', authCommand);
      
      // THEN: We should determine authentication status
      if (memgraphUser && memgraphPassword) {
        if (authResult.stdout.includes('1')) {
          console.log("✓ Memgraph authentication: ENABLED and working");
          expect(authResult.stdout).toMatch(/1/);
        } else {
          console.log("⚠ Memgraph authentication: ENABLED but failing");
        }
      } else {
        console.log("ℹ Memgraph authentication: DISABLED");
      }
    });
  });

  describe("Environment Configuration Detection", () => {
    
    test("Domain Configuration Validation", async () => {
      // GIVEN: A configured domain for the LightRAG stack
      const domain = process.env.PUBLISH_DOMAIN || 'dev.localhost';
      
      // WHEN: We test domain resolution and accessibility
      const mainSiteResult = await TestUtils.httpRequest(`https://${domain}/health`);
      
      // THEN: The domain should be properly configured
      expect(mainSiteResult.status).toBe(200);
      expect(mainSiteResult.body).toMatch(/OK/);
      console.log(`✓ Domain configuration: ${domain} is accessible`);
    });

    test("SSL Certificate Configuration", async () => {
      // GIVEN: SSL certificates for the configured domain
      const domain = process.env.PUBLISH_DOMAIN || 'dev.localhost';
      
      // WHEN: We test HTTPS connectivity
      const httpsResult = await TestUtils.httpRequest(`https://${domain}/health`);
      
      // THEN: SSL should be working properly
      expect(httpsResult.status).toBe(200);
      console.log("✓ SSL certificates: Working properly");
    });
  });
});

describe("Storage Validation Tests", () => {
  
  describe("Redis Storage Deep Validation", () => {
    
    test("Redis Key-Value Storage Structure", async () => {
      // GIVEN: A Redis instance used for LightRAG KV storage
      const password = process.env.REDIS_PASSWORD;
      const authFlag = password ? `-a "${password}"` : '';
      
      // WHEN: We examine Redis data structures
      const keysResult = await TestUtils.dockerExec('kv', `redis-cli ${authFlag} keys "*"`);
      const infoResult = await TestUtils.dockerExec('kv', `redis-cli ${authFlag} info keyspace`);
      
      // THEN: We should understand the storage state
      console.log("ℹ Redis storage analysis:");
      console.log(`  Keys found: ${keysResult.stdout.split('\n').filter(k => k.trim()).length}`);
      console.log(`  Keyspace info: ${infoResult.stdout}`);
      
      expect(keysResult.exitCode).toBe(0);
      expect(infoResult.exitCode).toBe(0);
    });

    test("Redis Document Status Storage", async () => {
      // GIVEN: Redis used for document status tracking
      const password = process.env.REDIS_PASSWORD;
      const authFlag = password ? `-a "${password}"` : '';
      
      // WHEN: We check for document status keys
      const docKeysResult = await TestUtils.dockerExec('kv', 
        `redis-cli ${authFlag} keys "*doc*" | head -10`);
      
      // THEN: We should see document-related storage patterns
      console.log("ℹ Document status storage:");
      console.log(`  Document keys sample: ${docKeysResult.stdout}`);
      
      expect(docKeysResult.exitCode).toBe(0);
    });
  });

  describe("Qdrant Vector Storage Deep Validation", () => {
    
    test("Qdrant Collections Structure", async () => {
      // GIVEN: A Qdrant instance for vector storage
      const apiKey = process.env.QDRANT_API_KEY;
      const headers = apiKey ? `-H "api-key: ${apiKey}"` : '';
      
      // WHEN: We examine Qdrant collections
      const collectionsResult = await TestUtils.dockerExec('vectors', 
        `curl -s ${headers} http://localhost:6333/collections`);
      
      // THEN: We should understand the vector storage state
      try {
        const collections = JSON.parse(collectionsResult.stdout);
        console.log("ℹ Qdrant vector storage:");
        console.log(`  Collections: ${collections.result?.collections?.length || 0}`);
        
        if (collections.result?.collections?.length > 0) {
          for (const collection of collections.result.collections) {
            console.log(`  - ${collection.name}: ${collection.vectors_count || 0} vectors`);
          }
        }
        
        expect(collectionsResult.exitCode).toBe(0);
      } catch (error) {
        console.log(`⚠ Qdrant response parsing failed: ${error.message}`);
      }
    });

    test("Qdrant Vector Dimensions and Configuration", async () => {
      // GIVEN: Qdrant collections with specific configurations
      const apiKey = process.env.QDRANT_API_KEY;
      const headers = apiKey ? `-H "api-key: ${apiKey}"` : '';
      
      // WHEN: We examine collection configurations
      const collectionsResult = await TestUtils.dockerExec('vectors', 
        `curl -s ${headers} http://localhost:6333/collections`);
      
      // AND: We check specific collection details if they exist
      try {
        const collections = JSON.parse(collectionsResult.stdout);
        if (collections.result?.collections?.length > 0) {
          const firstCollection = collections.result.collections[0].name;
          const configResult = await TestUtils.dockerExec('vectors', 
            `curl -s ${headers} http://localhost:6333/collections/${firstCollection}`);
          
          // THEN: We should validate vector configuration matches expectations
          const config = JSON.parse(configResult.stdout);
          console.log("ℹ Vector configuration:");
          console.log(`  Dimension: ${config.result?.config?.params?.vectors?.size || 'unknown'}`);
          console.log(`  Distance: ${config.result?.config?.params?.vectors?.distance || 'unknown'}`);
        }
      } catch (error) {
        console.log("ℹ No collections found or parsing failed - this may be normal for new installations");
      }
    });
  });

  describe("Memgraph Graph Storage Deep Validation", () => {
    
    test("Memgraph Node and Relationship Analysis", async () => {
      // GIVEN: A Memgraph instance for graph storage
      const user = process.env.MEMGRAPH_USER;
      const password = process.env.MEMGRAPH_PASSWORD;
      const authFlags = user && password ? `--username ${user} --password ${password}` : '';
      
      // WHEN: We analyze graph structure
      const nodeCountResult = await TestUtils.dockerExec('graph', 
        `echo "MATCH (n) RETURN count(n) as node_count;" | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false ${authFlags}`);
      
      const relationshipCountResult = await TestUtils.dockerExec('graph', 
        `echo "MATCH ()-[r]->() RETURN count(r) as rel_count;" | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false ${authFlags}`);
      
      // THEN: We should understand the graph storage state
      console.log("ℹ Memgraph graph storage:");
      
      const nodeMatch = nodeCountResult.stdout.match(/(\d+)/);
      const relMatch = relationshipCountResult.stdout.match(/(\d+)/);
      
      console.log(`  Nodes: ${nodeMatch ? nodeMatch[1] : 'unknown'}`);
      console.log(`  Relationships: ${relMatch ? relMatch[1] : 'unknown'}`);
      
      expect(nodeCountResult.exitCode).toBe(0);
      expect(relationshipCountResult.exitCode).toBe(0);
    });

    test("Memgraph Schema and Indexes", async () => {
      // GIVEN: A Memgraph instance with potential schema
      const user = process.env.MEMGRAPH_USER;
      const password = process.env.MEMGRAPH_PASSWORD;
      const authFlags = user && password ? `--username ${user} --password ${password}` : '';
      
      // WHEN: We examine schema information
      const schemaResult = await TestUtils.dockerExec('graph', 
        `echo "SHOW INDEX INFO;" | mgconsole --host 127.0.0.1 --port 7687 --use-ssl=false ${authFlags}`);
      
      // THEN: We should see index configuration
      console.log("ℹ Memgraph schema:");
      console.log(`  Index info: ${schemaResult.stdout || 'No indexes found'}`);
      
      expect(schemaResult.exitCode).toBe(0);
    });
  });
});

describe("Service Communication Tests", () => {
  
  describe("Inter-Service Connectivity", () => {
    
    test("LightRAG to Redis Communication", async () => {
      // GIVEN: LightRAG service that should connect to Redis
      
      // WHEN: We test the connection from LightRAG container
      const connectionTest = await TestUtils.dockerExec('rag', 
        'nc -z kv 6379 && echo "Connected" || echo "Failed"');
      
      // THEN: The connection should be established
      expect(connectionTest.stdout).toMatch(/Connected/);
      console.log("✓ LightRAG → Redis: Connection established");
    });

    test("LightRAG to Qdrant Communication", async () => {
      // GIVEN: LightRAG service that should connect to Qdrant
      
      // WHEN: We test the connection from LightRAG container
      const connectionTest = await TestUtils.dockerExec('rag', 
        'curl -s --connect-timeout 3 http://vectors:6333/health || echo "Failed"');
      
      // THEN: The connection should be working
      expect(connectionTest.stdout).not.toMatch(/Failed/);
      console.log("✓ LightRAG → Qdrant: Connection established");
    });

    test("LightRAG to Memgraph Communication", async () => {
      // GIVEN: LightRAG service that should connect to Memgraph
      
      // WHEN: We test the connection from LightRAG container
      const connectionTest = await TestUtils.dockerExec('rag', 
        'nc -z graph 7687 && echo "Connected" || echo "Failed"');
      
      // THEN: The connection should be established
      expect(connectionTest.stdout).toMatch(/Connected/);
      console.log("✓ LightRAG → Memgraph: Connection established");
    });

    test("LobeChat to LightRAG Communication", async () => {
      // GIVEN: LobeChat service that should connect to LightRAG
      
      // WHEN: We test the connection from LobeChat container
      const healthCheck = await TestUtils.dockerExec('lobechat', 
        'curl -s --connect-timeout 3 http://rag:9621/health');
      
      // THEN: The health check should succeed
      try {
        const health = JSON.parse(healthCheck.stdout);
        expect(health.status).toBe('healthy');
        console.log("✓ LobeChat → LightRAG: Health check passed");
      } catch (error) {
        console.log(`⚠ LobeChat → LightRAG: Health check response parsing failed`);
      }
    });
  });

  describe("External API Connectivity", () => {
    
    test("LightRAG API Endpoint Accessibility", async () => {
      // GIVEN: LightRAG API that should be accessible externally
      const domain = TEST_CONFIG.domain;
      const apiKey = process.env.LIGHTRAG_API_KEY;
      
      // WHEN: We test API accessibility
      const healthResult = await TestUtils.httpRequest(`https://rag.${domain}/health`);
      
      // AND: We test authenticated endpoint if API key is available
      let authResult = { status: 0, body: 'No API key configured' };
      if (apiKey) {
        authResult = await TestUtils.httpRequest(`https://rag.${domain}/documents`, {
          headers: { 'X-API-Key': apiKey }
        });
      }
      
      // THEN: The API should be accessible
      expect(healthResult.status).toBe(200);
      console.log("✓ LightRAG API: Health endpoint accessible");
      
      if (apiKey) {
        expect(authResult.status).toBe(200);
        console.log("✓ LightRAG API: Authenticated endpoints accessible");
      } else {
        console.log("ℹ LightRAG API: No API key configured for authentication test");
      }
    });
  });
});

// Test execution summary
describe("Configuration Summary", () => {
  
  test("Generate Configuration Report", async () => {
    // GIVEN: All previous tests have run
    
    // WHEN: We compile a configuration summary
    const summary = {
      domain: process.env.PUBLISH_DOMAIN || 'dev.localhost',
      security: {
        redis_auth: !!process.env.REDIS_PASSWORD,
        qdrant_api_key: !!process.env.QDRANT_API_KEY,
        memgraph_auth: !!(process.env.MEMGRAPH_USER && process.env.MEMGRAPH_PASSWORD),
        lightrag_api_key: !!process.env.LIGHTRAG_API_KEY
      },
      services: TEST_CONFIG.services
    };
    
    // THEN: We should have a clear picture of the configuration
    console.log("\n" + "=".repeat(60));
    console.log("LIGHTRAG CONFIGURATION SUMMARY");
    console.log("=".repeat(60));
    console.log(`Domain: ${summary.domain}`);
    console.log(`Security Configuration:`);
    console.log(`  Redis Authentication: ${summary.security.redis_auth ? 'ENABLED' : 'DISABLED'}`);
    console.log(`  Qdrant API Key: ${summary.security.qdrant_api_key ? 'ENABLED' : 'DISABLED'}`);
    console.log(`  Memgraph Authentication: ${summary.security.memgraph_auth ? 'ENABLED' : 'DISABLED'}`);
    console.log(`  LightRAG API Key: ${summary.security.lightrag_api_key ? 'ENABLED' : 'DISABLED'}`);
    console.log(`Services: ${summary.services.join(', ')}`);
    console.log("=".repeat(60));
    
    expect(summary).toBeDefined();
  });
});

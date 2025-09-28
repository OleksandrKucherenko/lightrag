#!/bin/bash

# security storage folder
mkdir -p .secrets

# caddy
mkdir -p docker/data/caddy
mkdir -p docker/etc/caddy

# kv
mkdir -p docker/data/redis

# graph
mkdir -p docker/data/memgraph
mkdir -p docker/logs/memgraph

# vector
mkdir -p docker/data/qdrant/storage
mkdir -p docker/data/qdrant/snapshots

# rag
mkdir -p docker/data/lightrag/storage
mkdir -p docker/data/lightrag/inputs
mkdir -p docker/logs/lightrag

# webui
mkdir -p docker/data/lobechat

# LLM/IDE folders
mkdir -p .windsurf .opencode .codex
ln -sfn "$(pwd)/.kilocode/workflows" .windsurf/workflows || true
ln -sfn "$(pwd)/.kilocode/workflows" .opencode/command || true

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This repository contains a Docker-based isolated development environment setup for Claude Code. It creates a containerized environment with all essential development tools pre-installed.

## Key Commands

### Setup and Usage
```bash
# Initial setup (run once)
./setup-claude-isolated.sh

# Start development environment
claude-dev                    # In current directory
claude-dev /path/to/project   # In specific directory
claude-dev . claude          # Start with Claude directly

# Update Claude Code
claude-dev-update
```

### Making Changes to the Environment
- To add new tools to the Docker image: Edit the Dockerfile section in `setup-claude-isolated.sh` (around line 127-194)
- To modify startup behavior: Edit the entrypoint script section (around line 209-259)
- After changes, rebuild: `cd ~/.claude-docker && docker build -t claude-isolated .`

## Architecture Overview

The setup consists of:
1. **setup-claude-isolated.sh**: Main setup script that:
   - Auto-detects local GitHub credentials
   - Creates Docker configuration files in `~/.claude-docker/`
   - Builds a Docker image with Claude Code and development tools
   - Creates `claude-dev` and `claude-dev-update` commands in `~/bin/`

2. **Docker Container**: Ubuntu 22.04 base with:
   - Claude Code CLI
   - Python 3 + uv (fast package manager)
   - Node.js 20
   - Development tools (git, gh, docker CLI, ripgrep, etc.)
   - Project directory mounted at `/workspace`

3. **Credential Handling**: 
   - Automatically detects git config and gh CLI authentication
   - Stores credentials in `~/.claude-docker/` (username, email, gitname, token)
   - Mounts credentials read-only into container

## Important Implementation Details

- The container is ephemeral - only files in the mounted project directory persist
- GitHub credentials are handled securely via mounted volumes, not baked into the image
- The setup supports both token-based auth and gh CLI authentication
- Docker-in-Docker is supported if Docker socket is available on host
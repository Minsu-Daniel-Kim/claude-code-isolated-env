# Claude Code Isolated Environment

A Docker-based isolated development environment with Claude Code and all essential development tools pre-installed.

## Quick Start

```bash
# Run the setup script
./setup-claude-isolated.sh

# Start developing
claude-dev
```

## What's Included

- **Claude Code** - Anthropic's official CLI
- **Languages**: Python 3, Node.js 20, TypeScript
- **Python Tools**: pip, pipenv, poetry, uv, black, pytest
- **Node Tools**: npm, typescript, ts-node, prettier, eslint
- **Version Control**: git, GitHub CLI (optional)
- **Utilities**: Docker CLI, ripgrep, jq, tmux, vim, nano

## Usage

### Basic Commands

```bash
# Start in current directory
claude-dev

# Start in specific project
claude-dev /path/to/project

# Start Claude directly
claude-dev . claude

# Update Claude Code to latest version
claude-dev-update
```

### Inside the Container

```bash
# Run Claude Code
claude

# Use any installed tool
python3 script.py
npm install
git status
```

## Features

- **Isolated Environment**: No system pollution
- **Persistent Changes**: Files are saved to your project
- **GitHub Integration**: Optional authentication during setup
- **Docker-in-Docker**: Run Docker commands inside container
- **Pre-configured**: Git aliases and useful tools ready to use

## Examples

### Basic Development Session
```bash
cd my-project
claude-dev
# Now inside container
claude  # Start Claude Code
```

### Python Project
```bash
claude-dev my-python-app
# Inside container
uv pip install -r requirements.txt  # Fast installs with uv
python3 main.py
```

### Node.js Project
```bash
claude-dev my-node-app
# Inside container
npm install
npm run dev
```

## Requirements

- Docker installed and running
- Bash shell
- macOS or Linux (Windows users: use WSL2)

## Optional: GitHub Integration

During setup, you can provide:
- GitHub username
- GitHub personal access token
- Git email (defaults to username@users.noreply.github.com)

This enables:
- Authenticated git operations
- GitHub CLI (`gh`) commands
- Automatic credential configuration

## Troubleshooting

### Permission Denied
```bash
chmod +x setup-claude-isolated.sh
```

### Command Not Found
```bash
source ~/.bashrc
# Or open a new terminal
```

### Update Claude Code
```bash
claude-dev-update
```

### Rebuild After Setup Changes
If you modify the setup script or need to rebuild the environment:
```bash
# Exit container if you're in one
exit

# Re-run setup to regenerate Dockerfile
cd /path/to/claude-code-isolated-env
bash setup-claude-isolated.sh
# Press Enter/Y when asked about credentials

# Rebuild Docker image
cd ~/.claude-docker
docker build --no-cache -t claude-isolated .

# Run claude-dev
claude-dev
```

## Notes

- Your project files are mounted at `/workspace` inside the container
- All changes are immediately reflected in your actual project directory
- The container is ephemeral - only your project files persist
- Install project dependencies inside the container as needed
- Use requirements.txt or virtual environment for project-specific dependencies. This keeps your dependencies documented and reproducible across different environments.
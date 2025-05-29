#!/bin/bash

# Claude Code Isolated Environment Setup
# Complete isolated development environment with Claude Code

set -e

echo "🚀 Claude Code Isolated Environment Setup"
echo "========================================"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Create directories
echo "📁 Creating configuration directories..."
mkdir -p ~/.claude-docker
mkdir -p ~/bin

# Auto-detect GitHub credentials
echo ""
echo "🔍 Checking for existing GitHub credentials..."

# Try to get git username and email from git config
GIT_USER=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

# Try to get GitHub username from gh cli
if command -v gh &> /dev/null; then
    GITHUB_USER=$(gh api user --jq .login 2>/dev/null || echo "")
else
    GITHUB_USER=""
fi

# If we found credentials, use them
if [ ! -z "$GITHUB_USER" ] || [ ! -z "$GIT_USER" ]; then
    echo "✅ Found existing Git configuration:"
    [ ! -z "$GIT_USER" ] && echo "   Name: $GIT_USER"
    [ ! -z "$GIT_EMAIL" ] && echo "   Email: $GIT_EMAIL"
    [ ! -z "$GITHUB_USER" ] && echo "   GitHub: $GITHUB_USER"
    echo ""
    read -p "Use these credentials? (Y/n): " USE_EXISTING
    
    if [[ "$USE_EXISTING" != "n" && "$USE_EXISTING" != "N" ]]; then
        # Use existing credentials
        if [ -z "$GITHUB_USER" ] && [ ! -z "$GIT_USER" ]; then
            # Try to extract GitHub username from email if it's a GitHub noreply email
            if [[ "$GIT_EMAIL" =~ ^[0-9]+\+(.+)@users\.noreply\.github\.com$ ]]; then
                GITHUB_USER="${BASH_REMATCH[1]}"
            elif [[ "$GIT_EMAIL" =~ ^(.+)@users\.noreply\.github\.com$ ]]; then
                GITHUB_USER="${BASH_REMATCH[1]}"
            else
                read -p "GitHub username: " GITHUB_USER
            fi
        fi
        
        # Check if gh CLI is authenticated
        if command -v gh &> /dev/null && gh auth status &>/dev/null; then
            echo "🔐 Using GitHub CLI authentication"
            echo "gh-cli" > ~/.claude-docker/auth-method
        else
            echo "🔑 Please provide a GitHub personal access token"
            echo "   (Create one at: https://github.com/settings/tokens)"
            read -sp "GitHub token: " GITHUB_TOKEN
            echo ""
            if [ ! -z "$GITHUB_TOKEN" ]; then
                echo "$GITHUB_TOKEN" > ~/.claude-docker/token
                chmod 600 ~/.claude-docker/token
            fi
        fi
        
        # Save username and email
        [ ! -z "$GITHUB_USER" ] && echo "$GITHUB_USER" > ~/.claude-docker/username
        [ ! -z "$GIT_EMAIL" ] && echo "$GIT_EMAIL" > ~/.claude-docker/email
        [ ! -z "$GIT_USER" ] && echo "$GIT_USER" > ~/.claude-docker/gitname
        chmod 600 ~/.claude-docker/* 2>/dev/null || true
    else
        # Manual setup
        echo ""
        echo "🔑 Manual GitHub Setup (Optional - press Enter to skip)"
        read -p "GitHub username: " GITHUB_USER
        if [ ! -z "$GITHUB_USER" ]; then
            read -sp "GitHub token: " GITHUB_TOKEN
            echo ""
            read -p "Git email (or press Enter for default): " GIT_EMAIL
            read -p "Git name (or press Enter for username): " GIT_USER
            
            [ -z "$GIT_EMAIL" ] && GIT_EMAIL="${GITHUB_USER}@users.noreply.github.com"
            [ -z "$GIT_USER" ] && GIT_USER="$GITHUB_USER"
            
            # Save credentials
            echo "$GITHUB_TOKEN" > ~/.claude-docker/token
            echo "$GITHUB_USER" > ~/.claude-docker/username
            echo "$GIT_EMAIL" > ~/.claude-docker/email
            echo "$GIT_USER" > ~/.claude-docker/gitname
            chmod 600 ~/.claude-docker/*
        fi
    fi
else
    # No existing config found - manual setup
    echo "❌ No existing Git configuration found"
    echo ""
    echo "🔑 GitHub Setup (Optional - press Enter to skip)"
    read -p "GitHub username: " GITHUB_USER
    if [ ! -z "$GITHUB_USER" ]; then
        read -sp "GitHub token: " GITHUB_TOKEN
        echo ""
        read -p "Git email (or press Enter for default): " GIT_EMAIL
        read -p "Git name (or press Enter for username): " GIT_USER
        
        [ -z "$GIT_EMAIL" ] && GIT_EMAIL="${GITHUB_USER}@users.noreply.github.com"
        [ -z "$GIT_USER" ] && GIT_USER="$GITHUB_USER"
        
        # Save credentials
        echo "$GITHUB_TOKEN" > ~/.claude-docker/token
        echo "$GITHUB_USER" > ~/.claude-docker/username
        echo "$GIT_EMAIL" > ~/.claude-docker/email
        echo "$GIT_USER" > ~/.claude-docker/gitname
        chmod 600 ~/.claude-docker/*
    fi
fi

# Create comprehensive Dockerfile
echo "🐳 Creating Docker configuration..."
cat > ~/.claude-docker/Dockerfile << 'EOF'
FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Basic tools
    curl wget git vim nano \
    # Build tools
    build-essential gcc g++ make cmake \
    # Python
    python3 python3-pip python3-venv \
    # Node.js (via NodeSource)
    ca-certificates gnupg \
    # Utilities
    jq ripgrep tree htop tmux \
    # Network tools
    net-tools iputils-ping dnsutils \
    # Archive tools
    zip unzip tar \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install global npm packages
RUN npm install -g \
    @anthropic-ai/claude-code \
    typescript \
    ts-node \
    nodemon \
    prettier \
    eslint

# Create claude wrapper to skip permissions
RUN CLAUDE_PATH=$(which claude) && \
    if [ ! -z "$CLAUDE_PATH" ]; then \
        mv "$CLAUDE_PATH" "${CLAUDE_PATH}-original" && \
        echo '#!/bin/bash' > "$CLAUDE_PATH" && \
        echo "exec \"${CLAUDE_PATH}-original\" --dangerously-skip-permissions \"\$@\"" >> "$CLAUDE_PATH" && \
        chmod +x "$CLAUDE_PATH" && \
        echo "Claude wrapper installed at $CLAUDE_PATH"; \
    fi

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for Docker-in-Docker capability)
RUN curl -fsSL https://get.docker.com | sh

# Set up Python tools
RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install \
    pipenv \
    poetry \
    black \
    flake8 \
    pytest \
    requests \
    numpy \
    pandas

# Install uv (fast Python package installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /etc/bash.bashrc

# Create workspace
WORKDIR /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
EOF

# Create entrypoint script
cat > ~/.claude-docker/entrypoint.sh << 'EOF'
#!/bin/bash

# Configure git if credentials exist
if [ -f /creds/username ]; then
    # Set git name
    if [ -f /creds/gitname ]; then
        git config --global user.name "$(cat /creds/gitname)"
    else
        git config --global user.name "$(cat /creds/username)"
    fi
    
    # Set git email
    if [ -f /creds/email ]; then
        git config --global user.email "$(cat /creds/email)"
    else
        git config --global user.email "$(cat /creds/username)@users.noreply.github.com"
    fi
    
    # Configure authentication
    if [ -f /creds/auth-method ] && [ "$(cat /creds/auth-method)" = "gh-cli" ]; then
        # Use gh CLI authentication if available on host
        echo "🔐 GitHub CLI authentication detected"
    elif [ -f /creds/token ]; then
        # Configure git credential helper
        git config --global credential.helper store
        echo "https://$(cat /creds/username):$(cat /creds/token)@github.com" > ~/.git-credentials
        
        # Configure GitHub CLI with token
        echo "$(cat /creds/token)" | gh auth login --with-token 2>/dev/null || true
    fi
fi

# Check if gh is already authenticated (from mounted config)
if command -v gh &> /dev/null && gh auth status &>/dev/null 2>&1; then
    echo "🔐 GitHub CLI already authenticated"
fi

# Set up useful aliases
echo 'alias ll="ls -la"' >> ~/.bashrc
echo 'alias gs="git status"' >> ~/.bashrc
echo 'alias gd="git diff"' >> ~/.bashrc
echo 'alias gc="git commit"' >> ~/.bashrc
echo 'alias gp="git push"' >> ~/.bashrc

# Welcome message
echo "🚀 Claude Code Isolated Environment"
echo "📦 Available: claude, node, python3, git, gh, docker, uv"
if [ -f /creds/username ]; then
    echo "👤 GitHub: $(cat /creds/username)"
fi
echo "📂 Workspace: /workspace"
echo ""

exec "$@"
EOF

# Build the Docker image
echo "🔨 Building Docker image (this may take a few minutes)..."
cd ~/.claude-docker
docker build -t claude-isolated .

# Create the main command
echo "📝 Creating 'claude-dev' command..."
cat > ~/bin/claude-dev << 'EOF'
#!/bin/bash

# Claude Dev - Isolated development environment

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
PROJECT_DIR="${1:-$(pwd)}"
EXTRA_ARGS="${@:2}"

# Change to project directory
cd "$PROJECT_DIR"

# Display info
echo -e "${BLUE}🚀 Starting Claude Isolated Environment${NC}"
echo -e "${BLUE}📂 Project: $PROJECT_DIR${NC}"
echo -e "${BLUE}🛠️  Tools: claude, node, python, git, docker${NC}"

# Check if credentials exist
CRED_MOUNT=""
GH_CONFIG_MOUNT=""
if [ -f ~/.claude-docker/username ]; then
    echo -e "${GREEN}✓ GitHub integration enabled${NC}"
    CRED_MOUNT="-v $HOME/.claude-docker:/creds:ro"
fi

# Check if gh CLI config exists
if [ -d ~/.config/gh ]; then
    echo -e "${GREEN}✓ GitHub CLI config detected${NC}"
    GH_CONFIG_MOUNT="-v $HOME/.config/gh:/root/.config/gh:ro"
fi

# Detect if we need special permissions
DOCKER_SOCK=""
if [ -S /var/run/docker.sock ]; then
    echo -e "${YELLOW}🐳 Docker socket detected - enabling Docker-in-Docker${NC}"
    DOCKER_SOCK="-v /var/run/docker.sock:/var/run/docker.sock"
fi

echo ""

# Run container
docker run --rm -it \
  -v "$PROJECT_DIR":/workspace \
  $CRED_MOUNT \
  $GH_CONFIG_MOUNT \
  $DOCKER_SOCK \
  -e GIT_EMAIL="${GIT_EMAIL:-}" \
  --name claude-dev-$$ \
  claude-isolated $EXTRA_ARGS

echo -e "${BLUE}👋 Session ended${NC}"
EOF

chmod +x ~/bin/claude-dev

# Create update script
cat > ~/bin/claude-dev-update << 'EOF'
#!/bin/bash

echo "🔄 Updating Claude Code in isolated environment..."

# Rebuild with latest Claude Code
docker build --no-cache -t claude-isolated ~/.claude-docker/

echo "✅ Update complete!"
EOF
chmod +x ~/bin/claude-dev-update

# Update PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📖 Commands:"
echo "  claude-dev              # Start in current directory"
echo "  claude-dev /path/to/project  # Start in specific directory"
echo "  claude-dev . bash      # Start with bash (default)"
echo "  claude-dev . claude    # Start with Claude Code directly"
echo "  claude-dev-update      # Update Claude Code version"
echo ""
echo "💡 Inside the container:"
echo "  - claude          # Run Claude Code"
echo "  - All development tools available"
echo "  - Your files are in /workspace"
echo "  - Changes are saved to your project"
echo ""
echo "🔄 Run: source ~/.bashrc"
echo "   Or start a new terminal"
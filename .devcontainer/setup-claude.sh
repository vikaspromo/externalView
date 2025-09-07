#!/bin/bash
# Setup Claude credentials
mkdir -p ~/.claude
echo "$CLAUDE_CREDENTIALS" > ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json

# Install Claude Code globally
npm install -g claude-code

# Add claude alias to bashrc
echo 'alias claude="npx claude-code"' >> ~/.bashrc

echo "✅ Claude Code installed and authenticated!"
echo "Run 'source ~/.bashrc' or start a new terminal to use the 'claude' command"

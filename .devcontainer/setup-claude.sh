#!/bin/bash
mkdir -p ~/.claude
echo "$CLAUDE_CREDENTIALS" > ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json
echo "✅ Claude Code authentication configured!"

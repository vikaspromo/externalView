#!/bin/bash

echo "🚀 Starting ExternalView Codespace setup..."

# Wait for the environment to be ready
sleep 2

# Dynamically set the APP_URL based on the current Codespace
if [ -n "$CODESPACE_NAME" ]; then
    APP_URL="https://${CODESPACE_NAME}-3000.app.github.dev"
    echo "✅ Detected Codespace: $CODESPACE_NAME"
    echo "✅ Setting APP_URL to: $APP_URL"
    
    # Update the .env.local file with the correct URL
    if [ -f /workspaces/externalView/.env.local ]; then
        # Create a backup of the original .env.local if it doesn't exist
        if [ ! -f /workspaces/externalView/.env.local.backup ]; then
            cp /workspaces/externalView/.env.local /workspaces/externalView/.env.local.backup
        fi
        
        # Update the NEXT_PUBLIC_APP_URL
        sed -i "s|NEXT_PUBLIC_APP_URL=.*|NEXT_PUBLIC_APP_URL=$APP_URL|" /workspaces/externalView/.env.local
        echo "✅ Updated .env.local with Codespace URL"
    else
        echo "⚠️  .env.local not found, creating from template..."
        # Create .env.local if it doesn't exist
        cat > /workspaces/externalView/.env.local << EOF
NEXT_PUBLIC_SUPABASE_URL=https://vohyhkjygvkaxlmqkbem.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvaHloa2p5Z3ZrYXhsbXFrYmVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5NTI3NDcsImV4cCI6MjA3MDUyODc0N30.VzSvIk5psbVauOARGu5pP4ekRlukc0bEkr25R4ZhxRk
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvaHloa2p5Z3ZrYXhsbXFrYmVtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDk1Mjc0NywiZXhwIjoyMDcwNTI4NzQ3fQ.8yVCYgR5qmfb-YFCj08UzeVWyVt60UTErZ7z736LYkY
NEXT_PUBLIC_APP_URL=$APP_URL
EOF
    fi
else
    echo "⚠️  Not running in a Codespace, using localhost"
    APP_URL="http://localhost:3000"
fi

# Navigate to the project directory
cd /workspaces/externalView

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing npm dependencies..."
    npm install
else
    echo "✅ Dependencies already installed"
fi

# Kill any existing Next.js processes
echo "🔄 Cleaning up any existing processes..."
pkill -f "next dev" 2>/dev/null || true

# Start the Next.js development server in the background
echo "🎯 Starting Next.js development server..."
nohup npm run dev > /tmp/nextjs.log 2>&1 &

echo "✅ Next.js server starting in background..."
echo "📝 Logs available at: /tmp/nextjs.log"

# Wait a moment and check if the server started successfully
sleep 5
if pgrep -f "next dev" > /dev/null; then
    echo "✅ Next.js server is running!"
    echo "🌐 Access your application at: $APP_URL"
    echo ""
    echo "📌 Remember to add this URL to your Supabase Redirect URLs:"
    echo "   $APP_URL/auth/callback"
else
    echo "❌ Failed to start Next.js server. Check /tmp/nextjs.log for details"
fi

echo "🎉 Startup script completed!"
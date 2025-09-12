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
        echo "⚠️  .env.local not found"
        echo "📝 Please create .env.local from .env.example:"
        echo "   cp .env.example .env.local"
        echo "   Then update it with your Supabase project credentials"
        echo ""
        echo "🔐 For security reasons, we no longer create .env.local automatically."
        echo "   Get your credentials from: https://app.supabase.com/project/_/settings/api"
        
        # Create a minimal .env.local with just the APP_URL for Codespaces
        cat > /workspaces/externalView/.env.local << EOF
# Minimal configuration for Codespaces
# Please add your Supabase credentials below:
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url_here
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key_here
SUPABASE_SERVICE_KEY=your_supabase_service_key_here
NEXT_PUBLIC_APP_URL=$APP_URL
EOF
        
        echo "⚠️  Created .env.local with placeholders. Please update with real values."
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
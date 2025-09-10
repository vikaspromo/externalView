#!/bin/bash

# RLS Policy Test Runner Script
# This script helps you test the comprehensive RLS policies

set -e

echo "================================================"
echo "    RLS Policy Testing Setup & Runner"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 1: Check if Supabase is running
echo -e "${BLUE}Step 1: Checking Supabase status...${NC}"
if npx supabase status 2>/dev/null | grep -q "RUNNING"; then
    echo -e "${GREEN}✓ Supabase is running${NC}"
else
    echo -e "${YELLOW}Starting Supabase...${NC}"
    npx supabase start
    sleep 5
fi

# Step 2: Get Supabase keys
echo -e "\n${BLUE}Step 2: Getting Supabase configuration...${NC}"
ANON_KEY=$(npx supabase status --output json 2>/dev/null | grep -o '"anon_key":"[^"]*' | cut -d'"' -f4)
SERVICE_KEY=$(npx supabase status --output json 2>/dev/null | grep -o '"service_key":"[^"]*' | cut -d'"' -f4)

if [ -z "$ANON_KEY" ] || [ -z "$SERVICE_KEY" ]; then
    echo -e "${RED}✗ Failed to get Supabase keys${NC}"
    echo "Please ensure Supabase is running: npx supabase start"
    exit 1
fi

echo -e "${GREEN}✓ Got Supabase keys${NC}"

# Step 3: Create .env.test file
echo -e "\n${BLUE}Step 3: Creating test environment file...${NC}"
cat > .env.test << EOF
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=$ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SERVICE_KEY
EOF
echo -e "${GREEN}✓ Created .env.test${NC}"

# Step 4: Install dependencies if needed
echo -e "\n${BLUE}Step 4: Checking Node.js dependencies...${NC}"
if [ ! -f "package.json" ]; then
    echo -e "${YELLOW}Creating package.json...${NC}"
    npm init -y > /dev/null 2>&1
fi

if ! npm list @supabase/supabase-js dotenv 2>/dev/null | grep -q "@supabase/supabase-js"; then
    echo -e "${YELLOW}Installing required packages...${NC}"
    npm install @supabase/supabase-js dotenv --save-dev
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi

# Step 5: Apply migrations
echo -e "\n${BLUE}Step 5: Applying database migrations...${NC}"
echo -e "${YELLOW}Resetting database and applying migrations...${NC}"

# Try to reset the database
if npx supabase db reset 2>&1 | grep -q "Applied"; then
    echo -e "${GREEN}✓ Migrations applied successfully${NC}"
else
    echo -e "${YELLOW}⚠ Database reset had issues, trying to apply migrations manually...${NC}"
    
    # Try applying migrations manually
    for migration in supabase/migrations/*.sql; do
        if [ -f "$migration" ]; then
            filename=$(basename "$migration")
            echo -e "  Applying $filename..."
            psql "postgresql://postgres:postgres@localhost:54322/postgres" -f "$migration" 2>/dev/null || true
        fi
    done
fi

# Step 6: Verify policies are installed
echo -e "\n${BLUE}Step 6: Verifying RLS policies...${NC}"
POLICY_COUNT=$(psql "postgresql://postgres:postgres@localhost:54322/postgres" -t -c "
SELECT COUNT(*) FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('clients', 'users', 'client_org_history', 'organizations', 'org_positions');" 2>/dev/null | tr -d ' ')

if [ "$POLICY_COUNT" -gt "0" ]; then
    echo -e "${GREEN}✓ Found $POLICY_COUNT RLS policies${NC}"
else
    echo -e "${RED}✗ No RLS policies found${NC}"
    echo "Please check your migrations"
fi

# Step 7: Run tests
echo -e "\n${BLUE}Step 7: Running RLS Policy Tests...${NC}"
echo "================================================"
echo ""

# Check which test file to run
if [ -f "test-rls-policies.js" ]; then
    # Make the test file executable
    chmod +x test-rls-policies.js
    
    # Run the tests with the test environment
    node -r dotenv/config test-rls-policies.js dotenv_config_path=.env.test
elif [ -f "supabase/tests/test_rls_policies.sql" ]; then
    echo -e "${YELLOW}Running SQL test suite...${NC}"
    psql "postgresql://postgres:postgres@localhost:54322/postgres" -f supabase/tests/test_rls_policies.sql
else
    echo -e "${RED}✗ No test files found${NC}"
    echo "Expected test-rls-policies.js or supabase/tests/test_rls_policies.sql"
    exit 1
fi

echo ""
echo "================================================"
echo -e "${GREEN}Testing complete!${NC}"
echo ""
echo "To manually inspect the database:"
echo "  npx supabase studio"
echo ""
echo "To view logs:"
echo "  npx supabase logs"
echo ""
echo "To stop Supabase:"
echo "  npx supabase stop"
echo "================================================"
# Claude Code Setup Prompt for ExternalView 0.2

Use this prompt with Claude Code to set up your new project:

---

## Prompt:

"Help me set up a new ExternalView 0.2 project from scratch. I need to:

1. **Create a new Next.js project** called 'externalview_0.2' with TypeScript, Tailwind, and App Router:
   ```bash
   npx create-next-app@latest externalview_0.2 --typescript --tailwind --app --no-src-dir
   ```

2. **Set up a NEW Supabase project** - I don't have one yet. Walk me through:
   - Creating an account on supabase.com
   - Creating a new project called "externalview-v2" 
   - Getting the API URL and keys
   - Setting up local Supabase CLI

3. **Install only essential dependencies**:
   ```bash
   npm install @supabase/supabase-js @anthropic-ai/sdk zod
   npm install -D @types/node
   ```

4. **Initialize and link Supabase**:
   ```bash
   npx supabase init
   npx supabase link --project-ref [my-project-ref]
   npx supabase start
   ```

5. **Create the database schema** with these 5 tables using STANDARD PostgreSQL (no Supabase-specific features):
   ```sql
   -- clients table (your paying customers)
   CREATE TABLE clients (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     name TEXT NOT NULL,
     created_at TIMESTAMPTZ DEFAULT NOW()
   );

   -- users table  
   CREATE TABLE users (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     client_id UUID REFERENCES clients(id),
     email TEXT NOT NULL,
     auth_user_id UUID UNIQUE,
     created_at TIMESTAMPTZ DEFAULT NOW()
   );

   -- organizations table
   CREATE TABLE organizations (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     client_id UUID REFERENCES clients(id),
     name TEXT NOT NULL,
     ein TEXT,
     website TEXT,
     metadata JSONB,
     created_at TIMESTAMPTZ DEFAULT NOW()
   );

   -- positions table
   CREATE TABLE positions (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     organization_id UUID REFERENCES organizations(id),
     client_id UUID REFERENCES clients(id),
     issue TEXT,
     stance TEXT,
     details TEXT,
     analyzed_at TIMESTAMPTZ DEFAULT NOW()
   );

   -- audit_log table (for SOC 2)
   CREATE TABLE audit_log (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     timestamp TIMESTAMPTZ DEFAULT NOW(),
     user_id UUID,
     client_id UUID,
     action TEXT,
     table_name TEXT,
     record_id UUID,
     metadata JSONB
   );

   -- Basic indexes
   CREATE INDEX idx_users_client ON users(client_id);
   CREATE INDEX idx_orgs_client ON organizations(client_id);
   CREATE INDEX idx_positions_client ON positions(client_id);
   CREATE INDEX idx_audit_client ON audit_log(client_id, timestamp);
   ```

6. **Create the Repository pattern** in `lib/db/repository.ts`:
   - Generic Repository interface that works with any database
   - SupabaseRepository implementation
   - This is THE KEY to easy AWS migration later

7. **Create database exports** in `lib/db/index.ts`:
   - Export repositories for each table
   - This is the ONLY file I'll need to change when migrating to AWS

8. **Create auth abstraction** in `lib/auth/index.ts`:
   - getCurrentUser() function
   - getClientId() helper
   - Wraps Supabase auth but can swap to Cognito later

9. **Set up GitHub Secrets for secure key storage**:
   
   Go to GitHub repository settings → Secrets and variables → Actions:
   ```
   NEXT_PUBLIC_SUPABASE_URL        # Your Supabase project URL
   NEXT_PUBLIC_SUPABASE_ANON_KEY   # Public anon key (safe to expose)
   SUPABASE_SERVICE_KEY            # Service role key (NEVER expose)
   ANTHROPIC_API_KEY               # Claude API key (NEVER expose)
   ```
   
   For Codespaces, also add to → Secrets and variables → Codespaces:
   ```
   SUPABASE_SERVICE_KEY
   ANTHROPIC_API_KEY
   ```
   
   Create `.env.example` (safe to commit):
   ```env
   # Copy this to .env.local for local development
   # In production, these come from GitHub Secrets/Vercel env vars
   NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
   SUPABASE_SERVICE_KEY=your-service-key
   ANTHROPIC_API_KEY=sk-ant-xxxxx
   ```
   
   Add `.env.local` to `.gitignore`:
   ```bash
   echo ".env.local" >> .gitignore
   ```

10. **Create a minimal dashboard** at `app/dashboard/page.tsx`:
    - List organizations
    - Add new organization form
    - Simple client filtering

11. **Push to GitHub**:
    ```bash
    git init
    git add .
    git commit -m "Initial ExternalView 0.2 prototype"
    git remote add origin https://github.com/vikaspromo/externalView_0.2
    git push -u origin main
    ```

**IMPORTANT REQUIREMENTS:**
- Use ONLY standard PostgreSQL (no Supabase-specific features like RLS)
- Keep everything minimal - this is a 2-week prototype
- Build clean abstractions (Repository pattern, Auth interface) for AWS migration
- Simple client filtering at application level (no complex RLS)
- Include basic audit logging for SOC 2 compliance
- Focus on shipping fast with room to migrate later

The goal is to have a working prototype in 2 weeks that can be migrated to AWS by changing only 5 files."

---

## What This Gets You:

1. **Working prototype** in hours, not weeks
2. **Clean abstractions** for AWS migration
3. **SOC 2 foundation** with audit logging
4. **Simple tenant isolation** without complexity
5. **Standard SQL** that works anywhere

## Using GitHub Secrets in Different Environments:

### For Local Development:
```bash
# Create .env.local from example (NOT committed to git)
cp .env.example .env.local
# Then manually add your actual keys to .env.local
```

### For GitHub Codespaces:
Secrets are automatically available as environment variables when you:
1. Add them to Settings → Codespaces secrets
2. Start a new Codespace

```javascript
// In your code, access them directly:
process.env.ANTHROPIC_API_KEY  // Automatically injected
process.env.SUPABASE_SERVICE_KEY  // Automatically injected
```

### For Vercel Deployment:
```bash
# Install Vercel CLI
npm i -g vercel

# Link project and add secrets
vercel link
vercel env add NEXT_PUBLIC_SUPABASE_URL
vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY  
vercel env add SUPABASE_SERVICE_KEY
vercel env add ANTHROPIC_API_KEY
```

### For GitHub Actions CI/CD:
```yaml
# .github/workflows/deploy.yml
env:
  NEXT_PUBLIC_SUPABASE_URL: ${{ secrets.NEXT_PUBLIC_SUPABASE_URL }}
  NEXT_PUBLIC_SUPABASE_ANON_KEY: ${{ secrets.NEXT_PUBLIC_SUPABASE_ANON_KEY }}
  SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Security Best Practices:
1. **NEVER commit** `.env.local` to git
2. **ALWAYS use** GitHub Secrets for sensitive keys
3. **Public keys** (like NEXT_PUBLIC_*) are safe in client code
4. **Service keys** should ONLY be used server-side
5. **Rotate keys** regularly and update in GitHub Secrets

## After Setup:

Once Claude Code completes the setup, you'll have:
- Next.js app with TypeScript and Tailwind
- Supabase database with 5 core tables
- Repository pattern for database abstraction
- Auth abstraction for provider switching
- Basic dashboard with organization management
- GitHub repository ready for collaboration

Next steps would be:
1. Add Claude API integration for position analysis
2. Add ProPublica API for EIN lookup
3. Deploy to Vercel
4. Start getting user feedback
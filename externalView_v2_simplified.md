# ExternalView v2.0 - Fast Prototype with AWS Migration Path

**GitHub Repository:** https://github.com/vikaspromo/externalView_0.2

## Core Principles

1. **Build abstractions NOW** - Repository pattern, Auth interface (saves months during AWS migration)
2. **Use standard SQL** - No Supabase-specific features (ensures portability)
3. **Basic audit logging** - Simple table for SOC 2 foundation
4. **Simple tenant isolation** - Application-level filtering (good enough for prototype)
5. **Ship in 2 weeks** - Not 2 months

## Quick Start (Day 1-3)

### Day 1: Project Setup

```bash
# Create Next.js app
npx create-next-app@latest externalview-v2 --typescript --tailwind --app --no-src-dir

# Install essentials only
npm install @supabase/supabase-js @anthropic-ai/sdk zod

# Dev dependencies
npm install -D @types/node

# Initialize Supabase
npx supabase init
```

**.env.local (single config file):**
```env
# Supabase (local or cloud)
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key

# APIs
ANTHROPIC_API_KEY=your-claude-key
```

### Day 2: Simple Database Schema

**migrations/001_core.sql:**
```sql
-- Standard PostgreSQL only (works on AWS RDS)

-- 1. Tenants (clients)
CREATE TABLE tenants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Users
CREATE TABLE users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id UUID REFERENCES tenants(id),
  email TEXT NOT NULL,
  auth_user_id UUID UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Organizations
CREATE TABLE organizations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id UUID REFERENCES tenants(id),
  name TEXT NOT NULL,
  ein TEXT,
  website TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Positions
CREATE TABLE positions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  organization_id UUID REFERENCES organizations(id),
  tenant_id UUID REFERENCES tenants(id),
  issue TEXT,
  stance TEXT,
  details TEXT,
  analyzed_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Simple audit log (SOC 2 foundation)
CREATE TABLE audit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  user_id UUID,
  tenant_id UUID,
  action TEXT,
  table_name TEXT,
  record_id UUID,
  metadata JSONB
);

-- Basic indexes
CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_orgs_tenant ON organizations(tenant_id);
CREATE INDEX idx_positions_tenant ON positions(tenant_id);
CREATE INDEX idx_audit_tenant ON audit_log(tenant_id, timestamp);
```

### Day 3: Critical Abstractions (MUST HAVE)

**lib/db/repository.ts (THE KEY TO AWS MIGRATION):**
```typescript
// Generic repository interface - works with ANY database
export interface Repository<T> {
  findAll(filter?: Partial<T>): Promise<T[]>
  findById(id: string): Promise<T | null>
  create(data: Partial<T>): Promise<T>
  update(id: string, data: Partial<T>): Promise<T>
  delete(id: string): Promise<void>
}

// Supabase implementation
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

export class SupabaseRepository<T> implements Repository<T> {
  constructor(private table: string) {}
  
  async findAll(filter?: Partial<T>): Promise<T[]> {
    let query = supabase.from(this.table).select('*')
    if (filter) {
      Object.entries(filter).forEach(([key, value]) => {
        query = query.eq(key, value)
      })
    }
    const { data } = await query
    return data || []
  }
  
  async findById(id: string): Promise<T | null> {
    const { data } = await supabase
      .from(this.table)
      .select('*')
      .eq('id', id)
      .single()
    return data
  }
  
  async create(data: Partial<T>): Promise<T> {
    const { data: result } = await supabase
      .from(this.table)
      .insert(data)
      .select()
      .single()
    return result
  }
  
  async update(id: string, data: Partial<T>): Promise<T> {
    const { data: result } = await supabase
      .from(this.table)
      .update(data)
      .eq('id', id)
      .select()
      .single()
    return result
  }
  
  async delete(id: string): Promise<void> {
    await supabase.from(this.table).delete().eq('id', id)
  }
}
```

**lib/db/index.ts (Single switch point for AWS):**
```typescript
import { SupabaseRepository } from './repository'

// When moving to AWS, just change these to PostgresRepository
export const db = {
  tenants: new SupabaseRepository('tenants'),
  users: new SupabaseRepository('users'),
  organizations: new SupabaseRepository('organizations'),
  positions: new SupabaseRepository('positions'),
  audit: new SupabaseRepository('audit_log'),
}
```

**lib/auth/index.ts (Auth abstraction):**
```typescript
interface AuthUser {
  id: string
  email: string
  tenant_id?: string
}

// Supabase auth (swap for Cognito later)
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export async function getCurrentUser(): Promise<AuthUser | null> {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null
  
  // Get tenant from users table
  const { data } = await db.users.findOne({ auth_user_id: user.id })
  return {
    id: user.id,
    email: user.email!,
    tenant_id: data?.tenant_id
  }
}

export async function getTenantId(): Promise<string | null> {
  const user = await getCurrentUser()
  return user?.tenant_id || null
}
```

## Core Features (Day 4-7)

### Day 4: Simple Tenant Context

**lib/tenant.ts:**
```typescript
// Simple tenant filtering (no complex RLS needed)
export async function getTenantData<T>(
  repo: Repository<T>,
  additionalFilter?: Partial<T>
): Promise<T[]> {
  const tenantId = await getTenantId()
  if (!tenantId) throw new Error('No tenant context')
  
  return repo.findAll({
    ...additionalFilter,
    tenant_id: tenantId
  } as Partial<T>)
}

// Audit logging helper
export async function logAction(
  action: string,
  table: string,
  recordId?: string,
  metadata?: any
) {
  const user = await getCurrentUser()
  await db.audit.create({
    user_id: user?.id,
    tenant_id: user?.tenant_id,
    action,
    table_name: table,
    record_id: recordId,
    metadata
  })
}
```

### Day 5: Basic Claude Integration

**lib/ai/analyze.ts:**
```typescript
import Anthropic from '@anthropic-ai/sdk'

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY!
})

export async function analyzeOrganization(orgName: string) {
  const response = await anthropic.messages.create({
    model: 'claude-3-haiku-20240307',
    max_tokens: 1000,
    messages: [{
      role: 'user',
      content: `List policy positions for ${orgName}. Return JSON array with: issue, stance, details`
    }]
  })
  
  // Parse and save
  const positions = JSON.parse(response.content[0].text)
  const tenantId = await getTenantId()
  
  for (const pos of positions) {
    await db.positions.create({
      ...pos,
      tenant_id: tenantId,
      analyzed_at: new Date()
    })
  }
  
  // Log for SOC 2
  await logAction('analyze', 'organizations', orgId, { positions: positions.length })
  
  return positions
}
```

### Day 6: ProPublica EIN Lookup (Simple)

**lib/api/propublica.ts:**
```typescript
export async function getOrgEIN(name: string): Promise<string | null> {
  try {
    const res = await fetch(
      `https://projects.propublica.org/nonprofits/api/v2/search.json?q=${encodeURIComponent(name)}`
    )
    const data = await res.json()
    return data.organizations?.[0]?.ein || null
  } catch {
    return null
  }
}
```

### Day 7: Minimal UI

**app/dashboard/page.tsx:**
```typescript
export default async function Dashboard() {
  const orgs = await getTenantData(db.organizations)
  
  return (
    <div className="p-6">
      <h1 className="text-2xl mb-4">Organizations</h1>
      
      <form action={createOrg} className="mb-4">
        <input name="name" placeholder="Organization name" className="border p-2" />
        <button type="submit" className="bg-blue-500 text-white p-2">Add</button>
      </form>
      
      <div className="space-y-2">
        {orgs.map(org => (
          <div key={org.id} className="border p-4">
            <h3>{org.name}</h3>
            <p>EIN: {org.ein || 'Not found'}</p>
            <button onClick={() => analyzeOrganization(org.name)}>
              Analyze Positions
            </button>
          </div>
        ))}
      </div>
    </div>
  )
}

async function createOrg(formData: FormData) {
  const name = formData.get('name') as string
  const ein = await getOrgEIN(name)
  const tenantId = await getTenantId()
  
  await db.organizations.create({
    name,
    ein,
    tenant_id: tenantId
  })
  
  await logAction('create', 'organizations')
}
```

## Deployment (Day 8)

```bash
# Push to GitHub
git init
git add .
git commit -m "Initial prototype"
git push

# Deploy to Vercel
vercel

# Add env vars in Vercel dashboard
```

## AWS Migration Path (When Ready)

### What Changes (5 files only):

1. **lib/db/repository.ts** - Add PostgresRepository class
2. **lib/db/index.ts** - Switch to PostgresRepository
3. **lib/auth/index.ts** - Switch to Cognito
4. **.env** - Update connection strings
5. **package.json** - Add pg and AWS SDK

### What Stays the Same:
- All business logic
- All UI components
- All API routes
- All data models

### Migration Steps:
```bash
# 1. Export data
pg_dump $SUPABASE_URL > backup.sql

# 2. Import to RDS
psql $RDS_URL < backup.sql

# 3. Update repository (lib/db/index.ts)
export const db = {
  organizations: new PostgresRepository('organizations'), // was SupabaseRepository
  // ... etc
}

# 4. Deploy
```

## What We Skipped (Add Later on AWS)

1. **Complex RLS** - Using simple tenant filtering for now
2. **Job Queues** - Direct function calls for now
3. **Multi-environment** - One Supabase project is fine
4. **CI/CD** - Manual deployment is fine for prototype
5. **Monitoring** - Console.log is enough
6. **Rate Limiting** - Not needed yet
7. **Caching** - Not needed yet
8. **Error Handling** - Basic try/catch only

## SOC 2 Foundation (Built In)

Even in this simplified version, we have:
1. **Audit logging** - Every action logged
2. **Tenant isolation** - Data separated by tenant_id
3. **User tracking** - Know who did what
4. **Timestamps** - Know when things happened

## Why This Works

- **2 weeks to production** instead of 2 months
- **~400 lines of code** instead of 4000
- **5 files to change** for AWS migration (not 500)
- **SOC 2 ready** from day one
- **Works today** with room to grow

## Next Steps After MVP

1. Get user feedback
2. Add features users actually want
3. Plan AWS migration when you have revenue
4. Add complexity only when needed
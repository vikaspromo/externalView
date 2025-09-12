# ExternalView v2.0 - Simplified Prototype Plan with AWS Migration Path

**GitHub Repository:** https://github.com/vikaspromo/externalView_0.2

## Project Context

ExternalView is a **multi-tenant stakeholder intelligence platform** that helps organizations track and analyze policy positions. This plan prioritizes:
1. **Rapid prototype development** (2 weeks to production)
2. **Future AWS migration** (clean abstraction layers)
3. **Tolerance for downtime** during development phase

### Core Business Requirements

1. **Multi-tenant SaaS platform** where clients log in to view AI-generated summaries of their public policy statements
2. **External organization policy tracking** - monitoring positions from trade associations, industry groups, etc.
3. **Policy alignment matching** - identifying thematic similarities between client and third-party positions
4. **Financial & relationship management** - track investments, membership dues, sponsorships with renewal monitoring
5. **SOC 2 compliance readiness** - will be critical for enterprise clients (add during AWS migration)

## Simplified Prototype Architecture (2 Weeks Total)

### Week 1: Foundation with Abstractions (3 Days)

#### Day 1: Project Setup

```bash
# Create Next.js app with TypeScript
npx create-next-app@latest stakeholder-intelligence --typescript --tailwind --app --no-src-dir

# Core dependencies
npm install @supabase/supabase-js @supabase/auth-helpers-nextjs
npm install @anthropic-ai/sdk
npm install zod  # For validation

# Dev dependencies
npm install -D @types/node eslint prettier

# Initialize Supabase (one project for prototype)
npx supabase init
npx supabase link --project-ref [your-project-ref]
```

**Environment Configuration (.env.local):**
```env
# Supabase (one project for prototype)
NEXT_PUBLIC_SUPABASE_URL=https://[project].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=[anon-key]
SUPABASE_SERVICE_KEY=[service-key]

# External APIs
ANTHROPIC_API_KEY=[your-claude-key]

# Environment flag
NEXT_PUBLIC_ENVIRONMENT=development
```

#### Day 2: Database Schema (Simple, No RLS)

**Create migration: 001_initial_schema.sql**
```sql
-- Use standard PostgreSQL only (no Supabase-specific features)
-- This ensures easy migration to AWS RDS

-- Core tables
CREATE TABLE tenants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  auth_user_id UUID UNIQUE NOT NULL,  -- Links to Supabase auth
  email TEXT NOT NULL,
  role TEXT DEFAULT 'viewer',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE organizations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  name TEXT NOT NULL,
  type TEXT,
  website TEXT,
  ein TEXT,
  metadata JSONB,  -- Store ProPublica data (address, revenue, assets, etc.)
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE organization_positions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations(id),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  issue_category TEXT NOT NULL,
  issue_description TEXT NOT NULL,
  stance TEXT,
  position_details TEXT,
  confidence_score DECIMAL(3,2),
  source_urls TEXT[],
  analyzed_at TIMESTAMPTZ DEFAULT NOW(),
  analyzed_by TEXT  -- 'claude-3-haiku' or user id
);

CREATE TABLE client_org_relationships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  relationship_type TEXT NOT NULL,
  annual_investment DECIMAL(12,2),
  renewal_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Basic indexes for performance
CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_auth ON users(auth_user_id);
CREATE INDEX idx_orgs_tenant ON organizations(tenant_id);
CREATE INDEX idx_positions_org ON organization_positions(organization_id);
CREATE INDEX idx_positions_tenant ON organization_positions(tenant_id);
CREATE INDEX idx_relationships_tenant ON client_org_relationships(tenant_id);

-- Note: No RLS policies - handle in application layer for prototype
```

#### Day 3: Critical Data Abstraction Layer

This is THE MOST IMPORTANT part for AWS migration. Build this correctly now to save months later.

**Project Structure:**
```
stakeholder-intelligence/
├── lib/
│   ├── db/
│   │   ├── types.ts          # Shared types
│   │   ├── repository.ts     # Repository interface
│   │   ├── supabase/        
│   │   │   └── supabase-repository.ts  # Supabase implementation
│   │   └── index.ts          # THE SWITCH POINT for AWS migration
│   ├── auth/
│   │   ├── auth-provider.ts  # Auth interface
│   │   ├── supabase-auth.ts  # Supabase implementation
│   │   └── index.ts          # Export current provider
│   └── storage/
│       ├── storage-provider.ts  # Storage interface
│       ├── supabase-storage.ts  # Supabase implementation
│       └── index.ts             # Export current provider
```

**lib/db/types.ts:**
```typescript
export interface Tenant {
  id: string
  name: string
  slug: string
  created_at: Date
}

export interface Organization {
  id: string
  tenant_id: string
  name: string
  type?: string
  website?: string
  ein?: string
  metadata?: {
    city?: string
    state?: string
    address?: string
    assets?: number
    revenue?: number
    ntee_code?: string
    tax_period?: string
  }
  created_at: Date
}

export interface Position {
  id: string
  organization_id: string
  tenant_id: string
  issue_category: string
  issue_description: string
  stance?: string
  position_details?: string
  confidence_score?: number
  source_urls?: string[]
  analyzed_at: Date
  analyzed_by?: string
}
```

**lib/db/repository.ts:**
```typescript
// Generic repository interface - works with any database
export interface Repository<T> {
  findAll(filter?: Partial<T>): Promise<T[]>
  findById(id: string): Promise<T | null>
  findOne(filter: Partial<T>): Promise<T | null>
  create(data: Omit<T, 'id' | 'created_at'>): Promise<T>
  update(id: string, data: Partial<T>): Promise<T>
  delete(id: string): Promise<void>
}
```

**lib/db/supabase/supabase-repository.ts:**
```typescript
import { createClient } from '@supabase/supabase-js'
import { Repository } from '../repository'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

export class SupabaseRepository<T extends { id: string }> implements Repository<T> {
  constructor(private tableName: string) {}
  
  async findAll(filter?: Partial<T>): Promise<T[]> {
    let query = supabase.from(this.tableName).select('*')
    
    if (filter) {
      Object.entries(filter).forEach(([key, value]) => {
        if (value !== undefined) {
          query = query.eq(key, value)
        }
      })
    }
    
    const { data, error } = await query
    if (error) throw new Error(`Failed to fetch ${this.tableName}: ${error.message}`)
    return data || []
  }
  
  async findById(id: string): Promise<T | null> {
    const { data, error } = await supabase
      .from(this.tableName)
      .select('*')
      .eq('id', id)
      .single()
    
    if (error && error.code !== 'PGRST116') {
      throw new Error(`Failed to fetch ${this.tableName}: ${error.message}`)
    }
    return data
  }
  
  async findOne(filter: Partial<T>): Promise<T | null> {
    let query = supabase.from(this.tableName).select('*')
    
    Object.entries(filter).forEach(([key, value]) => {
      if (value !== undefined) {
        query = query.eq(key, value)
      }
    })
    
    const { data, error } = await query.limit(1).single()
    
    if (error && error.code !== 'PGRST116') {
      throw new Error(`Failed to fetch ${this.tableName}: ${error.message}`)
    }
    return data
  }
  
  async create(data: Omit<T, 'id' | 'created_at'>): Promise<T> {
    const { data: result, error } = await supabase
      .from(this.tableName)
      .insert(data)
      .select()
      .single()
    
    if (error) throw new Error(`Failed to create ${this.tableName}: ${error.message}`)
    return result
  }
  
  async update(id: string, data: Partial<T>): Promise<T> {
    const { data: result, error } = await supabase
      .from(this.tableName)
      .update(data)
      .eq('id', id)
      .select()
      .single()
    
    if (error) throw new Error(`Failed to update ${this.tableName}: ${error.message}`)
    return result
  }
  
  async delete(id: string): Promise<void> {
    const { error } = await supabase
      .from(this.tableName)
      .delete()
      .eq('id', id)
    
    if (error) throw new Error(`Failed to delete ${this.tableName}: ${error.message}`)
  }
}
```

**lib/db/index.ts (THE CRITICAL SWITCH POINT):**
```typescript
import { SupabaseRepository } from './supabase/supabase-repository'
import { Tenant, Organization, Position } from './types'

// When migrating to AWS, you only need to change this file!
// Replace SupabaseRepository with PostgresRepository

export const db = {
  tenants: new SupabaseRepository<Tenant>('tenants'),
  users: new SupabaseRepository<User>('users'),
  organizations: new SupabaseRepository<Organization>('organizations'),
  positions: new SupabaseRepository<Position>('organization_positions'),
  relationships: new SupabaseRepository<Relationship>('client_org_relationships'),
}

// Helper functions that work with any repository implementation
export async function getTenantOrganizations(tenantId: string) {
  return db.organizations.findAll({ tenant_id: tenantId })
}

export async function getOrganizationPositions(orgId: string) {
  return db.positions.findAll({ organization_id: orgId })
}
```

### Week 2: Core Features (4 Days)

#### Day 4-5: Authentication & Tenant Context

**lib/auth/auth-provider.ts:**
```typescript
export interface User {
  id: string
  email: string
  tenant_id?: string
}

export interface AuthProvider {
  signIn(email: string, password: string): Promise<User>
  signUp(email: string, password: string): Promise<User>
  signOut(): Promise<void>
  getCurrentUser(): Promise<User | null>
}
```

**lib/auth/supabase-auth.ts:**
```typescript
import { createClient } from '@supabase/supabase-js'
import { AuthProvider, User } from './auth-provider'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export class SupabaseAuth implements AuthProvider {
  async signIn(email: string, password: string): Promise<User> {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })
    
    if (error) throw error
    
    // Get tenant info
    const { data: userData } = await supabase
      .from('users')
      .select('id, tenant_id')
      .eq('auth_user_id', data.user.id)
      .single()
    
    return {
      id: data.user.id,
      email: data.user.email!,
      tenant_id: userData?.tenant_id,
    }
  }
  
  async getCurrentUser(): Promise<User | null> {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return null
    
    const { data: userData } = await supabase
      .from('users')
      .select('id, tenant_id')
      .eq('auth_user_id', user.id)
      .single()
    
    return {
      id: user.id,
      email: user.email!,
      tenant_id: userData?.tenant_id,
    }
  }
  
  async signOut(): Promise<void> {
    await supabase.auth.signOut()
  }
}
```

**lib/auth/index.ts:**
```typescript
import { SupabaseAuth } from './supabase-auth'

// Export current auth provider (change this for AWS Cognito later)
export const auth = new SupabaseAuth()

// Helper to get current tenant (works with any auth provider)
export async function getCurrentTenantId(): Promise<string | null> {
  const user = await auth.getCurrentUser()
  return user?.tenant_id || null
}
```

**lib/auth/tenant-context.ts:**
```typescript
// Simple tenant context management
export async function withTenantContext<T>(
  operation: (tenantId: string) => Promise<T>
): Promise<T> {
  const tenantId = await getCurrentTenantId()
  if (!tenantId) {
    throw new Error('No tenant context available')
  }
  return operation(tenantId)
}

// Use in API routes and server components
export async function getTenantOrganizations() {
  return withTenantContext(async (tenantId) => {
    return db.organizations.findAll({ tenant_id: tenantId })
  })
}
```

#### Day 6: ProPublica API Integration for Organization Metadata

**lib/api/propublica-client.ts:**
```typescript
// ProPublica API client for fetching organization metadata
interface ProPublicaOrganization {
  ein: string
  name: string
  city: string
  state: string
  country: string
  address: string
  subsection_code: string
  ruling_date: string
  tax_period: string
  assets: number
  income: number
  revenue: number
  ntee_code: string
  organization_type: string
}

export async function searchProPublicaOrganization(
  searchTerm: string
): Promise<ProPublicaOrganization | null> {
  try {
    // ProPublica Nonprofit Explorer API
    const baseUrl = 'https://projects.propublica.org/nonprofits/api/v2'
    
    // Search for organization
    const searchResponse = await fetch(
      `${baseUrl}/search.json?q=${encodeURIComponent(searchTerm)}`
    )
    
    if (!searchResponse.ok) {
      console.error('ProPublica search failed:', searchResponse.status)
      return null
    }
    
    const searchData = await searchResponse.json()
    
    if (!searchData.organizations || searchData.organizations.length === 0) {
      console.log('No organizations found for:', searchTerm)
      return null
    }
    
    // Get the first match
    const org = searchData.organizations[0]
    
    // Fetch detailed information
    const detailResponse = await fetch(
      `${baseUrl}/organizations/${org.ein}.json`
    )
    
    if (!detailResponse.ok) {
      console.error('ProPublica detail fetch failed:', detailResponse.status)
      return null
    }
    
    const detailData = await detailResponse.json()
    
    return {
      ein: detailData.organization.ein,
      name: detailData.organization.name,
      city: detailData.organization.city,
      state: detailData.organization.state,
      country: detailData.organization.country || 'USA',
      address: detailData.organization.address,
      subsection_code: detailData.organization.subsection_code,
      ruling_date: detailData.organization.ruling_date,
      tax_period: detailData.organization.tax_period,
      assets: detailData.organization.assets,
      income: detailData.organization.income,
      revenue: detailData.organization.revenue,
      ntee_code: detailData.organization.ntee_code,
      organization_type: determineOrgType(detailData.organization),
    }
  } catch (error) {
    console.error('ProPublica API error:', error)
    return null
  }
}

function determineOrgType(org: any): string {
  // Determine organization type based on NTEE code
  const nteeCode = org.ntee_code?.charAt(0)
  
  switch (nteeCode) {
    case 'A': return 'arts_culture'
    case 'B': return 'education'
    case 'C': case 'D': return 'environment'
    case 'E': case 'F': case 'G': case 'H': return 'health'
    case 'I': case 'J': case 'K': case 'L': case 'M': case 'N': case 'O': case 'P': return 'human_services'
    case 'Q': return 'international'
    case 'R': case 'S': case 'T': case 'U': case 'V': case 'W': return 'public_benefit'
    case 'X': return 'religion'
    case 'Y': return 'mutual_benefit'
    default: return 'nonprofit'
  }
}

// Enhanced organization creation with ProPublica data
export async function createOrganizationWithMetadata(
  name: string,
  tenantId: string,
  website?: string
): Promise<Organization> {
  // First, try to get metadata from ProPublica
  const propublicaData = await searchProPublicaOrganization(name)
  
  // Create organization with enriched data
  const organization = await db.organizations.create({
    tenant_id: tenantId,
    name: propublicaData?.name || name,
    type: propublicaData?.organization_type || 'unknown',
    website: website || `https://www.google.com/search?q=${encodeURIComponent(name)}`,
    ein: propublicaData?.ein || null,
    // Store additional metadata in a JSON field if needed
    metadata: propublicaData ? {
      city: propublicaData.city,
      state: propublicaData.state,
      address: propublicaData.address,
      assets: propublicaData.assets,
      revenue: propublicaData.revenue,
      ntee_code: propublicaData.ntee_code,
      tax_period: propublicaData.tax_period,
    } : null,
  })
  
  return organization
}

// Batch update existing organizations with ProPublica data
export async function enrichOrganizationsWithProPublica(
  tenantId: string
): Promise<{ updated: number; failed: number }> {
  const organizations = await db.organizations.findAll({ tenant_id: tenantId })
  
  let updated = 0
  let failed = 0
  
  for (const org of organizations) {
    // Skip if already has EIN
    if (org.ein) continue
    
    // Rate limit: ProPublica recommends max 100 requests per minute
    await new Promise(resolve => setTimeout(resolve, 1000))
    
    const propublicaData = await searchProPublicaOrganization(org.name)
    
    if (propublicaData) {
      try {
        await db.organizations.update(org.id, {
          ein: propublicaData.ein,
          type: propublicaData.organization_type,
          metadata: {
            city: propublicaData.city,
            state: propublicaData.state,
            address: propublicaData.address,
            assets: propublicaData.assets,
            revenue: propublicaData.revenue,
            ntee_code: propublicaData.ntee_code,
            tax_period: propublicaData.tax_period,
          },
        })
        updated++
      } catch (error) {
        console.error(`Failed to update org ${org.id}:`, error)
        failed++
      }
    }
  }
  
  return { updated, failed }
}
```

#### Day 7: Claude Integration (Direct, No Job Queue)

**lib/ai/claude-client.ts:**
```typescript
import Anthropic from '@anthropic-ai/sdk'

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY!,
})

export async function analyzeOrganizationPositions(
  orgName: string,
  orgWebsite?: string
): Promise<Position[]> {
  const prompt = `
    Analyze the public policy positions of ${orgName}.
    ${orgWebsite ? `Website: ${orgWebsite}` : ''}
    
    Return a JSON array of their positions on key issues:
    [
      {
        "issue_category": "category",
        "issue_description": "specific issue",
        "stance": "support|oppose|neutral",
        "position_details": "their reasoning",
        "confidence_score": 0.0-1.0,
        "source_urls": ["url1", "url2"]
      }
    ]
  `
  
  const response = await anthropic.messages.create({
    model: 'claude-3-haiku-20240307',
    max_tokens: 2000,
    messages: [{
      role: 'user',
      content: prompt,
    }],
  })
  
  // Parse response
  const content = response.content[0]
  if (content.type !== 'text') {
    throw new Error('Unexpected response type')
  }
  
  try {
    const positions = JSON.parse(content.text)
    return positions
  } catch (error) {
    console.error('Failed to parse Claude response:', content.text)
    throw new Error('Failed to parse AI response')
  }
}

// Simple direct function - no job queue needed for prototype
export async function analyzeAndSavePositions(orgId: string) {
  const org = await db.organizations.findById(orgId)
  if (!org) throw new Error('Organization not found')
  
  const positions = await analyzeOrganizationPositions(org.name, org.website)
  
  // Save each position
  for (const position of positions) {
    await db.positions.create({
      organization_id: orgId,
      tenant_id: org.tenant_id,
      ...position,
      analyzed_by: 'claude-3-haiku',
    })
  }
  
  return positions
}
```

#### Day 8: Basic Dashboard UI

**app/dashboard/page.tsx:**
```typescript
import { getTenantOrganizations } from '@/lib/db'
import { AddOrganizationForm } from '@/components/add-organization-form'
import { OrganizationsList } from '@/components/organizations-list'
import { EnrichButton } from '@/components/enrich-button'

export default async function Dashboard() {
  const organizations = await getTenantOrganizations()
  
  return (
    <div className="container mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">
        Stakeholder Intelligence Dashboard
      </h1>
      
      <div className="mb-8 flex gap-4">
        <AddOrganizationForm />
        <EnrichButton />
      </div>
      
      <div>
        <h2 className="text-2xl font-semibold mb-4">
          Organizations ({organizations.length})
        </h2>
        <OrganizationsList organizations={organizations} />
      </div>
    </div>
  )
}
```

**app/api/organizations/route.ts:**
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { createOrganizationWithMetadata } from '@/lib/api/propublica-client'
import { getCurrentTenantId } from '@/lib/auth'

export async function POST(request: NextRequest) {
  try {
    const tenantId = await getCurrentTenantId()
    if (!tenantId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
    
    const { name, website } = await request.json()
    
    // Create organization with ProPublica metadata
    const organization = await createOrganizationWithMetadata(
      name,
      tenantId,
      website
    )
    
    return NextResponse.json(organization)
  } catch (error) {
    console.error('Failed to create organization:', error)
    return NextResponse.json(
      { error: 'Failed to create organization' },
      { status: 500 }
    )
  }
}
```

**app/api/organizations/[id]/analyze/route.ts:**
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { analyzeAndSavePositions } from '@/lib/ai/claude-client'
import { getCurrentTenantId } from '@/lib/auth'

export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    // Simple tenant check
    const tenantId = await getCurrentTenantId()
    if (!tenantId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
    
    // Verify org belongs to tenant
    const org = await db.organizations.findById(params.id)
    if (!org || org.tenant_id !== tenantId) {
      return NextResponse.json({ error: 'Not found' }, { status: 404 })
    }
    
    // Analyze (no job queue, just async)
    const positions = await analyzeAndSavePositions(params.id)
    
    return NextResponse.json({ 
      success: true, 
      positions_found: positions.length 
    })
  } catch (error) {
    console.error('Analysis failed:', error)
    return NextResponse.json(
      { error: 'Analysis failed' },
      { status: 500 }
    )
  }
}
```

**app/api/organizations/enrich/route.ts:**
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { enrichOrganizationsWithProPublica } from '@/lib/api/propublica-client'
import { getCurrentTenantId } from '@/lib/auth'

export async function POST(request: NextRequest) {
  try {
    const tenantId = await getCurrentTenantId()
    if (!tenantId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
    
    // Enrich all organizations for this tenant
    const result = await enrichOrganizationsWithProPublica(tenantId)
    
    return NextResponse.json({
      success: true,
      updated: result.updated,
      failed: result.failed,
    })
  } catch (error) {
    console.error('Enrichment failed:', error)
    return NextResponse.json(
      { error: 'Enrichment failed' },
      { status: 500 }
    )
  }
}
```

## Deployment (Day 9)

### Simple Deployment with Vercel

```bash
# Push to GitHub
git init
git add .
git commit -m "Initial prototype"
git remote add origin [your-repo]
git push -u origin main

# Deploy with Vercel
# 1. Import project from GitHub
# 2. Add environment variables
# 3. Deploy
```

### Environment Variables for Vercel:
```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_KEY
ANTHROPIC_API_KEY
```

## AWS Migration Path (When Ready - 6-12 months)

### Phase 1: Database Migration (4-8 hours downtime acceptable)

#### Step 1: Export from Supabase
```bash
# Export all data
pg_dump $SUPABASE_DATABASE_URL > backup.sql

# Or use Supabase dashboard export
```

#### Step 2: Set up AWS RDS PostgreSQL
```bash
# Create RDS instance
# Import data
psql $RDS_URL < backup.sql
```

#### Step 3: Create PostgreSQL Repository Implementation
```typescript
// lib/db/postgres/postgres-repository.ts
import { Pool } from 'pg'
import { Repository } from '../repository'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
})

export class PostgresRepository<T> implements Repository<T> {
  constructor(private tableName: string) {}
  
  async findAll(filter?: Partial<T>): Promise<T[]> {
    let query = `SELECT * FROM ${this.tableName}`
    const values: any[] = []
    
    if (filter && Object.keys(filter).length > 0) {
      const conditions = Object.entries(filter)
        .filter(([_, value]) => value !== undefined)
        .map(([key, _], index) => `${key} = $${index + 1}`)
      
      if (conditions.length > 0) {
        query += ` WHERE ${conditions.join(' AND ')}`
        values.push(...Object.values(filter).filter(v => v !== undefined))
      }
    }
    
    const result = await pool.query(query, values)
    return result.rows
  }
  
  // Implement other methods...
}
```

#### Step 4: Switch Repository Implementation
```typescript
// lib/db/index.ts - ONLY FILE TO CHANGE!
import { PostgresRepository } from './postgres/postgres-repository'  // was SupabaseRepository

export const db = {
  tenants: new PostgresRepository<Tenant>('tenants'),
  users: new PostgresRepository<User>('users'),
  organizations: new PostgresRepository<Organization>('organizations'),
  positions: new PostgresRepository<Position>('organization_positions'),
  relationships: new PostgresRepository<Relationship>('client_org_relationships'),
}
```

### Phase 2: Authentication Migration (2-4 hours downtime)

#### Step 1: Set up AWS Cognito
```bash
# Create Cognito User Pool
# Migrate users (export from Supabase Auth, import to Cognito)
```

#### Step 2: Create Cognito Auth Implementation
```typescript
// lib/auth/cognito-auth.ts
import { CognitoIdentityProviderClient } from '@aws-sdk/client-cognito-identity-provider'
import { AuthProvider, User } from './auth-provider'

export class CognitoAuth implements AuthProvider {
  private client = new CognitoIdentityProviderClient({
    region: process.env.AWS_REGION,
  })
  
  async signIn(email: string, password: string): Promise<User> {
    // Implement Cognito sign in
  }
  
  async getCurrentUser(): Promise<User | null> {
    // Implement get current user from Cognito
  }
}
```

#### Step 3: Switch Auth Provider
```typescript
// lib/auth/index.ts - ONLY FILE TO CHANGE!
import { CognitoAuth } from './cognito-auth'  // was SupabaseAuth

export const auth = new CognitoAuth()
```

### Phase 3: Add Enterprise Features (Post-Migration)

Once on AWS, add the features we skipped in the prototype:

#### 1. Row Level Security (RLS)
```typescript
// Add to PostgresRepository
async findAll(filter?: Partial<T>): Promise<T[]> {
  const tenantId = await getCurrentTenantId()
  // Always filter by tenant
  const query = `SELECT * FROM ${this.tableName} WHERE tenant_id = $1`
  // ...
}
```

#### 2. Comprehensive Audit Logging
```sql
-- Add audit table
CREATE TABLE audit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  user_id UUID,
  tenant_id UUID,
  action TEXT,
  table_name TEXT,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address INET
);

-- Add triggers to all tables
CREATE TRIGGER audit_trigger_organizations
  AFTER INSERT OR UPDATE OR DELETE ON organizations
  FOR EACH ROW EXECUTE FUNCTION audit_function();
```

#### 3. Background Job Queue (AWS SQS + Lambda)
```typescript
// lib/jobs/sqs-queue.ts
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs'

export async function queueAnalysisJob(orgId: string) {
  const client = new SQSClient({ region: process.env.AWS_REGION })
  
  await client.send(new SendMessageCommand({
    QueueUrl: process.env.ANALYSIS_QUEUE_URL,
    MessageBody: JSON.stringify({
      type: 'analyze-organization',
      orgId,
      tenantId: await getCurrentTenantId(),
    }),
  }))
}

// Lambda function processes these jobs
```

#### 4. Advanced Monitoring (CloudWatch + Datadog)
```typescript
// lib/monitoring/cloudwatch.ts
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch'

export async function trackMetric(name: string, value: number) {
  const client = new CloudWatchClient({ region: process.env.AWS_REGION })
  
  await client.send(new PutMetricDataCommand({
    Namespace: 'ExternalView',
    MetricData: [{
      MetricName: name,
      Value: value,
      Timestamp: new Date(),
    }],
  }))
}
```

#### 5. Multi-Environment Setup
```bash
# Separate AWS accounts or VPCs for:
- Development
- Staging  
- Production

# Infrastructure as Code with Terraform
terraform/
  ├── environments/
  │   ├── dev/
  │   ├── staging/
  │   └── prod/
  └── modules/
      ├── rds/
      ├── cognito/
      └── lambda/
```

#### 6. Zero-Downtime Deployments
```yaml
# Use AWS CodeDeploy with Blue/Green deployments
# Or ECS with rolling updates
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "arn:aws:ecs:task-definition"
        LoadBalancerInfo:
          ContainerName: "app"
          ContainerPort: 3000
```

#### 7. Advanced Rate Limiting (AWS API Gateway)
```yaml
# API Gateway rate limiting
RateLimits:
  - Resource: /api/v1/*
    Limit: 1000
    Period: MINUTE
    BurstLimit: 2000
```

#### 8. Data Encryption at Rest
```typescript
// Enable RDS encryption
// Enable S3 encryption for file storage
// Use AWS KMS for key management
```

#### 9. Compliance & SOC 2 Features
```typescript
// Add comprehensive audit logging
// Add data retention policies
// Add privacy consent management
// Add GDPR compliance tools
// Add automated compliance reports
```

#### 10. Cost Attribution & Billing
```typescript
// Track detailed usage per tenant
// Integrate with Stripe for billing
// Add usage-based pricing tiers
```

## Migration Timeline

### Months 1-6: Prototype Phase
- Use Supabase for everything
- Focus on product-market fit
- Iterate quickly with user feedback
- Keep architecture simple

### Months 6-12: Preparation Phase
- Start planning AWS architecture
- Set up AWS accounts
- Create Terraform infrastructure
- Build PostgreSQL repository implementation
- Test migration process with dev data

### Month 12: Migration Weekend
- Friday evening: Take backups, notify users
- Saturday: Migrate database to RDS
- Saturday: Update repository implementations
- Sunday: Migrate auth to Cognito
- Sunday: Testing and verification
- Monday: Back online with AWS

### Months 13-18: Enhancement Phase
- Add enterprise features gradually
- Implement zero-downtime deployments
- Add comprehensive monitoring
- Achieve SOC 2 compliance
- Scale to enterprise customers

## Why This Approach Works

### Advantages:
1. **2 weeks to working prototype** instead of 2-3 months
2. **Clean migration path** - change 5-10 files, not 500
3. **Low initial complexity** - one developer can handle everything
4. **Cost-effective** - Supabase free tier during prototype
5. **User feedback early** - iterate based on real usage

### Trade-offs (Acceptable for Prototype):
- No zero-downtime deployments initially
- Basic monitoring only at first
- Simple application-level security (no RLS)
- Manual processes instead of automation
- Single environment instead of dev/staging/prod

## The Critical Success Factors

### Must Have (Day 1):
1. **Repository pattern** - Makes migration possible
2. **Auth abstraction** - Allows auth provider switch
3. **Standard SQL only** - Ensures database portability
4. **Clean interfaces** - Enables implementation swaps

### Can Wait (Add on AWS):
1. Complex RLS policies
2. Job queues
3. Advanced monitoring
4. Multi-environment setup
5. Audit logging
6. Compliance features
7. Zero-downtime deployments

## Quick Reference: File Changes for AWS Migration

When migrating to AWS, you only need to modify these files:

1. **lib/db/index.ts** - Switch to PostgresRepository
2. **lib/auth/index.ts** - Switch to CognitoAuth  
3. **lib/storage/index.ts** - Switch to S3Storage
4. **.env** - Update environment variables
5. **package.json** - Add AWS SDK dependencies

Everything else remains unchanged because of the abstraction layers built on day 1.

## Final Notes

This plan prioritizes:
- **Speed to market** over initial perfection
- **Clean architecture** for future migration
- **Pragmatic choices** over engineering idealism
- **User value** over technical complexity

The abstraction layers are the critical investment that makes everything else possible. Build those right, and the AWS migration becomes a weekend project instead of a multi-month nightmare.
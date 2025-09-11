# Supabase CLI

[![Coverage Status](https://coveralls.io/repos/github/supabase/cli/badge.svg?branch=main)](https://coveralls.io/github/supabase/cli?branch=main) [![Bitbucket Pipelines](https://img.shields.io/bitbucket/pipelines/supabase-cli/setup-cli/master?style=flat-square&label=Bitbucket%20Canary)](https://bitbucket.org/supabase-cli/setup-cli/pipelines) [![Gitlab Pipeline Status](https://img.shields.io/gitlab/pipeline-status/sweatybridge%2Fsetup-cli?label=Gitlab%20Canary)
](https://gitlab.com/sweatybridge/setup-cli/-/pipelines)

[Supabase](https://supabase.io) is an open source Firebase alternative. We're building the features of Firebase using enterprise-grade open source tools.

This repository contains all the functionality for Supabase CLI.

- [x] Running Supabase locally
- [x] Managing database migrations
- [x] Creating and deploying Supabase Functions
- [x] Generating types directly from your database schema
- [x] Making authenticated HTTP requests to [Management API](https://supabase.com/docs/reference/api/introduction)

## Getting started

### Install the CLI

Available via [NPM](https://www.npmjs.com) as dev dependency. To install:

```bash
npm i supabase --save-dev
```

To install the beta release channel:

```bash
npm i supabase@beta --save-dev
```

When installing with yarn 4, you need to disable experimental fetch with the following nodejs config.

```
NODE_OPTIONS=--no-experimental-fetch yarn add supabase
```

> **Note**
For Bun versions below v1.0.17, you must add `supabase` as a [trusted dependency](https://bun.sh/guides/install/trusted) before running `bun add -D supabase`.

<details>
  <summary><b>macOS</b></summary>

  Available via [Homebrew](https://brew.sh). To install:

  ```sh
  brew install supabase/tap/supabase
  ```

  To install the beta release channel:
  
  ```sh
  brew install supabase/tap/supabase-beta
  brew link --overwrite supabase-beta
  ```
  
  To upgrade:

  ```sh
  brew upgrade supabase
  ```
</details>

<details>
  <summary><b>Windows</b></summary>

  Available via [Scoop](https://scoop.sh). To install:

  ```powershell
  scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
  scoop install supabase
  ```

  To upgrade:

  ```powershell
  scoop update supabase
  ```
</details>

<details>
  <summary><b>Linux</b></summary>

  Available via [Homebrew](https://brew.sh) and Linux packages.

  #### via Homebrew

  To install:

  ```sh
  brew install supabase/tap/supabase
  ```

  To upgrade:

  ```sh
  brew upgrade supabase
  ```

  #### via Linux packages

  Linux packages are provided in [Releases](https://github.com/supabase/cli/releases). To install, download the `.apk`/`.deb`/`.rpm`/`.pkg.tar.zst` file depending on your package manager and run the respective commands.

  ```sh
  sudo apk add --allow-untrusted <...>.apk
  ```

  ```sh
  sudo dpkg -i <...>.deb
  ```

  ```sh
  sudo rpm -i <...>.rpm
  ```

  ```sh
  sudo pacman -U <...>.pkg.tar.zst
  ```
</details>

<details>
  <summary><b>Other Platforms</b></summary>

  You can also install the CLI via [go modules](https://go.dev/ref/mod#go-install) without the help of package managers.

  ```sh
  go install github.com/supabase/cli@latest
  ```

  Add a symlink to the binary in `$PATH` for easier access:

  ```sh
  ln -s "$(go env GOPATH)/bin/cli" /usr/bin/supabase
  ```

  This works on other non-standard Linux distros.
</details>

<details>
  <summary><b>Community Maintained Packages</b></summary>

  Available via [pkgx](https://pkgx.sh/). Package script [here](https://github.com/pkgxdev/pantry/blob/main/projects/supabase.com/cli/package.yml).
  To install in your working directory:

  ```bash
  pkgx install supabase
  ```

  Available via [Nixpkgs](https://nixos.org/). Package script [here](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/tools/supabase-cli/default.nix).
</details>

### Run the CLI

```bash
supabase bootstrap
```

Or using npx:

```bash
npx supabase bootstrap
```

The bootstrap command will guide you through the process of setting up a Supabase project using one of the [starter](https://github.com/supabase-community/supabase-samples/blob/main/samples.json) templates.

## Docs

Command & config reference can be found [here](https://supabase.com/docs/reference/cli/about).

## Breaking changes

We follow semantic versioning for changes that directly impact CLI commands, flags, and configurations.

However, due to dependencies on other service images, we cannot guarantee that schema migrations, seed.sql, and generated types will always work for the same CLI major version. If you need such guarantees, we encourage you to pin a specific version of CLI in package.json.

## Developing

To run from source:

```sh
# Go >= 1.22
go run . help
```
# Row Level Security (RLS)

## Executive Summary
We've implemented comprehensive Row Level Security (RLS) policies to ensure complete multi-tenant data isolation. All CRUD operations (Create, Read, Update, Delete) are protected at the database level, preventing any cross-tenant data access or manipulation.

## Core Security Functions

### 1. `user_has_client_access(p_client_uuid UUID)`
- **Purpose**: Validates if a user has access to a specific client's data
- **Returns**: BOOLEAN
- **Volatility**: STABLE (no side effects after fix)
- **Logic**: Checks if user is admin or belongs to the specified client

### 2. `is_admin()`
- **Purpose**: Checks if current user is an admin
- **Returns**: BOOLEAN
- **Volatility**: STABLE
- **Logic**: Verifies auth.uid() exists in user_admins table (uses auth.uid() NOT email to prevent JWT spoofing)

### 3. `get_user_client_uuid()`
- **Purpose**: Returns the client UUID for the current user
- **Returns**: UUID
- **Volatility**: STABLE

### 4. `validate_client_uuid(p_client_uuid UUID)`
- **Purpose**: Validates if a client UUID belongs to current user
- **Returns**: BOOLEAN
- **Volatility**: STABLE

### 5. `prevent_client_uuid_change()`
- **Purpose**: Trigger function to prevent changing client_uuid in updates
- **Returns**: TRIGGER

### 6. `auto_populate_client_uuid()`
- **Purpose**: Automatically sets client_uuid on INSERT
- **Returns**: TRIGGER

## Table-by-Table RLS Policies

### CLIENTS Table
| Operation | Policy | Access Rules |
|-----------|---------|--------------|
| SELECT | `clients_select_policy` | Users see only their assigned client |
| INSERT | `clients_insert_policy` | Only admins can create new clients |
| UPDATE | `clients_update_policy` | Users can update their own client, admins can update any |
| DELETE | `clients_delete_policy` | Only admins can delete clients |

### USERS Table
| Operation | Policy | Access Rules |
|-----------|---------|--------------|
| SELECT | `users_select_policy` | Users can query their own record by ID, see all users in their client, admins see all |
| INSERT | `users_insert_policy` | Admins can create any user, users can self-register |
| UPDATE | `users_update_policy` | Users can update own profile, admins can update anyone, cannot change client_uuid |
| DELETE | `users_delete_policy` | Only admins can delete users |

### CLIENT_ORG_HISTORY Table
| Operation | Policy | Access Rules |
|-----------|---------|--------------|
| SELECT | `client_org_history_select_policy` | Users see only their client's relationships |
| INSERT | `client_org_history_insert_policy` | Users can add orgs to their client only |
| UPDATE | `client_org_history_update_policy` | Users can update their client's relationships, cannot change client_uuid |
| DELETE | `client_org_history_delete_policy` | Users can delete their client's relationships |

### ORGANIZATIONS Table (Master List)
| Operation | Policy | Access Rules |
|-----------|---------|--------------|
| SELECT | `organizations_select_policy` | All authenticated users can view |
| INSERT | `organizations_insert_policy` | Only admins |
| UPDATE | `organizations_update_policy` | Only admins |
| DELETE | `organizations_delete_policy` | Only admins |

### ORG_POSITIONS Table
| Operation | Policy | Access Rules |
|-----------|---------|--------------|
| SELECT | `org_positions_select_policy` | All authenticated users can view |
| INSERT | `org_positions_insert_policy` | Only admins |
| UPDATE | `org_positions_update_policy` | Only admins |
| DELETE | `org_positions_delete_policy` | Only admins |

### STAKEHOLDER_CONTACTS Table
| Operation | Policy | Access Rules |
|-----------|---------|--------------|
| SELECT | `stakeholder_contacts_select_policy` | Users see only their client's contacts |
| INSERT | `stakeholder_contacts_insert_policy` | Auto-populates client_uuid via trigger |
| UPDATE | `stakeholder_contacts_update_policy` | Cannot change client_uuid |
| DELETE | `stakeholder_contacts_delete_policy` | Users can delete their client's contacts |

### STAKEHOLDER_NOTES Table
| Operation | Policy | Access Rules |
|-----------|---------|--------------|
| SELECT | `stakeholder_notes_select_policy` | Users see only their client's notes |
| INSERT | `stakeholder_notes_insert_policy` | Auto-populates client_uuid via trigger |
| UPDATE | `stakeholder_notes_update_policy` | Cannot change client_uuid |
| DELETE | `stakeholder_notes_delete_policy` | Users can delete their client's notes |

### USER_ADMINS Table
| Operation | Policy | Access Rules |
|-----------|---------|--------------|
| SELECT | Only admins can read audit logs | Only admins using auth.uid() |
| INSERT | N/A | Managed by super admin |
| UPDATE | N/A | Managed by super admin |
| DELETE | N/A | Managed by super admin |

### SECURITY_AUDIT_LOG Table
| Operation | Policy | Access Rules |
|-----------|---------|--------------|
| SELECT | Only admins can read audit logs | Only admins |
| INSERT | Via functions only | System-generated only |
| UPDATE | N/A | Immutable log |
| DELETE | N/A | Immutable log |

## Security Features Implemented

### 1. Multi-Tenant Isolation
- ✅ Complete data isolation between clients
- ✅ No cross-tenant data visibility or modification
- ✅ Enforced at database level (cannot be bypassed by application)

### 2. JWT Vulnerability Fix
- ✅ Removed email-based authentication (JWT email claims can be forged)
- ✅ All admin checks use `auth.uid()` (cryptographically secure)
- ✅ Admin accounts linked to auth.users via foreign key

### 3. Audit Trail
- ✅ Security audit log table tracks access attempts
- ✅ Failed cross-tenant access attempts logged
- ✅ Admin access logged for compliance
- ✅ Audit logs are immutable

### 4. Soft Deletes
- ✅ `deleted_at` timestamps on all tables
- ✅ Data retained for audit/recovery
- ✅ Deleted records hidden from normal queries

### 5. Automatic Client Association
- ✅ Triggers auto-populate `client_uuid` on INSERT
- ✅ Prevents manual client_uuid manipulation
- ✅ Reduces human error in data assignment

### 6. Rate Limiting
- ✅ `is_rate_limited()` function for checking request rates
- ✅ Prevents abuse and DoS attempts
- ✅ Configurable limits per user

## Migration History

1. **20250910000000_create_base_tables.sql** - Initial table structure with RLS enabled
2. **20250910000001_create_user_admins_table.sql** - Admin management system with auth.uid() verification
3. **20250910000002_add_active_column_to_users.sql** - User status tracking
4. **20250910000003_fix_jwt_vulnerability_fixed.sql** - Critical security fix replacing email-based auth
5. **20250910000004_comprehensive_rls_policies.sql** - Complete CRUD policies for all tables
6. **20250910000005_fix_rls_volatile_function.sql** - Fixed STABLE function violations
7. **20250910000006_fix_users_self_select.sql** - Allow users to query own record by ID

## Security Checklist

- [x] All tables have RLS enabled
- [x] Complete CRUD policies on all tables
- [x] No cross-tenant data access possible
- [x] JWT vulnerability patched
- [x] Admin access uses secure auth.uid()
- [x] Audit logging implemented
- [x] Soft deletes for data recovery
- [x] Auto-population of client_uuid
- [x] Rate limiting available
- [x] All functions are STABLE (no side effects in RLS)
- [x] Triggers prevent client_uuid changes
- [x] Users can self-query by ID

## Critical Security Notes

1. **Never use email for authentication** - JWT email claims can be forged
2. **Always use auth.uid()** - Cryptographically secure user identification
3. **RLS functions must be STABLE** - No INSERT/UPDATE/DELETE operations
4. **Client UUID is immutable** - Once set, cannot be changed (prevents data theft)
5. **Admins have full access** - Admin accounts must be carefully managed

## Performance Considerations

1. **Indexes on all foreign keys** - Optimizes RLS policy checks
2. **Partial indexes for soft deletes** - `WHERE deleted_at IS NULL`
3. **STABLE functions cached** - Within transaction for performance
4. **Bulk operations supported** - RLS doesn't significantly impact performance

# Testing

## RLS Policy Testing

### Quick Start

#### Option 1: Automated Testing (Recommended)
```bash
# Run the automated test suite
./run-rls-tests.sh
```

This script will:
1. Start Supabase if not running
2. Apply all migrations
3. Run comprehensive tests
4. Report results

#### Option 2: Manual SQL Testing
```bash
# Start Supabase
npx supabase start

# Reset database with migrations
npx supabase db reset

# Run SQL test suite
psql "postgresql://postgres:postgres@localhost:54322/postgres" \
  -f supabase/tests/test_rls_policies.sql
```

#### Option 3: JavaScript Integration Testing
```bash
# Install dependencies
npm install @supabase/supabase-js dotenv

# Set up environment variables
cp .env.example .env.test
# Edit .env.test with your Supabase keys from http://localhost:54323

# Run JavaScript tests
node test-rls-policies.js
```

### What Gets Tested

1. **INSERT Protection** ✅ - Users cannot insert data for other tenants
2. **UPDATE Protection** ✅ - Users cannot change client_uuid to another tenant
3. **DELETE Protection** ✅ - Users cannot delete other tenant's data
4. **SELECT Isolation** ✅ - Users only see their own tenant's data
5. **Admin Bypass** ✅ - Admins can access all tenant data
6. **Performance** ✅ - Bulk operations tested

### Expected Test Results

When all tests pass, you should see:
```
✓ Prevent insert for different client
✓ Allow insert for own client
✓ Prevent client_uuid change
✓ Allow updating other fields
✓ Prevent deleting other client data
✓ Cannot see other client data
✓ Can see own client data
✓ Auto-populate client_uuid on insert
✓ Soft delete sets deleted_at
✓ Soft deleted records hidden

TEST SUMMARY
============
Passed: 10
Failed: 0
Total:  10

✓ All tests passed! RLS policies are working correctly.
```

### Manual Verification via Supabase Studio

1. **Open Supabase Studio**
   ```bash
   npx supabase studio
   ```
   Opens at: http://localhost:54323

2. **Create Test Users** - Go to Authentication → Users
3. **Test Cross-Tenant Access** - Use SQL Editor with different user contexts

### Troubleshooting

#### Issue: Supabase won't start
```bash
# Stop all containers
npx supabase stop --project-id externalView

# Start fresh
npx supabase start
```

#### Issue: Migrations fail
```bash
# Check migration order
ls -la supabase/migrations/

# Apply manually if needed
psql "postgresql://postgres:postgres@localhost:54322/postgres" \
  -f supabase/migrations/[migration_file].sql
```

#### Issue: Tests fail with auth errors
- Check your Supabase keys in `.env.test`
- Get fresh keys from: http://localhost:54323/project/default/settings/api

#### Issue: Policies not working
```sql
-- Check installed policies
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename;

-- Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';
```

### Production Deployment

Before deploying to production:

1. **Run full test suite**
   ```bash
   ./run-rls-tests.sh
   ```

2. **Review migration order**
   ```bash
   ls -la supabase/migrations/
   ```

3. **Push to production**
   ```bash
   npx supabase db push
   ```

4. **Verify in production** - Create test accounts, verify tenant isolation, check performance

# Project Structure

## Components Directory Structure

### Organization

- **`/ui`** - Reusable UI components (buttons, tables, modals, etc.)
  - Generic, presentation-focused components
  - No business logic
  - Highly reusable across the application

- **`/dashboard`** - Dashboard-specific components
  - Business logic specific to dashboard functionality
  - May use UI components internally
  - Not intended for reuse outside dashboard context

- **`/auth`** - Authentication-related components
  - Login forms, auth guards, etc.
  - Handles authentication UI/UX

### Component Guidelines

1. Each component should have a single responsibility
2. Use TypeScript interfaces for all props
3. Include JSDoc comments for complex components
4. Keep components small and focused
5. Extract shared logic into custom hooks
6. Use composition over inheritance

### Naming Conventions

- Components: PascalCase (e.g., `Button.tsx`)
- Directories: lowercase (e.g., `/ui`)
- Index files for barrel exports when appropriate

# Security

## Reporting a Vulnerability

To report a security vulnerability, please follow the project's security reporting process. All security issues should be reported privately to maintain the safety of users while fixes are developed and deployed.

# Support & Maintenance

- **Migration Rollback**: Each migration has corresponding rollback
- **Testing**: Run `/run-rls-tests.sh` after any RLS changes
- **Monitoring**: Check security_audit_log for suspicious activity
- **Updates**: Always test in development before production

# Last updated: Sun Sep  7 02:12:42 UTC 2025

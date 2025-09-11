# Security Documentation

## 🔐 CRITICAL SECURITY NOTICE: Supabase Key Rotation Required

**IMMEDIATE ACTION REQUIRED**: If you're seeing this after January 11, 2025, the Supabase keys must be rotated immediately.

### Why This Is Critical
- Production Supabase keys were previously committed to Git history
- Service Role keys provide full database admin access
- Keys may have been exposed to unauthorized parties
- Immediate rotation prevents potential data breach

### Step 1: Rotate Supabase Keys

1. **Access Supabase Dashboard**
   - Go to your project: https://app.supabase.com/project/vohyhkjygvkaxlmqkbem
   - Look for **Settings** icon (gear icon) in the left sidebar
   - Click on **API** in the main panel (not in Project Settings submenu)
   - Alternative: Try direct link: https://app.supabase.com/project/vohyhkjygvkaxlmqkbem/settings/api
   - Sign in with admin credentials

2. **Regenerate All Keys**
   - In the "Project API keys" section, look for:
     - **Option A**: "Generate new JWT secret" button at the top
     - **Option B**: Three dots menu (⋮) or settings icon next to each key
     - **Option C**: "Regenerate JWT Secret" in a separate JWT section
     - **Option D**: If no regenerate option visible:
       - Check "JWT Settings" or "JWT Keys" in left nav
       - Or go to Authentication → Configuration → JWT
   
   - **Alternative Method** (if UI doesn't show regenerate):
     - You may need to generate a new JWT secret first
     - This will automatically create new anon and service_role keys
     - Look for "Generate new JWT secret" or similar option
   
   - Copy and save the new keys immediately (password manager recommended)
   - Note: Keys might be partially hidden with "Reveal" or eye icon

3. **Update GitHub Secrets**
   - Navigate to: Settings → Secrets and variables → Actions
   - Update these secrets with new values:
     - `NEXT_PUBLIC_SUPABASE_URL` (stays the same)
     - `NEXT_PUBLIC_SUPABASE_ANON_KEY` (new value)
     - `SUPABASE_SERVICE_KEY` (new value)

4. **Update Vercel Environment Variables** (CRITICAL for production)
   - Go to: https://vercel.com/dashboard → Your Project → Settings → Environment Variables
   - Update these variables for all environments (Production, Preview, Development):
     - `NEXT_PUBLIC_SUPABASE_URL` (stays the same)
     - `NEXT_PUBLIC_SUPABASE_ANON_KEY` (new value)
     - `SUPABASE_SERVICE_KEY` (new value)
   - Click "Save" for each variable
   - **Redeploy** to apply changes: Deployments → Three dots → Redeploy

5. **Update Local Development**
   - Copy `.env.example` to `.env.local`
   - Add the new keys to `.env.local`
   - **NEVER** commit `.env.local` to Git

### Step 2: Clean Git History (Optional but Recommended)

Remove exposed keys from Git history using BFG Repo-Cleaner:

```bash
# Download BFG
wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar

# Create a backup
git clone --mirror https://github.com/vikaspromo/externalView.git externalView-backup

# Remove sensitive data
java -jar bfg-1.14.0.jar --replace-text passwords.txt externalView-backup

# Clean and push
cd externalView-backup
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push --force
```

Create `passwords.txt` with patterns to remove:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9*==>REMOVED
vohyhkjygvkaxlmqkbem.supabase.co==>REMOVED
```

### Step 3: Audit Access Logs

1. Check Supabase logs for unauthorized access:
   - Dashboard → Logs → Auth
   - Look for unfamiliar IPs or unusual patterns

2. Review database audit logs:
   ```sql
   SELECT * FROM security_audit_log 
   WHERE event_type = 'unauthorized_client_access'
   ORDER BY created_at DESC;
   ```

### Security Best Practices Going Forward

#### Environment Variables
- ✅ Use `.env.local` for local development only
- ✅ Add `.env.local` to `.gitignore`
- ✅ Store production secrets in GitHub Secrets or secure vaults
- ❌ Never commit secrets to Git
- ❌ Never hardcode secrets in source code

#### Key Management
- Rotate keys every 90 days
- Use different keys for dev/staging/production
- Implement key rotation reminders
- Document key rotation in audit logs

#### Access Control
- Enable MFA for all admin accounts
- Review admin access quarterly
- Implement least privilege principle
- Log all admin actions

#### Code Reviews
- Check for exposed secrets in PRs
- Use automated secret scanning (GitHub secret scanning)
- Review `.gitignore` for sensitive files
- Verify environment variable usage

### Monitoring & Alerts

Set up alerts for:
- Failed authentication attempts (>5 in 5 minutes)
- Cross-tenant access attempts
- Service key usage from unknown IPs
- Database schema changes

### Incident Response Plan

If keys are compromised:
1. **Immediate**: Rotate all keys
2. **Within 1 hour**: Review access logs
3. **Within 4 hours**: Notify affected users if data breach
4. **Within 24 hours**: Complete security audit
5. **Within 72 hours**: File compliance reports if required

### Compliance Considerations

For SOC 2 compliance:
- Document all key rotations
- Maintain audit logs for 7 years
- Implement automated secret scanning
- Conduct quarterly security reviews
- Enable database encryption at rest

### Contact

Security issues: security@yourcompany.com
Security updates: Check this file regularly

---
Last Updated: January 11, 2025
Next Review: April 11, 2025
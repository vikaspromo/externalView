# Data Pipelines

This directory contains scripts for integrating various external data sources into the External View platform.

## Directory Structure

```
data-pipelines/
├── propublica/          # ProPublica Nonprofit Explorer API
├── opensecrets/         # OpenSecrets campaign finance data (future)
├── fec/                 # Federal Election Commission data (future)
├── irs/                 # IRS Form 990 data (future)
└── shared/              # Shared utilities across all data sources
```

## Available Data Sources

### ProPublica Nonprofit Explorer
- **Status**: ✅ Implemented
- **Data**: EINs, nonprofit names, classifications, financial data
- **Scripts**: Organization search and EIN population

### OpenSecrets (Planned)
- **Status**: 🔜 Coming soon
- **Data**: Campaign contributions, lobbying data, revolving door information

### FEC (Planned)
- **Status**: 🔜 Coming soon
- **Data**: Federal campaign finance reports, PAC contributions

### IRS (Planned)
- **Status**: 🔜 Coming soon
- **Data**: Form 990 filings, tax-exempt organization data

## Usage

Each data source has its own directory with specialized scripts. See individual README files in each directory for specific usage instructions.

### Running ProPublica Scripts

```bash
# Fetch and save organization EINs
npx tsx scripts/data-pipelines/propublica/fetch-organizations.ts

# Check current EIN status
npx tsx scripts/data-pipelines/propublica/check-eins.ts

# Test ProPublica search without saving
npx tsx scripts/data-pipelines/propublica/fetch-organizations-test.ts
```

## Shared Utilities

The `shared/` directory contains common utilities:
- `database.ts`: Supabase client initialization
- `rate-limiter.ts`: API rate limiting utilities
- `types.ts`: Shared TypeScript interfaces (if needed)

## Environment Variables

All scripts require the following environment variables in `.env.local`:
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_KEY=your_service_key
```

## Adding New Data Sources

1. Create a new directory under `data-pipelines/`
2. Add source-specific types in `types.ts`
3. Create fetch/import scripts
4. Document in a source-specific README
5. Update this main README

## Database Migrations

Related database migrations are stored in `/supabase/migrations/`
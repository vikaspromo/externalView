# ProPublica Nonprofit Explorer Integration

This directory contains scripts for integrating with ProPublica's Nonprofit Explorer API.

## Overview

ProPublica provides comprehensive data about tax-exempt organizations through their Nonprofit Explorer API. This integration fetches organization data including EINs, names, locations, and financial information.

## Scripts

### `fetch-organizations.ts`
Main script that searches for organizations and updates the database with EIN information.

**Features:**
- Searches ProPublica for each organization without an EIN
- Handles single and multiple matches
- Updates existing records and inserts new ones for multiple matches
- Links related organizations via `ein_related` field
- Uses "00-0000000" as marker for organizations not found

**Usage:**
```bash
npx tsx scripts/data-pipelines/propublica/fetch-organizations.ts
```

### `fetch-organizations-test.ts`
Test script that searches ProPublica without saving to database. Useful for testing and debugging.

**Usage:**
```bash
npx tsx scripts/data-pipelines/propublica/fetch-organizations-test.ts
```

### `check-eins.ts`
Utility script to check the current EIN status of all organizations.

**Usage:**
```bash
npx tsx scripts/data-pipelines/propublica/check-eins.ts
```

## API Information

- **Base URL**: `https://projects.propublica.org/nonprofits/api/v2`
- **Rate Limit**: 1 second delay between requests (implemented)
- **Authentication**: None required (public API)
- **Documentation**: https://projects.propublica.org/nonprofits/api

## Data Fields

### From ProPublica API
- `ein`: Employer Identification Number
- `strein`: Formatted EIN with hyphen (e.g., "12-3456789")
- `name`: Organization name
- `sub_name`: Sub-organization name
- `city`, `state`: Location information
- `ntee_code`: National Taxonomy of Exempt Entities code
- `subseccd`: IRS subsection code
- `totrevenue`: Total revenue
- `totfuncexpns`: Total functional expenses
- `score`: Relevance score for search results

### Database Fields Added
- `ein`: VARCHAR(20) - The organization's EIN
- `ein_related`: VARCHAR(20)[] - Array of related EINs with same search score

## Handling Multiple Matches

When a search returns multiple organizations with the same relevance score:
1. The first match updates the existing database record
2. Additional matches are inserted as new records
3. All related records have `ein_related` arrays linking them together

## No Results Handling

Organizations not found in ProPublica are marked with EIN "00-0000000" to indicate they've been searched but not found.

## Related Files

- **Database Migration**: `/supabase/migrations/20250109_add_ein_columns.sql`
- **Shared Types**: `./types.ts`
- **Database Client**: `../shared/database.ts`
- **Rate Limiter**: `../shared/rate-limiter.ts`
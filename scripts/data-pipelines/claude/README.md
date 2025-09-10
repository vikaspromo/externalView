# Claude API Integration Scripts

This directory contains scripts for integrating with Anthropic's Claude API to analyze and extract information about organizations.

## Overview

These scripts use Claude AI to analyze organizations and extract structured information such as policy positions, public stances, and other relevant data.

## Scripts

### `fetch-positions.ts`
Fetches and analyzes policy positions for organizations.

**Features:**
- Selects a random organization that doesn't have positions data yet
- Queries Claude API to analyze the organization's public positions
- Returns structured JSON with positions on various policy issues
- Saves results to the `organization_positions` table

**Usage:**
```bash
# First, add your Anthropic API key to .env.local:
# ANTHROPIC_API_KEY=sk-ant-api03-...

# Run the script
npx tsx scripts/data-pipelines/claude/fetch-positions.ts
```

## Database Schema

### `organization_positions` Table
Stores the policy positions data fetched from Claude API.

```sql
CREATE TABLE organization_positions (
  id UUID PRIMARY KEY,
  organization_uuid UUID REFERENCES organizations(uuid),
  organization_name VARCHAR(255),
  ein VARCHAR(20),
  positions JSONB,  -- Array of position objects
  fetched_at TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Position Object Structure
```json
{
  "description": "Short description of the issue",
  "position": "In favor|Opposed|No position",
  "positionDetails": "Detailed explanation of their stance",
  "referenceMaterials": ["URL1", "URL2"]
}
```

## Environment Variables

**Required:**
- `ANTHROPIC_API_KEY` - Your Anthropic API key
  - Add to `.env.local` file
  - Get your API key from: https://console.anthropic.com/settings/keys
  - Format: `ANTHROPIC_API_KEY=sk-ant-api03-...`

**Note:** The CLAUDE_CREDENTIALS GitHub secret contains OAuth tokens for Claude Code and cannot be used with the Anthropic SDK.

## API Configuration

- **Model**: Claude 3 Haiku (cost-efficient)
- **Temperature**: 0 (for consistent, factual responses)
- **Max Tokens**: 4096

## Position Categories Analyzed

The script analyzes organizations' positions on:
- Legislative and regulatory matters
- Industry-specific regulations
- Labor and employment policies
- Tax and economic policies
- Health and safety regulations
- Government programs and funding
- Trade and international commerce
- Environmental regulations
- Technology and innovation policies
- Controversial or politically significant topics

## Error Handling

- Validates API key availability
- Checks for table existence before operations
- Handles JSON parsing errors gracefully
- Provides clear error messages for debugging

## Rate Limiting

Currently no rate limiting is implemented. Consider adding delays between requests if processing multiple organizations in batch.

## Future Enhancements

- Batch processing for multiple organizations
- Scheduled updates for existing positions
- Comparison of positions over time
- Export functionality for reports
- Integration with other data sources for validation
#!/usr/bin/env node

/**
 * Environment validation script
 * Run this before starting the application to ensure all required
 * environment variables are properly configured
 */

const fs = require('fs')
const path = require('path')

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
}

// Required environment variables
const requiredVars = [
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY',
]

// Optional but recommended variables
const optionalVars = [
  'NEXT_PUBLIC_APP_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'DATABASE_URL',
]

console.log(`${colors.blue}🔍 Checking environment variables...${colors.reset}\n`)

let hasErrors = false
let hasWarnings = false

// Check for .env file
const envPath = path.join(process.cwd(), '.env.local')
const envExists = fs.existsSync(envPath)

if (!envExists) {
  console.log(`${colors.yellow}⚠️  Warning: No .env.local file found${colors.reset}`)
  console.log('   Create one by copying .env.example:')
  console.log(`   ${colors.blue}cp .env.example .env.local${colors.reset}\n`)
  hasWarnings = true
}

// Check required variables
console.log(`${colors.blue}Required Variables:${colors.reset}`)
requiredVars.forEach(varName => {
  if (process.env[varName]) {
    const value = process.env[varName]
    const displayValue = varName.includes('KEY') 
      ? `${value.substring(0, 10)}...` 
      : value
    console.log(`  ${colors.green}✓${colors.reset} ${varName}: ${displayValue}`)
  } else {
    console.log(`  ${colors.red}✗${colors.reset} ${varName}: NOT SET`)
    hasErrors = true
  }
})

// Check optional variables
console.log(`\n${colors.blue}Optional Variables:${colors.reset}`)
optionalVars.forEach(varName => {
  if (process.env[varName]) {
    const value = process.env[varName]
    const displayValue = varName.includes('KEY') || varName.includes('DATABASE_URL')
      ? `${value.substring(0, 10)}...` 
      : value
    console.log(`  ${colors.green}✓${colors.reset} ${varName}: ${displayValue}`)
  } else {
    console.log(`  ${colors.yellow}○${colors.reset} ${varName}: not set`)
    if (varName === 'NEXT_PUBLIC_APP_URL') {
      console.log('    (will default to http://localhost:3000)')
    }
  }
})

// Check Supabase URL format
if (process.env.NEXT_PUBLIC_SUPABASE_URL) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  if (url.includes('localhost') || url.includes('127.0.0.1')) {
    console.log(`\n${colors.blue}ℹ️  Using local Supabase instance${colors.reset}`)
  } else if (!url.startsWith('https://')) {
    console.log(`\n${colors.yellow}⚠️  Warning: Production Supabase URL should use HTTPS${colors.reset}`)
    hasWarnings = true
  }
}

// Summary
console.log('\n' + '='.repeat(50))
if (hasErrors) {
  console.log(`${colors.red}❌ Environment validation failed!${colors.reset}`)
  console.log('   Please set all required environment variables.')
  console.log('   See .env.example for documentation.')
  process.exit(1)
} else if (hasWarnings) {
  console.log(`${colors.yellow}⚠️  Environment validation passed with warnings${colors.reset}`)
  console.log('   The application will run but some features may not work.')
} else {
  console.log(`${colors.green}✅ Environment validation passed!${colors.reset}`)
  console.log('   All required environment variables are set.')
}
console.log('='.repeat(50))
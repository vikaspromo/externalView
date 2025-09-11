/**
 * Environment variable validation and type safety
 * This ensures all required environment variables are present
 * and provides type-safe access throughout the application
 */

type EnvConfig = {
  // Public environment variables (exposed to client)
  NEXT_PUBLIC_APP_URL: string
  NEXT_PUBLIC_SUPABASE_URL: string
  NEXT_PUBLIC_SUPABASE_ANON_KEY: string
  
  // Server-only environment variables
  SUPABASE_SERVICE_ROLE_KEY?: string
  DATABASE_URL?: string
  
  // Optional services
  ANTHROPIC_API_KEY?: string
  SENTRY_DSN?: string
  
  // Environment
  NODE_ENV: 'development' | 'production' | 'test'
}

class EnvironmentError extends Error {
  constructor(variable: string) {
    super(`Missing required environment variable: ${variable}`)
    this.name = 'EnvironmentError'
  }
}

/**
 * Validates that a required environment variable exists
 */
function getRequiredEnv(key: string): string {
  const value = process.env[key]
  if (!value) {
    throw new EnvironmentError(key)
  }
  return value
}

/**
 * Gets an optional environment variable with a default value
 */
function getOptionalEnv(key: string, defaultValue?: string): string | undefined {
  return process.env[key] || defaultValue
}

/**
 * Validates and returns all environment variables with proper types
 * This should be called once at application startup
 */
export function validateEnv(): EnvConfig {
  // Only validate server-side
  if (typeof window !== 'undefined') {
    return {
      NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
      NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL!,
      NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      NODE_ENV: (process.env.NODE_ENV as EnvConfig['NODE_ENV']) || 'development',
    }
  }

  const config: EnvConfig = {
    // Required public variables
    NEXT_PUBLIC_APP_URL: getRequiredEnv('NEXT_PUBLIC_APP_URL'),
    NEXT_PUBLIC_SUPABASE_URL: getRequiredEnv('NEXT_PUBLIC_SUPABASE_URL'),
    NEXT_PUBLIC_SUPABASE_ANON_KEY: getRequiredEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    
    // Optional server variables
    SUPABASE_SERVICE_ROLE_KEY: getOptionalEnv('SUPABASE_SERVICE_ROLE_KEY'),
    DATABASE_URL: getOptionalEnv('DATABASE_URL'),
    
    // Optional services
    ANTHROPIC_API_KEY: getOptionalEnv('ANTHROPIC_API_KEY'),
    SENTRY_DSN: getOptionalEnv('SENTRY_DSN'),
    
    // Environment
    NODE_ENV: (process.env.NODE_ENV as EnvConfig['NODE_ENV']) || 'development',
  }

  // Additional validation
  if (config.NODE_ENV === 'production') {
    // In production, service role key should be set
    if (!config.SUPABASE_SERVICE_ROLE_KEY) {
      console.warn('⚠️  Warning: SUPABASE_SERVICE_ROLE_KEY not set in production')
    }
    
    // Ensure URLs are HTTPS in production
    if (!config.NEXT_PUBLIC_SUPABASE_URL.startsWith('https://')) {
      console.warn('⚠️  Warning: NEXT_PUBLIC_SUPABASE_URL should use HTTPS in production')
    }
  }

  return config
}

// Export a singleton instance
let envConfig: EnvConfig | null = null

export function getEnv(): EnvConfig {
  if (!envConfig) {
    envConfig = validateEnv()
  }
  return envConfig
}

// Type-safe environment variable access
export const env = new Proxy({} as EnvConfig, {
  get(target, prop: string) {
    const config = getEnv()
    return config[prop as keyof EnvConfig]
  },
})
/**
 * Production-safe logger utility
 * Only logs in development mode to prevent sensitive data exposure in production
 */

const isDevelopment = process.env.NODE_ENV === 'development'
const isTest = process.env.NODE_ENV === 'test'

/**
 * Logger configuration
 */
interface LoggerConfig {
  enabled: boolean
  logToConsole: boolean
  logLevel: 'debug' | 'info' | 'warn' | 'error'
}

const config: LoggerConfig = {
  enabled: isDevelopment || isTest,
  logToConsole: isDevelopment,
  logLevel: 'error', // Only log errors and above in production
}

/**
 * Production-safe logger
 * In development: logs to console
 * In production: silent (can be configured to send to monitoring service)
 */
export const logger = {
  /**
   * Log debug information (development only)
   */
  debug: (...args: any[]): void => {
    if (config.enabled && config.logLevel === 'debug') {
      if (config.logToConsole) {
        console.debug('[DEBUG]', ...args)
      }
    }
  },

  /**
   * Log informational messages (development only)
   */
  info: (...args: any[]): void => {
    if (config.enabled && ['debug', 'info'].includes(config.logLevel)) {
      if (config.logToConsole) {
        console.info('[INFO]', ...args)
      }
    }
  },

  /**
   * Log warnings (development only)
   */
  warn: (...args: any[]): void => {
    if (config.enabled && ['debug', 'info', 'warn'].includes(config.logLevel)) {
      if (config.logToConsole) {
        console.warn('[WARN]', ...args)
      }
    }
  },

  /**
   * Log errors
   * In production, this could be configured to send to error tracking service
   */
  error: (message: string, error?: any): void => {
    if (config.enabled) {
      if (config.logToConsole) {
        console.error('[ERROR]', message, error)
      }
    }
    
    // In production, send to error tracking service
    // Example: Sentry, LogRocket, etc.
    if (!isDevelopment && error) {
      // TODO: Integrate with error tracking service
      // Example:
      // Sentry.captureException(error, {
      //   extra: { message }
      // })
    }
  },

  /**
   * Log security events (always silent in production)
   * These should go through the audit log system instead
   */
  security: (event: string, metadata?: any): void => {
    if (isDevelopment) {
      console.warn('[SECURITY]', event, metadata)
    }
    // In production, use the audit log service instead
  },
}

/**
 * Helper to safely stringify objects for logging
 * Prevents circular reference errors and redacts sensitive fields
 */
export function safeStringify(obj: any): string {
  const sensitiveKeys = ['password', 'token', 'key', 'secret', 'authorization']
  
  try {
    return JSON.stringify(obj, (key, value) => {
      // Redact sensitive fields
      if (sensitiveKeys.some(sensitive => key.toLowerCase().includes(sensitive))) {
        return '[REDACTED]'
      }
      
      // Handle circular references
      if (typeof value === 'object' && value !== null) {
        if (seen.has(value)) {
          return '[Circular]'
        }
        seen.add(value)
      }
      
      return value
    }, 2)
  } catch (error) {
    return '[Unable to stringify]'
  }
}

const seen = new WeakSet()

/**
 * Development-only logger for debugging
 * This will be completely removed in production builds
 */
export const devLog = isDevelopment ? {
  log: console.log,
  error: console.error,
  warn: console.warn,
  info: console.info,
  debug: console.debug,
  table: console.table,
  time: console.time,
  timeEnd: console.timeEnd,
} : {
  log: () => {},
  error: () => {},
  warn: () => {},
  info: () => {},
  debug: () => {},
  table: () => {},
  time: () => {},
  timeEnd: () => {},
}

export default logger
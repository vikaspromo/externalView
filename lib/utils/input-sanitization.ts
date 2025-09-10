/**
 * Input sanitization and validation utilities for user-generated content
 * Provides protection against XSS, SQL injection, and other malicious inputs
 */

/**
 * Sanitizes user input for safe storage in database
 * @param input - Raw user input string
 * @param maxLength - Maximum allowed length (default: 10000)
 * @returns Sanitized string safe for database storage
 */
export function sanitizeInput(input: string, maxLength: number = 10000): string {
  if (!input || typeof input !== 'string') {
    return ''
  }

  // Trim whitespace
  let sanitized = input.trim()

  // Enforce max length
  if (sanitized.length > maxLength) {
    sanitized = sanitized.substring(0, maxLength)
  }

  // Remove null bytes
  sanitized = sanitized.replace(/\0/g, '')

  // Escape HTML entities to prevent XSS
  sanitized = sanitized
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;')

  // Remove any potential SQL injection patterns (extra safety layer)
  // Note: Supabase already uses parameterized queries, but this adds defense in depth
  sanitized = sanitized.replace(/(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|CREATE)\b)/gi, '')

  return sanitized
}

/**
 * Unescapes HTML entities for display
 * @param input - HTML-escaped string
 * @returns Unescaped string for display
 */
export function unescapeHtml(input: string): string {
  if (!input || typeof input !== 'string') {
    return ''
  }

  return input
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#x27;/g, "'")
    .replace(/&#x2F;/g, '/')
}

/**
 * Validates input against common patterns
 * @param input - String to validate
 * @param type - Type of validation to perform
 * @returns Boolean indicating if input is valid
 */
export function validateInput(
  input: string,
  type: 'email' | 'url' | 'alphanumeric' | 'text' = 'text'
): boolean {
  if (!input || typeof input !== 'string') {
    return false
  }

  switch (type) {
    case 'email':
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      return emailRegex.test(input)

    case 'url':
      try {
        new URL(input)
        return true
      } catch {
        return false
      }

    case 'alphanumeric':
      const alphanumericRegex = /^[a-zA-Z0-9\s]+$/
      return alphanumericRegex.test(input)

    case 'text':
      // Allow most characters but block obvious script injections
      const scriptPattern = /<script|javascript:|on\w+\s*=/gi
      return !scriptPattern.test(input)

    default:
      return true
  }
}

/**
 * Sanitizes input specifically for display in React components
 * Preserves line breaks and basic formatting while preventing XSS
 * @param input - Raw user input
 * @param preserveLineBreaks - Whether to preserve line breaks
 * @returns Sanitized string safe for display
 */
export function sanitizeForDisplay(input: string, preserveLineBreaks: boolean = true): string {
  if (!input || typeof input !== 'string') {
    return ''
  }

  // First apply general sanitization
  let sanitized = sanitizeInput(input)

  // Unescape for display
  sanitized = unescapeHtml(sanitized)

  // Preserve line breaks if requested
  if (preserveLineBreaks) {
    // Line breaks are already preserved in the original text
    // This is handled by CSS white-space property in the component
  }

  return sanitized
}

/**
 * Rate limiting helper for input operations
 * Returns true if the operation should be allowed based on rate limits
 */
export function checkRateLimit(
  key: string,
  maxAttempts: number = 10,
  windowMs: number = 60000
): boolean {
  const now = Date.now()
  const storageKey = `rate_limit_${key}`
  
  try {
    const stored = localStorage.getItem(storageKey)
    if (!stored) {
      localStorage.setItem(storageKey, JSON.stringify({ count: 1, timestamp: now }))
      return true
    }

    const { count, timestamp } = JSON.parse(stored)
    
    // Reset if window has passed
    if (now - timestamp > windowMs) {
      localStorage.setItem(storageKey, JSON.stringify({ count: 1, timestamp: now }))
      return true
    }

    // Check if under limit
    if (count < maxAttempts) {
      localStorage.setItem(storageKey, JSON.stringify({ count: count + 1, timestamp }))
      return true
    }

    return false
  } catch {
    // If localStorage is not available, allow the operation
    return true
  }
}
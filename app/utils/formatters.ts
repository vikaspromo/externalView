/**
 * Formatting utilities for displaying data in the UI
 */

import { isCurrencyField, isDateField } from './field-detection'

/**
 * Format a number or string value as USD currency
 */
export const formatCurrency = (value: number | string): string => {
  const num = typeof value === 'string' ? parseFloat(value) : value
  if (isNaN(num)) return String(value)
  return `$${num.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}

/**
 * Format a date string or Date object as a readable date
 */
export const formatDate = (value: string | Date): string => {
  try {
    const date = value instanceof Date ? value : new Date(value)
    // Check if date is valid
    if (isNaN(date.getTime())) return String(value)
    
    // Format as "Month Day, Year" (e.g., "January 15, 2024")
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })
  } catch (error) {
    return String(value)
  }
}

/**
 * Format a field value intelligently based on its content
 */
export const formatFieldValue = (key: string, value: any): string => {
  if (value === null || value === undefined) return '-'
  
  // Handle arrays - join items with comma, no brackets or quotes
  if (Array.isArray(value)) {
    if (value.length === 0) return '-'
    // For arrays of objects, stringify each object
    if (value.some(item => typeof item === 'object' && item !== null)) {
      return value.map(item => 
        typeof item === 'object' ? JSON.stringify(item) : String(item)
      ).join(', ')
    }
    // For simple arrays, capitalize first letter of each item and join
    return value.map(item => {
      const str = String(item)
      return str.charAt(0).toUpperCase() + str.slice(1)
    }).join(', ')
  }
  
  // Check if it's a date field and the value looks like a date
  if (isDateField(key) && typeof value === 'string') {
    // Check if it looks like a date (ISO format, or contains date separators)
    if (value.match(/^\d{4}-\d{2}-\d{2}/) || value.match(/\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/)) {
      return formatDate(value)
    }
  }
  
  // Check if it's a currency field and the value is numeric
  if (isCurrencyField(key) && (typeof value === 'number' || !isNaN(parseFloat(value)))) {
    return formatCurrency(value)
  }
  
  // Handle objects (but not arrays, which are already handled above)
  if (typeof value === 'object' && value !== null) {
    // Use pretty printing for objects
    return JSON.stringify(value, null, 2)
  }
  
  // Handle booleans
  if (typeof value === 'boolean') {
    return value ? 'Yes' : 'No'
  }
  
  // Default to string representation
  return String(value)
}
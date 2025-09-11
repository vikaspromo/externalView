/**
 * Field type detection utilities
 */

/**
 * Check if a field name suggests it contains currency data
 */
export const isCurrencyField = (key: string): boolean => {
  const currencyKeywords = [
    'amount', 'spend', 'budget', 'cost', 'price', 'fee', 'revenue', 
    'dues', 'payment', 'sponsorship', 'value', 'salary', 'income',
    'expense', 'total', 'subtotal', 'balance', 'credit', 'debit',
  ]
  const lowerKey = key.toLowerCase()
  return currencyKeywords.some(keyword => lowerKey.includes(keyword))
}

/**
 * Check if a field name suggests it contains date data
 */
export const isDateField = (key: string): boolean => {
  const dateKeywords = [
    'date', 'time', 'created', 'updated', 'modified', 'deadline',
    'due', 'expires', 'renewal', 'start', 'end', 'birth', 'joined',
    'last', 'next', 'scheduled', 'completed', 'signed',
  ]
  const lowerKey = key.toLowerCase()
  return dateKeywords.some(keyword => lowerKey.includes(keyword))
}

/**
 * Check if a field name suggests it contains percentage data
 */
export const isPercentageField = (key: string): boolean => {
  const percentageKeywords = [
    'percent', 'percentage', 'rate', 'ratio', 'score', 'alignment',
  ]
  const lowerKey = key.toLowerCase()
  return percentageKeywords.some(keyword => lowerKey.includes(keyword))
}

/**
 * Check if a field name suggests it contains boolean data
 */
export const isBooleanField = (key: string): boolean => {
  const booleanKeywords = [
    'is_', 'has_', 'can_', 'should_', 'active', 'enabled', 
    'disabled', 'visible', 'hidden', 'completed', 'approved',
  ]
  const lowerKey = key.toLowerCase()
  return booleanKeywords.some(keyword => lowerKey.includes(keyword))
}
/**
 * Reusable loading spinner component
 */

import React from 'react'

interface LoadingSpinnerProps {
  size?: 'small' | 'medium' | 'large'
  color?: string
}

export const LoadingSpinner: React.FC<LoadingSpinnerProps> = ({ 
  size = 'medium',
  color = 'primary-600' 
}) => {
  const sizeClasses = {
    small: 'h-8 w-8',
    medium: 'h-12 w-12',
    large: 'h-16 w-16'
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50">
      <div className={`animate-spin rounded-full ${sizeClasses[size]} border-b-2 border-${color}`}></div>
    </div>
  )
}
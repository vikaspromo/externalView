'use client'

import React, { useState, useRef, useEffect } from 'react'
import { sanitizeInput, sanitizeForDisplay } from '@/lib/utils/input-sanitization'

interface EditableTextProps {
  value: string
  onSave: (newValue: string) => Promise<void>
  placeholder?: string
  maxLength?: number
  className?: string
  multiline?: boolean
  disabled?: boolean
  label?: string
}

export function EditableText({
  value,
  onSave,
  placeholder = 'Click to edit...',
  maxLength = 5000,
  className = '',
  multiline = false,
  disabled = false,
  label,
}: EditableTextProps) {
  const [isEditing, setIsEditing] = useState(false)
  const [editValue, setEditValue] = useState(value)
  const [isSaving, setIsSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showSuccess, setShowSuccess] = useState(false)
  const inputRef = useRef<HTMLTextAreaElement | HTMLInputElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)

  // Update edit value when prop value changes
  useEffect(() => {
    if (!isEditing) {
      setEditValue(value)
    }
  }, [value, isEditing])

  // Focus input when entering edit mode
  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus()
      inputRef.current.select()
    }
  }, [isEditing])

  // Handle click outside to save
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        if (isEditing) {
          handleSave()
        }
      }
    }

    if (isEditing) {
      document.addEventListener('mousedown', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isEditing, editValue])

  const handleSave = async () => {
    if (disabled || isSaving) return

    const trimmedValue = editValue.trim()
    
    // If value hasn't changed, just exit edit mode
    if (trimmedValue === value.trim()) {
      setIsEditing(false)
      return
    }

    // Sanitize input before saving
    const sanitized = sanitizeInput(trimmedValue, maxLength)

    setIsSaving(true)
    setError(null)

    try {
      await onSave(sanitized)
      setIsEditing(false)
      setShowSuccess(true)
      setTimeout(() => setShowSuccess(false), 2000)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save')
      // Keep in edit mode on error
    } finally {
      setIsSaving(false)
    }
  }

  const handleCancel = () => {
    setEditValue(value)
    setIsEditing(false)
    setError(null)
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.preventDefault()
      handleCancel()
    } else if (e.key === 'Enter') {
      if (!multiline || (e.shiftKey === false && e.metaKey === false)) {
        e.preventDefault()
        handleSave()
      }
    }
  }

  const displayValue = sanitizeForDisplay(value || '', multiline)

  if (isEditing) {
    const InputComponent = multiline ? 'textarea' : 'input'
    
    return (
      <div ref={containerRef} className="relative">
        {label && (
          <label className="text-sm font-semibold text-gray-700 mb-2 block">
            {label}
          </label>
        )}
        <InputComponent
          ref={inputRef as any}
          value={editValue}
          onChange={(e) => setEditValue(e.target.value)}
          onKeyDown={handleKeyDown}
          maxLength={maxLength}
          disabled={isSaving}
          className={`
            w-full px-3 py-2 text-sm border-2 border-blue-500 rounded-md
            focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent
            disabled:opacity-50 disabled:cursor-not-allowed
            ${multiline ? 'min-h-[100px] resize-y' : ''}
            ${className}
          `}
          placeholder={placeholder}
        />
        
        {/* Character count and help text on one line */}
        <div className="mt-1 flex justify-between items-center text-xs text-gray-500">
          <span>
            {multiline ? 'Shift+Enter for new line • ' : ''}
            Enter to save • Esc to cancel
          </span>
          <div className="flex items-center space-x-2">
            {isSaving && (
              <span className="flex items-center">
                <svg className="animate-spin h-3 w-3 mr-1" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                Saving...
              </span>
            )}
            <span>{editValue.length}/{maxLength}</span>
          </div>
        </div>
        {error && (
          <div className="mt-1 text-xs text-red-600">{error}</div>
        )}
      </div>
    )
  }

  return (
    <div ref={containerRef} className="relative group">
      {label && (
        <label className="text-sm font-semibold text-gray-700 mb-2 block">
          {label}
        </label>
      )}
      <div
        onClick={() => !disabled && setIsEditing(true)}
        className={`
          relative cursor-pointer px-3 py-2 text-sm rounded-md
          transition-all duration-200
          ${disabled ? 'cursor-not-allowed opacity-50' : 'hover:bg-gray-50'}
          ${!value ? 'text-gray-400 italic' : 'text-gray-700'}
          ${className}
        `}
      >
        {/* Content */}
        <div className={multiline ? 'whitespace-pre-wrap' : 'truncate'}>
          {displayValue || placeholder}
        </div>

        {/* Success indicator */}
        {showSuccess && (
          <div className="absolute top-2 right-2">
            <svg 
              className="w-4 h-4 text-green-500"
              fill="none" 
              viewBox="0 0 24 24" 
              stroke="currentColor"
            >
              <path 
                strokeLinecap="round" 
                strokeLinejoin="round" 
                strokeWidth={2} 
                d="M5 13l4 4L19 7" 
              />
            </svg>
          </div>
        )}
      </div>

      {/* Hover hint */}
      {!disabled && !value && (
        <div className="mt-1 text-xs text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity">
          Click to add {label?.toLowerCase() || 'text'}
        </div>
      )}
    </div>
  )
}
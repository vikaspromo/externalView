/**
 * Fixed auth hook that handles logout errors with new API keys
 */

import { useEffect, useState, useCallback } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { useRouter } from 'next/navigation'
import { User } from '@/lib/supabase/types'
import { logger } from '@/lib/utils/logger'

export interface AuthState {
  user: any | null
  userData: User | null
  isLoading: boolean
  isAdmin: boolean
  signOut: () => Promise<void>
}

export const useAuth = (): AuthState => {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)
  const router = useRouter()
  const supabase = createClientComponentClient()

  const signOut = useCallback(async () => {
    try {
      // Try to sign out normally
      await supabase.auth.signOut()
    } catch (error) {
      // If logout fails (403 with new keys), clear local session anyway
      // This is expected behavior with new API keys
      
      // Clear local storage to force re-authentication
      if (typeof window !== 'undefined') {
        // Clear Supabase auth storage
        const storageKey = `sb-${process.env.NEXT_PUBLIC_SUPABASE_URL?.split('//')[1]?.split('.')[0]}-auth-token`
        localStorage.removeItem(storageKey)
        sessionStorage.clear()
      }
    } finally {
      // Always redirect to home
      router.push('/')
    }
  }, [supabase, router])

  useEffect(() => {
    const getUser = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession()
        
        if (!session?.user) {
          router.push('/')
          return
        }

        setUser(session.user)
        
        // Check if user is in users table
        const { data: allowedUser } = await supabase
          .from('users')
          .select('*')
          .eq('id', session.user.id)
          .single()
        
        if (allowedUser) {
          setUserData(allowedUser as User)
          return
        }
        
        // Check if they're an admin
        const { data: adminUser } = await supabase
          .from('user_admins')
          .select('*')
          .eq('user_id', session.user.id)
          .eq('active', true)
          .single()
        
        if (adminUser) {
          setIsAdmin(true)
          const minimalUserData: User = {
            id: session.user.id,
            email: session.user.email!,
            first_name: null,
            last_name: null,
            client_uuid: '',
            active: true,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          }
          setUserData(minimalUserData)
          return
        }
        
        // User not authorized
        await signOut()
        return
      } catch (error) {
        logger.error('Auth error', error)
        router.push('/')
      } finally {
        setIsLoading(false)
      }
    }

    getUser()
  }, [supabase, router, signOut])

  return {
    user,
    userData,
    isLoading,
    isAdmin,
    signOut,
  }
}
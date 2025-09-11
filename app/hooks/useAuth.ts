/**
 * Custom hook for authentication logic
 */

import { useEffect, useState } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { useRouter } from 'next/navigation'
import { User } from '@/lib/supabase/types'

export interface AuthState {
  user: any | null
  userData: User | null
  isLoading: boolean
  signOut: () => Promise<void>
}

/**
 * Hook to manage authentication state and user data
 */
export const useAuth = (): AuthState => {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const router = useRouter()
  const supabase = createClientComponentClient()

  useEffect(() => {
    const getUser = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession()
        
        if (!session?.user) {
          router.push('/')
          return
        }

        setUser(session.user)
        
        // CRITICAL FIX: Use auth.uid() instead of email to prevent JWT spoofing
        // Check if user is in users table (allowed users)
        const { data: allowedUser } = await supabase
          .from('users')
          .select('*')
          .eq('id', session.user.id)  // Use uid, not email!
          .single()
        
        if (allowedUser) {
          setUserData(allowedUser as User)
          return
        }
        
        // If not in users table, check if they're an admin
        const { data: adminUser } = await supabase
          .from('user_admins')
          .select('*')
          .eq('user_id', session.user.id)  // Use uid for admin check too!
          .eq('active', true)
          .single()
        
        if (adminUser) {
          // Create minimal user data for admin
          const minimalUserData: User = {
            id: session.user.id,
            email: session.user.email!,  // Email is only used for display, not auth
            first_name: null,
            last_name: null,
            client_uuid: '', // Admins don't have a default client
            active: true,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          }
          setUserData(minimalUserData)
          return
        }
        
        // User not authorized in either table
        await supabase.auth.signOut()
        router.push('/')
        return
      } catch (error) {
        console.error('Auth error:', error)
        router.push('/')
      } finally {
        setIsLoading(false)
      }
    }

    getUser()
  }, [supabase, router])

  const signOut = async () => {
    await supabase.auth.signOut()
    router.push('/')
  }

  return {
    user,
    userData,
    isLoading,
    signOut,
  }
}
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get('code')

  if (code) {
    const supabase = createRouteHandlerClient({ cookies })
    await supabase.auth.exchangeCodeForSession(code)
    
    // Get the user session
    const { data: { session } } = await supabase.auth.getSession()
    
    if (session?.user) {
      // Check if user is in users table
      const { data: allowedUser, error } = await supabase
        .from('users')
        .select('*')
        .eq('email', session.user.email)
        .single()
      
      if (allowedUser && !error) {
        // User is authorized, redirect to dashboard
        return NextResponse.redirect(new URL('/dashboard', process.env.NEXT_PUBLIC_APP_URL || requestUrl.origin))
      } else {
        // User is not authorized, redirect to home (will show access denied)
        return NextResponse.redirect(new URL('/', process.env.NEXT_PUBLIC_APP_URL || requestUrl.origin))
      }
    }
  }

  // If no code or session, redirect to home
  return NextResponse.redirect(new URL('/', process.env.NEXT_PUBLIC_APP_URL || requestUrl.origin))
}
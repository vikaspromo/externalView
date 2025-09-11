import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  const res = NextResponse.next()
  const supabase = createMiddlewareClient({ req: request, res })

  // Refresh session if expired
  const { data: { session } } = await supabase.auth.getSession()

  // If user is accessing dashboard without session, redirect to home
  if (request.nextUrl.pathname.startsWith('/dashboard') && !session) {
    return NextResponse.redirect(new URL('/', request.url))
  }

  // If user has session but is accessing dashboard, verify they're in users
  if (request.nextUrl.pathname.startsWith('/dashboard') && session) {
    // CRITICAL: Use auth.uid() instead of email to prevent JWT spoofing
    const { data: allowedUser } = await supabase
      .from('users')
      .select('*')
      .eq('id', session.user.id)  // Use uid, not email!
      .single()

    if (!allowedUser) {
      // Check if they're an admin using uid
      const { data: adminUser } = await supabase
        .from('user_admins')
        .select('*')
        .eq('user_id', session.user.id)  // Use uid for admin check too
        .eq('active', true)
        .single()

      if (!adminUser) {
        // User is authenticated but not authorized, redirect to home
        return NextResponse.redirect(new URL('/', request.url))
      }
    }
  }

  return res
}

export const config = {
  matcher: ['/dashboard/:path*', '/api/:path*', '/auth/:path*']
}
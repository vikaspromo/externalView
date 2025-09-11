import { renderHook, waitFor } from '@testing-library/react'
import { useAuth } from '@/app/hooks/useAuth'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'

// Mock the modules
jest.mock('@supabase/auth-helpers-nextjs')

describe('Authentication Security', () => {
  const mockPush = jest.fn()
  const mockRouter = {
    push: mockPush,
  }
  
  const mockSupabase = {
    auth: {
      getSession: jest.fn(),
      signOut: jest.fn(),
    },
    from: jest.fn(),
  }

  beforeEach(() => {
    jest.clearAllMocks()
    
    // Mock useRouter from next/navigation
    const navigation = require('next/navigation')
    navigation.useRouter.mockReturnValue(mockRouter)
    
    ;(createClientComponentClient as jest.Mock).mockReturnValue(mockSupabase)
  })

  describe('Critical Security: UID-based Authentication', () => {
    it('should use user.id (uid) for authentication, NOT email', async () => {
      const mockSession = {
        user: {
          id: 'test-uid-123',
          email: 'test@example.com',
        },
      }

      const mockUserData = {
        id: 'test-uid-123',
        email: 'test@example.com',
        client_uuid: 'client-123',
      }

      // Setup mock responses
      mockSupabase.auth.getSession.mockResolvedValue({
        data: { session: mockSession },
      })

      const selectMock = jest.fn().mockReturnThis()
      const eqMock = jest.fn().mockReturnThis()
      const singleMock = jest.fn().mockResolvedValue({ data: mockUserData })

      mockSupabase.from.mockReturnValue({
        select: selectMock,
      })
      selectMock.mockReturnValue({
        eq: eqMock,
      })
      eqMock.mockReturnValue({
        single: singleMock,
      })

      // Render the hook
      const { result } = renderHook(() => useAuth())

      // Wait for the hook to complete
      await waitFor(() => {
        expect(result.current.isLoading).toBe(false)
      })

      // CRITICAL ASSERTION: Verify we're using uid, not email
      expect(eqMock).toHaveBeenCalledWith('id', 'test-uid-123')
      expect(eqMock).not.toHaveBeenCalledWith('email', expect.anything())
      
      // Verify the user data is set correctly
      expect(result.current.userData?.id).toBe('test-uid-123')
    })

    it('should check admin status using user_id, NOT email', async () => {
      const mockSession = {
        user: {
          id: 'admin-uid-456',
          email: 'admin@example.com',
        },
      }

      // Setup: user not in users table
      mockSupabase.auth.getSession.mockResolvedValue({
        data: { session: mockSession },
      })

      // First call returns users table mock
      const usersSelectMock = jest.fn().mockReturnThis()
      const usersEqMock = jest.fn().mockReturnThis()
      const usersSingleMock = jest.fn().mockResolvedValue({ data: null })

      // Second call returns user_admins table mock
      const adminSelectMock = jest.fn().mockReturnThis()
      const adminEqMock = jest.fn().mockReturnThis()
      const adminSingleMock = jest.fn().mockResolvedValue({ 
        data: { user_id: 'admin-uid-456', active: true } 
      })

      mockSupabase.from
        .mockReturnValueOnce({
          select: usersSelectMock,
        })
        .mockReturnValueOnce({
          select: adminSelectMock,
        })

      usersSelectMock.mockReturnValue({
        eq: usersEqMock,
      })
      usersEqMock.mockReturnValue({
        single: usersSingleMock,
      })

      adminSelectMock.mockReturnValue({
        eq: adminEqMock,
      })
      adminEqMock.mockImplementation((field, value) => {
        if (field === 'active') return { single: adminSingleMock }
        return { eq: adminEqMock }
      })

      // Render the hook
      const { result } = renderHook(() => useAuth())

      // Wait for the hook to complete
      await waitFor(() => {
        expect(result.current.isLoading).toBe(false)
      })

      // CRITICAL ASSERTION: Admin check must use user_id, not email
      expect(adminEqMock).toHaveBeenCalledWith('user_id', 'admin-uid-456')
      expect(adminEqMock).not.toHaveBeenCalledWith('email', expect.anything())
    })

    it('should reject unauthorized users', async () => {
      const mockSession = {
        user: {
          id: 'unauthorized-uid',
          email: 'hacker@evil.com',
        },
      }

      mockSupabase.auth.getSession.mockResolvedValue({
        data: { session: mockSession },
      })

      // User not in users table
      const usersSelectMock = jest.fn().mockReturnThis()
      const usersEqMock = jest.fn().mockReturnThis()
      const usersSingleMock = jest.fn().mockResolvedValue({ data: null })

      // User not in admins table
      const adminSelectMock = jest.fn().mockReturnThis()
      const adminEqMock = jest.fn().mockReturnThis()
      const adminSingleMock = jest.fn().mockResolvedValue({ data: null })

      mockSupabase.from
        .mockReturnValueOnce({
          select: usersSelectMock,
        })
        .mockReturnValueOnce({
          select: adminSelectMock,
        })

      usersSelectMock.mockReturnValue({
        eq: usersEqMock,
      })
      usersEqMock.mockReturnValue({
        single: usersSingleMock,
      })

      adminSelectMock.mockReturnValue({
        eq: adminEqMock,
      })
      adminEqMock.mockImplementation((field, value) => {
        if (field === 'active') return { single: adminSingleMock }
        return { eq: adminEqMock }
      })

      mockSupabase.auth.signOut.mockResolvedValue({})

      // Render the hook
      renderHook(() => useAuth())

      // Wait for auth check to complete
      await waitFor(() => {
        expect(mockSupabase.auth.signOut).toHaveBeenCalled()
      })

      // Verify user was signed out and redirected
      expect(mockPush).toHaveBeenCalledWith('/')
    })
  })

  describe('Session Management', () => {
    it('should redirect to home if no session', async () => {
      mockSupabase.auth.getSession.mockResolvedValue({
        data: { session: null },
      })

      renderHook(() => useAuth())

      await waitFor(() => {
        expect(mockPush).toHaveBeenCalledWith('/')
      })
    })

    it('should handle signOut correctly', async () => {
      const mockSession = {
        user: {
          id: 'test-uid',
          email: 'test@example.com',
        },
      }

      mockSupabase.auth.getSession.mockResolvedValue({
        data: { session: mockSession },
      })
      mockSupabase.auth.signOut.mockResolvedValue({})

      const selectMock = jest.fn().mockReturnThis()
      const eqMock = jest.fn().mockReturnThis()
      const singleMock = jest.fn().mockResolvedValue({ 
        data: { id: 'test-uid', email: 'test@example.com' } 
      })

      mockSupabase.from.mockReturnValue({
        select: selectMock,
      })
      selectMock.mockReturnValue({
        eq: eqMock,
      })
      eqMock.mockReturnValue({
        single: singleMock,
      })

      const { result } = renderHook(() => useAuth())

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false)
      })

      // Call signOut
      await result.current.signOut()

      expect(mockSupabase.auth.signOut).toHaveBeenCalled()
      expect(mockPush).toHaveBeenCalledWith('/')
    })
  })
})
-- Quick Verification of Auth Setup
-- Run this in Supabase SQL Editor to check if everything is configured correctly

-- ============================================================================
-- CHECK 1: Your user exists in auth.users
-- ============================================================================
SELECT 'CHECK 1: Auth User' as check_name, 
       CASE WHEN COUNT(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status,
       COUNT(*) as count
FROM auth.users 
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';

-- ============================================================================
-- CHECK 2: Your user exists in users table
-- ============================================================================
SELECT 'CHECK 2: Users Table Record' as check_name,
       CASE WHEN COUNT(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status,
       COUNT(*) as count
FROM users 
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';

-- ============================================================================
-- CHECK 3: Your admin status is set
-- ============================================================================
SELECT 'CHECK 3: Admin Status' as check_name,
       CASE WHEN COUNT(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status,
       COUNT(*) as count
FROM user_admins 
WHERE user_id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f'
AND active = true;

-- ============================================================================
-- CHECK 4: user_admins has user_id column
-- ============================================================================
SELECT 'CHECK 4: user_id Column Exists' as check_name,
       CASE WHEN COUNT(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status,
       COUNT(*) as count
FROM information_schema.columns 
WHERE table_name = 'user_admins' 
AND column_name = 'user_id';

-- ============================================================================
-- CHECK 5: client_uuid is nullable
-- ============================================================================
SELECT 'CHECK 5: client_uuid Nullable' as check_name,
       CASE WHEN is_nullable = 'YES' THEN '✅ PASS' ELSE '❌ FAIL' END as status,
       is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name = 'client_uuid';

-- ============================================================================
-- CHECK 6: RLS is enabled on tables
-- ============================================================================
SELECT 'CHECK 6: RLS on users' as check_name,
       CASE WHEN relrowsecurity THEN '✅ PASS' ELSE '❌ FAIL' END as status,
       relrowsecurity as enabled
FROM pg_class 
WHERE relname = 'users';

SELECT 'CHECK 6: RLS on user_admins' as check_name,
       CASE WHEN relrowsecurity THEN '✅ PASS' ELSE '❌ FAIL' END as status,
       relrowsecurity as enabled
FROM pg_class 
WHERE relname = 'user_admins';

-- ============================================================================
-- CHECK 7: RLS policies exist
-- ============================================================================
SELECT 'CHECK 7: Users Policies' as check_name,
       CASE WHEN COUNT(*) >= 2 THEN '✅ PASS' ELSE '❌ FAIL' END as status,
       COUNT(*) as policy_count
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'users';

SELECT 'CHECK 7: Admin Policies' as check_name,
       CASE WHEN COUNT(*) >= 3 THEN '✅ PASS' ELSE '❌ FAIL' END as status,
       COUNT(*) as policy_count
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_admins';

-- ============================================================================
-- DETAILS: Show your complete setup
-- ============================================================================
SELECT '========== YOUR USER DETAILS ==========' as section;

SELECT 'Email' as field, email as value
FROM auth.users 
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f'
UNION ALL
SELECT 'User ID' as field, id::text as value
FROM users 
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f'
UNION ALL
SELECT 'Admin Status' as field, 
       CASE WHEN active THEN 'Active Admin' ELSE 'Not Admin' END as value
FROM user_admins 
WHERE user_id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f'
UNION ALL
SELECT 'Client UUID' as field, 
       COALESCE(client_uuid::text, 'NULL (Admin - can switch clients)') as value
FROM users 
WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f';

-- ============================================================================
-- SUMMARY: Overall health check
-- ============================================================================
SELECT '========== OVERALL STATUS ==========' as section;

WITH checks AS (
    SELECT 
        (SELECT COUNT(*) FROM auth.users WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f') as auth_user,
        (SELECT COUNT(*) FROM users WHERE id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f') as user_record,
        (SELECT COUNT(*) FROM user_admins WHERE user_id = '6ad5fd64-cf3c-4c7e-b6b4-400a4708b51f' AND active = true) as admin_status,
        (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'user_admins' AND column_name = 'user_id') as has_user_id_col
)
SELECT 
    CASE 
        WHEN auth_user > 0 AND user_record > 0 AND admin_status > 0 AND has_user_id_col > 0
        THEN '🎉 SUCCESS: Everything is properly configured!'
        ELSE '⚠️  INCOMPLETE: Some steps may have failed'
    END as result,
    auth_user as "Auth User Exists",
    user_record as "User Record Exists", 
    admin_status as "Admin Status Active",
    has_user_id_col as "user_id Column Added"
FROM checks;
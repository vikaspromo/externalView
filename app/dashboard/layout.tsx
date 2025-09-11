import { DashboardErrorBoundary } from '@/app/components/DashboardErrorBoundary'

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <DashboardErrorBoundary>
      {children}
    </DashboardErrorBoundary>
  )
}
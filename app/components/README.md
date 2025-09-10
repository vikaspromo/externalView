# Components Directory Structure

## Organization

- **`/ui`** - Reusable UI components (buttons, tables, modals, etc.)
  - Generic, presentation-focused components
  - No business logic
  - Highly reusable across the application

- **`/dashboard`** - Dashboard-specific components
  - Business logic specific to dashboard functionality
  - May use UI components internally
  - Not intended for reuse outside dashboard context

- **`/auth`** - Authentication-related components
  - Login forms, auth guards, etc.
  - Handles authentication UI/UX

## Component Guidelines

1. Each component should have a single responsibility
2. Use TypeScript interfaces for all props
3. Include JSDoc comments for complex components
4. Keep components small and focused
5. Extract shared logic into custom hooks
6. Use composition over inheritance

## Naming Conventions

- Components: PascalCase (e.g., `Button.tsx`)
- Directories: lowercase (e.g., `/ui`)
- Index files for barrel exports when appropriate
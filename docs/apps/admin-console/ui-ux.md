# Admin Console UI/UX

## Information architecture

Use the sidebar module order from `src/config/permissions.ts`. Role landing paths should open the first permitted operational area. Detail pages must preserve the originating queue and filters when returning.

## Operational patterns

Use dense but readable tables, explicit status badges, branch labels, filter controls, detail panels, confirmation dialogs, and clear action ownership. Do not rely on color alone for status or permission.

## Required states

Loading, empty database, query error/retry, mutation pending/success/failure, no-access, signed-out, expired session, and direct route refresh must be designed for every page.

## Accessibility and safety

Keyboard navigation, focus management, visible labels, semantic tables, accessible dialogs, and screen-reader status announcements are required. Hide raw SQL, credentials, stack traces, prescription images, and private member details from generic error surfaces.

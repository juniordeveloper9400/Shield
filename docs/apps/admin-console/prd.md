# Admin Console PRD

**Product:** SHIELD operations console  
**Implementation:** `shieldweb/` React/Vite app  
**Status:** Internal current-state baseline

## Problem

Staff need focused operational views over the shared `app` schema to manage stores, catalogue, orders, prescriptions, privilege activations, lab services, appointments, members, and admin access.

## Users

Super Admin, Admin, Pharmacy Admin, Lab Admin, and Appointments Admin. Pharmacy work is intended to be limited to one branch.

## Goals

- Give each role a useful landing queue.
- Make status transitions explicit and inspectable.
- Keep pharmacy branch context visible.
- Prevent unauthorized modules and actions.

## Current limitations

Authentication is a bundled static credential list with a `localStorage` login id, and Neon queries run directly from browser code. This console is internal-only until server-side identity, authorization, and database access exist.

## Success outcomes

Operators can resolve their permitted queues, see empty/error/no-access states, update valid statuses, and leave an auditable trail without exposing cross-branch data.

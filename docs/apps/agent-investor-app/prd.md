# Agent / Investor App PRD

**Product:** SHIELD partner-enabled Flutter app  
**Implementation:** `shield agent_invester/`  
**Status:** Current implementation requires product-boundary confirmation

## Problem

Converted SHIELD members need access to agent and investor status, earnings/investment information, and partner workflows without accidentally retaining an unauthorized member-only or partner-only state.

## Actors

- Converted agent with hierarchy, sales, earnings, transfers, withdrawals, and customer-plan context.
- Converted investor with store investment, units, plan, and ROI context.
- Ordinary member whose persona lookup returns no conversion.

## Current behavior

The app restores Firebase phone sessions, resolves persona rows from Neon, applies agent/investor services, and on Android shows a web-access screen for converted users. On web, converted users retain the app and receive persona cards. Most member commerce and care modules are also present because this project is currently a parallel full-app tree.

## Required product decisions

Confirm whether this becomes a dedicated partner portal, a shared client variant, or a transitional build. Define separate navigation, permissions, payout rules, investor disclosures, and release ownership before major divergence.

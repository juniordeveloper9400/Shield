# Agent / Investor App UI/UX

## Current experience

The app uses the Sahakar 360 Material 3 theme and member shell. Converted Android users see a web-access state; converted web users see persona cards in the home experience.

Product-detail FAQs match the member app: a full-width white section with larger
questions, thin dividers and trailing chevrons. Tapping a question expands its
answer below it; tapping again collapses it. Q/A badges and plus/minus icons are
removed. The updated web build must be deployed for this to appear online.

## Partner experience requirements

After the product boundary is decided, define dedicated navigation for agent and investor work, separate financial summaries from member wallet balances, show reporting periods and source timestamps, and make withdrawal/plan-change actions confirmation-sensitive.

## Required states

Persona loading, ordinary member, agent, investor, both-persona conflict, stale data, unavailable Neon, unauthorized action, signed-out, and app-resume refresh states must be explicit.

Do not present earnings, ROI, or investment values without clear status, currency, period, and authoritative source context.

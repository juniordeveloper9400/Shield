# SHIELD Claude Code Instructions

Use `AGENTS.md` as the canonical repository guidance and `docs/README.md` as the documentation index.

Before editing:

1. Identify whether the change belongs to the root Flutter app, `shieldweb`, or `backend`.
2. Read the relevant architecture and setup document.
3. Check `git status` and preserve unrelated changes.

Safety requirements:

- Never expose or commit `.env`, Neon credentials, generated `lib/data/neon/neon_secret.dart`, Firebase service-account keys, passwords, or keystores.
- Treat the current admin-console credentials and browser `localStorage` session as a development/internal implementation, not production authentication.
- Ask for confirmation before destructive database commands such as schema recreation or wipes.

Run focused validation after changes, then the broader checks listed in `AGENTS.md` when the touched surface warrants them. Keep documentation aligned with the code that exists today.

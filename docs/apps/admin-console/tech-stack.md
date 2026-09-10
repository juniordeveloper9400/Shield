# Admin Console Tech Stack

| Concern | Choice |
| --- | --- |
| UI runtime | React 18 |
| Language | TypeScript |
| Build/dev | Vite 5 |
| Routing | React Router 6 |
| Styling | Tailwind CSS 3, PostCSS, Autoprefixer |
| Database client | `@neondatabase/serverless` |
| Auth current state | Source-bundled credentials and `localStorage` |
| Hosting | Static SPA; Vercel config present |
| Type/build checks | `npm run typecheck`, `npm run build` |

Open stack decisions are the server/API framework, managed identity provider, audit logging, and secure image/data access path. Record each in an ADR before implementation.

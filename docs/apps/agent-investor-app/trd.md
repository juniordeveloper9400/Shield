# Agent / Investor App TRD

## Runtime

The project is a second Flutter/Dart app with Firebase Core/Phone Auth, Neon HTTP and PostgreSQL integrations, location/map plugins, image processing, and the same broad feature module set as the root app.

## Persona resolution

`PersonaService` observes `AuthService.currentUser`, loads agent/investor data by phone through `PersonaRepository`, applies `AgentService`/`InvestorService`, and refreshes on app resume. Results are ignored when the signed-in phone changes during an in-flight request.

## Platform behavior

Android sends converted members to `WebAccessScreen`; web keeps the full app and shows persona content. This split must be treated as a deliberate product contract until the partner app is separated.

## Technical risks

The project duplicates root app code and configuration, has no discovered test directory, and may drift in schema, dependencies, or auth behavior. Changes must be compared against the root app and documented as intentional.

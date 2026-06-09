# Battery Beacon × Umami Integration Plan

**Goal:** wire Battery Beacon (native macOS app) into the existing self-hosted
Umami at **`https://analytics.theportlandcompany.com`**, as phase 1 of the
broader "advanced tracking + author-built CRM" effort (Forge task `56ae9fb1`,
project *Battery Beacon* in TPC org).

## Existing infrastructure (discovered 2026-06-07)

| Component | Location |
|---|---|
| Umami server | `~/Sites/tpc-analytics-umami` → Cloudflare Workers + Durable Objects, repo `s3w47m88/tpc-umami-cloudflare` |
| Server URL | `https://analytics.theportlandcompany.com` (collector `/t.js`, API `/api/send`) |
| Database | Supabase PostgreSQL |
| Site connector tooling | `~/Sites/tpc-analytics-umami/plugins/umami-site-connector/scripts/connect-site.mjs` (idempotent website/team creation; needs `UMAMI_BASE_URL`, `UMAMI_ADMIN_USERNAME`, `UMAMI_ADMIN_PASSWORD` in `.env`) |
| Reference integrations | style-aesthetics (Next.js), oasis-property-services (React) |

## Key design point: native app ≠ browser

Umami's `t.js` tracker is browser-only. A macOS app integrates by POSTing
directly to Umami's event API:

```
POST https://analytics.theportlandcompany.com/api/send
Content-Type: application/json
User-Agent: <real UA string — Umami rejects empty/bot UAs>

{ "type": "event",
  "payload": {
    "website": "<WEBSITE_ID>",
    "hostname": "batterybeacon.app",
    "url": "/app/<screen-or-event-context>",
    "name": "<event_name>",        // omit for pageview-style hits
    "data": { ... }                 // custom event properties
  } }
```

## Phases

### Phase 1 — Register the app as an Umami "website"
1. Run `connect-site.mjs` (or the Umami admin API) to create website
   **"Battery Beacon (macOS app)"**, domain `batterybeacon.app` → capture the
   new `WEBSITE_ID`.
2. Verify it appears in the Umami dashboard.

### Phase 2 — Swift telemetry client (in this repo)
1. New `Sources/BatteryBeaconShared/Analytics/UmamiClient.swift`:
   - `URLSession`-based, async, fire-and-forget with a small offline queue
     (persist failed events to Application Support, retry on next launch).
   - Constants: endpoint URL + website id (id is not secret; ship in code).
   - Synthesized desktop UA (`Mozilla/5.0 (Macintosh; ...)`) so Umami's
     bot-filter accepts events; include `data.app_version` from the bundle.
   - A stable **anonymous install ID** (UUID in `UserDefaults`, app-group
     scoped) sent as `data.install_id` — this is the join key the future CRM
     will use.
2. Event taxonomy (v1):
   - `app_launched` (version, macOS version, first_launch flag)
   - `alert_fired` (threshold %, charging state)
   - `settings_changed` (which setting, new value class — no raw values)
   - `app_quit` (session length bucket)
3. **Opt-out toggle** in Settings ("Share anonymous usage analytics", default
   ON) — gates all sends.

### Phase 3 — Verify + ship
1. Build, run locally, confirm events land in the Umami dashboard in realtime.
2. Bump to 1.0.4 (build 12), upload, submit (existing `release`/`bb_submit`
   lanes).
3. **App Privacy already declared as "collects data"** (published 2026-06-07)
   — confirm declared types cover: *Identifiers (User ID — install_id)* +
   *Usage Data (Product Interaction)*, purpose *Analytics*. Keep "used for
   tracking" = **No** unless/until data is linked across companies' apps/sites
   (Apple's ATT definition); Umami first-party analytics does not require it.

### Phase 4 — CRM bridge (next, separate plan)
- The author-built CRM consumes Umami's Supabase tables (same database
  account) keyed on `install_id`; optional in-app email capture would upgrade
  anonymous installs to CRM contacts. Scope in the Forge task.

## Risks / notes
- Cloudflare Worker rate-limits & bot filtering: test `/api/send` from a
  non-browser UA early (Phase 2 first task).
- Don't send events in the sandboxed App Store build without the
  `com.apple.security.network.client` entitlement — check `project.yml`.
- Review impact: minimal; analytics with opt-out + accurate privacy labels is
  standard.

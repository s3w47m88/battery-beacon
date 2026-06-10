# Battery Beacon — Advanced Tracking + Author CRM Plan

**Status:** PLAN ONLY. Implementation of the CRM bridge (Phase C) is **on hold**
per user instruction. Phases 1–3 of `UMAMI_INTEGRATION_PLAN.md` (basic Umami
analytics) are already shipped in 1.0.4 (build 12).

**Forge task:** `56ae9fb1` (TPC org → Battery Beacon project).

---

## ⚠️ Reality check before "aggressive"

The original ask was "advanced and aggressive tracking of users." That framing
collides head-on with the platform we ship on — and we just **got rejected once
already** on privacy (Guideline 5.1.1). So this plan deliberately defines
"aggressive" as **maximally rich first-party product analytics with durable
identity**, NOT covert or cross-party tracking. The hard guardrails:

| Allowed (ships, low review risk) | Forbidden (rejection / removal risk) |
|---|---|
| ✅ Rich first-party event stream to our own Umami | ❌ Apple's ATT "tracking" (linking to data from other companies' apps/sites for ads) |
| ✅ Stable anonymous `install_id` as identity spine | ❌ Device fingerprinting / reading IDFV/serial to re-identify after reinstall |
| ✅ User-provided email → CRM contact (opt-in) | ❌ Silently harvesting email/contacts/AddressBook |
| ✅ Coarse IP-derived geo (Umami default) | ❌ Precise location, or selling/sharing data to third parties |
| ✅ Declared in App Privacy + privacy policy | ❌ Collecting anything not declared |

Everything below stays in the left column. Anything in the right column is a
non-starter and is called out so it doesn't creep back in.

---

## Architecture overview

```
Battery Beacon (macOS)
   │  UmamiClient (already shipped) — POST /api/send
   ▼
analytics.theportlandcompany.com  (self-hosted Umami on Cloudflare Workers)
   │  writes events → Supabase Postgres (DATABASE_URL in tpc-analytics-umami/.env)
   ▼
[Phase C] CRM sync job (NEW) reads Umami's website_event / session tables
   │  keyed on install_id (and email once captured)
   ▼
Author CRM (NEW service) — contacts, timelines, segments, lifecycle
```

The CRM never talks to the app directly. The app's only network egress stays
the single `/api/send` endpoint already declared — so the attack surface and
the privacy declaration do not grow when the CRM is added later.

---

## Phase A — Deepen the event stream (app-side, shippable now)

Extend the existing `UmamiAnalytics` taxonomy. Each event already carries
`install_id` + `app_version`; add the events below. Keep payloads to **classes
of values, never raw personal content**.

| Event | Properties | Why it matters for CRM |
|---|---|---|
| `app_launched` *(shipped)* | macos, first_launch | activation / DAU |
| `alert_fired` *(shipped)* | threshold, charging | core value moment |
| `settings_changed` | setting_key, value_class | feature adoption, intent |
| `threshold_added` / `threshold_removed` | count | power-user signal |
| `peripheral_alert` | device_class (mouse/kbd/…), critical | feature breadth |
| `analytics_opt_out` | — | suppress + honor immediately |
| `app_quit` *(shipped)* | session_seconds_bucket | engagement depth |
| `update_applied` | from_version, to_version | upgrade funnel |

Derived metrics (computed in CRM, not sent): days-active, alerts-per-week,
power-user score, churn-risk (no launches in N days).

## Phase B — Identity spine (app-side, opt-in email)

1. **Anonymous spine:** `install_id` (already shipped) is the durable key. It is
   per-install (resets on reinstall — acceptable; we do NOT fight this with
   fingerprinting).
2. **Optional email upgrade (opt-in only):** a non-blocking "Get battery tips &
   release notes" field in Settings. If the user enters an email, send a
   `contact_identified` event with `email` so the CRM can graduate the anonymous
   install into a named contact. Requires:
   - Explicit checkbox, default OFF.
   - App Privacy: add **Contact Info → Email Address**, purpose **App
     Functionality / Product Personalization**, *not* linked to tracking.
   - Privacy policy update describing email capture + how to unsubscribe.

## Phase C — Author CRM + sync (**ON HOLD** — design only)

**Data model (CRM, Postgres):**
- `contacts` (id, install_id, email?, first_seen, last_seen, app_version,
  os_version, country, lifecycle_stage, churn_risk, consent_flags)
- `events` (id, contact_id, name, props jsonb, ts) — mirrored/rolled-up from
  Umami
- `segments` (rule-based: "activated", "power user", "at-risk", "opted-out")

**Sync options (pick at implementation time):**
- **B1 (recommended):** read-only nightly + 5-min incremental job querying
  Umami's Supabase `website_event`/`session` tables (same DB account already in
  `tpc-analytics-umami/.env`), upsert into CRM keyed on `install_id`. Cheapest,
  no app changes, reuses existing infra.
- **B2:** dual-write — app POSTs to a CRM ingest endpoint too. Rejected: doubles
  app egress + privacy surface.
- **B3:** Umami webhook/API polling. Viable if we avoid direct DB coupling.

**Lifecycle automation (later):** opted-in emails only — onboarding tips,
re-engagement for at-risk installs, release announcements. Reuse the existing
TPC email tooling; never email a non-opted-in contact.

## Phase D — Compliance (gates every phase)

- **App Privacy** must list every type *before* it ships: Identifiers
  (install_id), Usage Data (product interaction), Diagnostics; + Email (Phase B)
  when added. Tracking = **No** throughout.
- **Privacy policy** (`PRIVACY.md`, already live) updated in lockstep with any
  new collection — this is what got us rejected once; never add a field without
  updating the policy first.
- **Opt-out** stays global and immediate (already shipped); add a delete/contact
  path for emailed contacts (GDPR/CCPA basic hygiene).
- **Honor opt-out in CRM:** an `analytics_opt_out` event must suppress the
  contact from all sync + automation.

---

## Sequencing / recommendation

1. **Now:** Phase A events (low risk, no privacy change beyond existing
   declaration) — bundle into a future 1.0.x once 1.0.4 clears review.
2. **Next minor:** Phase B email opt-in (requires App Privacy + policy update;
   ship together).
3. **Hold:** Phase C CRM + sync — start only when the user lifts the hold;
   recommend sync option **B1**.

Do not batch privacy-affecting changes with unrelated app updates — each
collection change should ship with its matching App Privacy + policy edit so a
rejection is easy to reason about.

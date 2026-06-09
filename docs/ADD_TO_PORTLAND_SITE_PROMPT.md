# Agent Prompt — Add "Battery Beacon" to theportlandcompany.com

You are adding a new product/app listing to **theportlandcompany.com**. Add it
the way the site already lists its other products — do not invent a new layout
or design system. Discover the codebase's conventions first, match them, and
stage the change for review. **Do not deploy** (no `git push`, no CI deploy, no
Pages/Workers publish) unless the human explicitly says to.

## Step 0 — Orient before editing
1. Locate the theportlandcompany.com repo (ask the human for the path if it is
   not the current working directory). Confirm you are in the right repo.
2. Identify the stack: static HTML, Next.js/Astro/Hugo, WordPress, a headless
   CMS, etc. Find how **existing products / portfolio items / apps** are
   represented (a `products/` dir, a CMS collection, a data file like
   `products.json`/`*.md` frontmatter, a component, or a CMS entry).
3. Pick ONE existing product entry as your template. Mirror its file location,
   naming, frontmatter/schema, image handling, routing, and nav/menu wiring.
   The new entry must appear everywhere comparable products appear (listing
   page, nav, sitemap, structured data) — not just as an orphan page.
4. If the products are managed in an external CMS (not in the repo), stop and
   tell the human exactly what to enter and where; do not fake a page in code.

## Product facts (authoritative — use verbatim where copy is needed)

- **Name:** Battery Beacon
- **Tagline:** Never overcharge your Mac again.
- **Category:** macOS utility / menu bar app
- **Platform:** macOS 14 (Sonoma) or later; Apple Silicon. Built with SwiftUI;
  respects system theme including Liquid Glass on macOS 26 (Tahoe).
- **Price:** Free (confirm with human if the site shows pricing).
- **Bundle ID:** com.spencerhill.batterybeacon
- **App Store ID:** 6768814007
- **App Store URL:** https://apps.apple.com/app/id6768814007
  ⚠️ Version 1.0.2 is currently **WAITING_FOR_REVIEW**, not yet released. The
  link will 404 until Apple approves it. Confirm the app is live (or use a
  "Coming soon to the Mac App Store" treatment) before publishing the page.
- **Source / support URL:** https://github.com/s3w47m88/battery-beacon

### Short description (1–2 sentences)
> A tiny menu bar utility that notifies you the moment your Mac's battery
> reaches the percentage you choose — so you can unplug at 95%, 100%, or any
> threshold you set, and never overcharge.

### Long description
> Battery Beacon is a tiny menu bar utility that notifies you the
> moment your Mac's battery reaches the percentage you choose — so you can
> unplug at 95%, 100%, or any threshold you set, and never overcharge.

### Feature bullets
- Lives in the menu bar; shows current battery % and a charging bolt.
- Configurable alert thresholds with sliders (default 95% and 100%).
- Native macOS notifications fire near the battery icon at each threshold while
  plugged in.
- Optional alert sound.
- Thresholds reset automatically when you unplug — one alert per threshold per
  charge cycle.
- Built with SwiftUI; respects your system theme, including Liquid Glass on
  macOS 26.

### Keywords (for meta/SEO if the template uses them)
battery, alert, charge, menu bar, notification, utility, laptop, macbook

## Assets
Source images live in this app's repo at
`tpc-battery-beacon/`:
- App icon: `Assets/AppIcon.png`
- Marketing screenshots (2880×1800 PNG):
  - `appstore-screenshots/en-US/01-glance-store.png` — collapsed popover ("at a glance")
  - `appstore-screenshots/en-US/02-stats-store.png` — live battery stats
  - `appstore-screenshots/en-US/03-alerts-store.png` — threshold alerts (hero)
- Copy these into theportlandcompany.com's asset pipeline at whatever size /
  format / location the existing products use (resize/optimize to match — do
  not drop full 2880px PNGs into a page that serves thumbnails). Provide alt
  text from the descriptions above.

## Deliverable & guardrails
- Add the listing following the site's existing product convention; wire it
  into listing pages, navigation, and any sitemap/structured-data the template
  generates.
- If the template has SEO/OpenGraph fields, fill title, description, and a
  representative image (the alerts screenshot is the strongest hero).
- Run the site locally and verify the new page renders, links work, the App
  Store link behaves correctly (account for the not-yet-released state), and
  images load. Capture a screenshot of the rendered page for the human.
- ✅ match existing patterns, optimize assets, stage locally, verify in-browser.
  ❌ no new bespoke layout, no broken/404 App Store link presented as live, no
  giant unoptimized images, no deploy without explicit instruction.
- When done, summarize what you added (files changed, where it appears in nav /
  listings) and ask before deploying.

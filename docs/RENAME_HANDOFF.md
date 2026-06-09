# Battery Beacon Rename + App Store Submission — Session Handoff

**Purpose:** continue the in-flight rebrand of *Battery Charged Notification*
→ **Battery Beacon** and ship 1.0.3 to the App Store. Most of the heavy
lifting is done — what remains are two UI-only one-time steps (an Apple
agreement, App Privacy), a final submit, and the GitHub/local-folder
rename.

The approved plan lives at `~/.claude/plans/smooth-singing-melody.md`.

---

## TL;DR — what to do next

1. **Sign the new Apple agreement** in App Store Connect (UI; *required, currently blocking ALL API calls*).
2. **Set App Privacy = Data Not Collected → Publish** for the new app (UI; API key can't do this).
3. Run `fastlane mac bb_submit` → confirm `WAITING_FOR_REVIEW`.
4. Delete the **old** app *Battery Charged Notification* (cancel its 1.0.2 review first, then delete in UI).
5. Commit the uncommitted Fastfile helper lanes, then do Phase 6: rename GitHub repo → `battery-beacon`, update remote, merge `rename/battery-beacon` → `master`, rename local folder → `tpc-battery-beacon`.

---

## State of the world (snapshot 2026-06-03)

### Decisions already made (user-confirmed)

| Thing | Old | New |
|---|---|---|
| Display name | Battery Charged Notification | **Battery Beacon** |
| Bundle ID (main) | `com.spencerhill.fullbatteryalert` | **`com.spencerhill.batterybeacon`** |
| Bundle ID (widget) | …`.widgets` | **…`.widgets`** (under batterybeacon) |
| App Group | `group.com.spencerhill.fullbatteryalert` | **`group.com.spencerhill.batterybeacon`** |
| Xcode target / scheme / project / SPM | `FullBatteryAlert` | **`BatteryBeacon`** |
| Source dirs | `Sources/FullBatteryAlert{,Shared,Widgets}` | **`Sources/BatteryBeacon{,Shared,Widgets}`** |
| @main struct | `FullBatteryAlertApp` | **`BatteryBeaconApp`** |
| Widget bundle struct | `FullBatteryAlertWidgetsBundle` | **`BatteryBeaconWidgetsBundle`** |
| Version | 1.0.2 (build 10) | **1.0.3 (build 11)** |
| SKU | `fullbatteryalert001` | **`batterybeacon001`** |
| GitHub repo | `s3w47m88/battery-charged-notification` | `s3w47m88/battery-beacon` (**not done**) |
| Local folder | `…/Sites/tpc-battery-charged-notification` | `…/Sites/tpc-battery-beacon` (**not done**) |

### App Store Connect (new app)

- **App:** "Battery Beacon", Apple ID **`6773545790`**, bundle `com.spencerhill.batterybeacon`, SKU `batterybeacon001`.
- **Build 11 (1.0.3):** uploaded, `VALID` (id `163a4a53-3372-4f11-a74a-ac1e4af8bbc9`).
- **Editable version:** 1.0.3, `PREPARE_FOR_SUBMISSION`, id `4b5d05f3-776c-48f3-bdd7-31a580cd5743`.
- **Done via API:** version localization (description, keywords, supportUrl, marketingUrl, promotionalText), build attached, screenshots (3 PNGs, all `COMPLETE`), Free pricing (`appPriceSchedules`), age rating (all NONE/false), review contact (Spencer Hill, thespencerhill@gmail.com, 5035550100), review notes.
- **Not done (blockers):**
  - **App Privacy "Data Collection"** — must be set to *Data Not Collected* and Published in the UI. The `.p8` API key cannot read or write this; the endpoints live on Apple's internal *iris* API. Confirmed by direct probe — `v1/appDataUsages` and `v1/apps/{id}/dataUsagePublishState` both return "does not exist" via the API key.
  - **Apple developer agreement** — `review_status` and `asc_versions` now return: *"A required agreement is missing or has expired."* Apple rolled out a new agreement during the session gap. **All API calls will fail until you accept it** in ASC → Agreements, Tax, and Banking.

### Old app — to be retired

- "Battery Charged Notification", bundle `com.spencerhill.fullbatteryalert`.
- Last known: 1.0.2 (build 10) was `WAITING_FOR_REVIEW`. Per user decision: **cancel review + delete the app**. Recommended order:
  1. `fastlane mac cancel_review` (already retargeted to new bundle id — see "Caveat" below).
  2. Delete the old app in App Store Connect UI (Spaceship `App.delete` isn't reliable for ASC).

### Repo & branches

- **Working branch:** `rename/battery-beacon` (off `master`), 3 commits ahead:
  - `1b6549f` Rename app to Battery Beacon: sources, project, build config
  - `3069eaf` Rename to Battery Beacon: fastlane lanes + ASC scripts
  - `0e9b818` Rename to Battery Beacon: README + docs
- **Uncommitted:** `fastlane/Fastfile` has +245 lines of temporary helper lanes from this session (see below). One real bug fix in that diff is worth keeping — see "Real bug fix to land".
- **Stale branches** that the project deploy doc says to merge/clean up later: `add-upload-screenshots-lane`, `claude/agitated-tu-831d8d`, `claude/cranky-chebyshev-1317a4`, `claude/hopeful-aryabhata-cad7f7`, `claude/nice-payne-57dfa6`, `claude/nostalgic-beaver-94823d`, `claude/sweet-poincare-4f34df`, `real-screenshots`. **Confirm with user before deleting.**
- `.gitignore` was updated this session to include `.claude/` (agent worktrees/plans/settings — never commit).

### Local rename verification

- `xcodegen` regenerated `BatteryBeacon.xcodeproj` cleanly.
- Unsigned Release build succeeded; produced `Battery Beacon.app` with `CFBundleName=Battery Beacon`, `CFBundleIdentifier=com.spencerhill.batterybeacon`, version 1.0.3 / build 11.
- Tracked tree is clean of legacy strings (`fullbatteryalert`, `FullBatteryAlert`, `Battery Charged`, `Fully Battery`). Verified by full repo grep.

### Provisioning

- Apple Distribution cert (`874Y6B43Q6`) reused.
- New profile **`com.spencerhill.batterybeacon AppStore`** created via `get_provisioning_profile` (with `provisioning_name:` set explicitly so it matches `PROVISIONING_PROFILE_SPECIFIER` in `project.yml`). Stored under `fastlane/profiles/`.
- Widget bundle ID / app group **not registered** — intentionally skipped because the widget target is disabled in `project.yml` (same as the prior shipping build); the build only signs the main app. If the widget is re-enabled later, run an adapted `setup_widget_capabilities` against `com.spencerhill.batterybeacon.widgets` + `group.com.spencerhill.batterybeacon`.

---

## Uncommitted Fastfile changes

`git diff fastlane/Fastfile` contains:

### Real bug fix to land (keep this)

In the `release` lane's *version localization* step, the original code patched
`description / keywords / supportUrl / marketingUrl / promotionalText / whatsNew`
in a single call. `whatsNew` is **not allowed on a first version of a brand-new
app**, and that one disallowed field caused the *entire* patch to be rejected
— silently wiping all the required fields. The fix splits it into two calls:
the required-fields patch first, then a separate `whatsNew` patch wrapped in
`rescue` so it harmlessly fails on first versions and works on updates.

### Throwaway diagnostic / helper lanes (remove before committing)

All added by this session, all start with `bb_` or `wait_`:

- `wait_app` — polls until the ASC app record exists (used during stand-up). No longer needed.
- `wait_build` — polls build processing state until `VALID`. Generally useful; could keep.
- `bb_diag` / `bb_diag2` — diagnostic dumps of version/loc/pricing/screenshots/privacy state.
- `bb_pricing` — sets Free pricing via `appPriceSchedules` (genuinely useful for any future new app; consider keeping as a real lane).
- `bb_privacy` — attempts to declare `DATA_NOT_COLLECTED` + publish. **Does not work via API key** (404 on the public API). Remove or guard.
- `bb_wait_privacy` — polls publish state. Also doesn't work via API key. Remove.
- `bb_submit` — submit-only lane that doesn't re-upload screenshots. Genuinely useful; consider keeping.

**Suggested commit hygiene before Phase 6:**
- Land the localization split (the real fix) as its own commit.
- Decide whether `bb_pricing`, `bb_submit`, `wait_build` graduate to real lanes (rename without `bb_` prefix, add `desc`) or get deleted.
- Delete `wait_app`, `bb_diag`, `bb_diag2`, `bb_privacy`, `bb_wait_privacy`.

---

## Resume playbook

### Step 1 — Accept the Apple agreement (UI; blocking)

Open <https://appstoreconnect.apple.com/agreements/> and sign whatever is pending. After this, `fastlane mac review_status` (or any lane) should stop returning the *required agreement* error.

Verify:
```bash
fastlane mac review_status
```

### Step 2 — App Privacy (UI; blocking)

Open <https://appstoreconnect.apple.com/apps/6773545790/distribution/privacy>:
1. **Get Started** (or **Edit**).
2. Answer **"No, we do not collect data from this app."**
3. **Publish**.

(No way to verify via API key — proceed once visibly published.)

### Step 3 — Submit Battery Beacon 1.0.3 for review

```bash
cd /Users/spencerhill/Sites/tpc-battery-charged-notification
fastlane mac bb_submit
```

`bb_submit` (defined in the uncommitted Fastfile diff): grabs the editable version, ensures a review submission exists with build 11 as an item, dumps screenshot states, and patches the submission with `submitted: true`. On success, prints `BBSUBMIT submitted sub=<id>` and the version state.

Then confirm:
```bash
fastlane mac review_status
# Expect: version 1.0.3 state=WAITING_FOR_REVIEW, build 11: processing=VALID
```

If submit fails with `appStoreVersions ... not in valid state`, run `fastlane mac bb_diag2` to see what's still missing. The likely culprits at this point are pricing (set), screenshots (COMPLETE), or privacy (the one thing requiring UI).

### Step 4 — Retire the old app

```bash
# Cancel the in-flight 1.0.2 review of the OLD app.
# IMPORTANT: cancel_review currently targets com.spencerhill.batterybeacon
# (the new bundle id) because of the global rename. Edit the lane to
# temporarily target the OLD bundle id, OR do it via UI.
```

Temporary cancel of old app (paste into a one-off lane or run from UI):
```ruby
# In ASC UI: My Apps → Battery Charged Notification → App Review
# → "Remove from Review" / "Cancel Submission".
# Then: My Apps → settings → Remove App (irreversible).
```

If doing via API, here's a one-off snippet — add as a temp lane, run, delete:
```ruby
lane :old_cancel do
  require 'spaceship'
  token = Spaceship::ConnectAPI::Token.create(key_id: "XG3FW9LT9Q", issuer_id: "178bab61-1c45-4f62-9525-55f8ed15a98d", filepath: File.expand_path("~/.appstoreconnect/private_keys/AuthKey_XG3FW9LT9Q.p8"))
  Spaceship::ConnectAPI.token = token
  app = Spaceship::ConnectAPI::App.find("com.spencerhill.fullbatteryalert")
  Spaceship::ConnectAPI.get_review_submissions(app_id: app.id, filter: { state: "WAITING_FOR_REVIEW,IN_REVIEW,READY_FOR_REVIEW" }).to_models.each do |s|
    Spaceship::ConnectAPI.patch_review_submission(review_submission_id: s.id, attributes: { canceled: true }) rescue nil
    UI.message("cancelled #{s.id}")
  end
end
```

Then delete the old app in the ASC UI (Spaceship `App.delete` exists but the modern web flow is more reliable).

### Step 5 — Phase 6: Repo + folder rename

Per the project deploy doc and the approved plan:

```bash
cd /Users/spencerhill/Sites/tpc-battery-charged-notification

# 1) Clean up Fastfile (see "Uncommitted Fastfile changes" above), commit.
# Suggested: one commit with the localization bug fix + bb_pricing/bb_submit
# graduated to real lanes; remove the diagnostic lanes.

# 2) Merge into master.
git checkout master
git merge --no-ff rename/battery-beacon -m "Rename to Battery Beacon"

# 3) Rename GitHub repo (GitHub keeps redirects).
gh repo rename battery-beacon -R s3w47m88/battery-charged-notification

# 4) Update local remote.
git remote set-url origin git@github.com:s3w47m88/battery-beacon.git

# 5) Push.
git push -u origin master

# 6) Review + delete stale branches (CONFIRM WITH USER FIRST):
#    add-upload-screenshots-lane, real-screenshots, all claude/* branches,
#    and rename/battery-beacon after merge.
git branch -d rename/battery-beacon
git push origin --delete rename/battery-beacon
# (repeat for each, after user confirmation)

# 7) Rename local folder. Note: this changes cwd — restart any shells/tools
# pointing at the old path. Memory/plan dirs under ~/.claude key off the path.
cd ~/Sites
mv tpc-battery-charged-notification tpc-battery-beacon
cd tpc-battery-beacon
```

---

## Reference

### Key identifiers

| What | Value |
|---|---|
| Team ID | `VP38993WK6` |
| ASC API key id | `XG3FW9LT9Q` |
| ASC issuer | `178bab61-1c45-4f62-9525-55f8ed15a98d` |
| Key file | `~/.appstoreconnect/private_keys/AuthKey_XG3FW9LT9Q.p8` |
| **New** app Apple ID | `6773545790` |
| **New** main bundle id | `com.spencerhill.batterybeacon` |
| New widget bundle id | `com.spencerhill.batterybeacon.widgets` (not yet registered) |
| New app group | `group.com.spencerhill.batterybeacon` (not yet created) |
| **New** version id | `4b5d05f3-776c-48f3-bdd7-31a580cd5743` (1.0.3) |
| **New** build id | `163a4a53-3372-4f11-a74a-ac1e4af8bbc9` (build 11) |
| **Old** main bundle id | `com.spencerhill.fullbatteryalert` |
| **Old** Apple ID | `6768814007` |
| Distribution cert | `874Y6B43Q6` |
| New provisioning profile name | `com.spencerhill.batterybeacon AppStore` |

### Direct ASC URLs

- New app: <https://appstoreconnect.apple.com/apps/6773545790>
- New app privacy: <https://appstoreconnect.apple.com/apps/6773545790/distribution/privacy>
- New app inflight version: <https://appstoreconnect.apple.com/apps/6773545790/distribution/macos/version/inflight>
- Old app: <https://appstoreconnect.apple.com/apps/6768814007>
- Agreements: <https://appstoreconnect.apple.com/agreements/>

### API-key limitations encountered (gotchas for future agents)

- **Cannot create app records.** `apps: CREATE` is disallowed; new apps must be made in the ASC UI (or via Apple-ID Spaceship session with interactive 2FA).
- **Cannot read/write App Privacy (data collection).** All `appDataUsages*` endpoints return *"resource does not exist"* on the public API — they live on the *iris* host, Apple-ID-only.
- **Pricing patch via `Spaceship::ConnectAPI.patch_app(app_price_tier_id:)` no-ops.** The `prices` relationship doesn't exist on `apps` anymore. Use the modern `appPriceSchedules` POST instead (see `bb_pricing` lane).
- **First-version localization rejects `whatsNew`.** Patch required fields and `whatsNew` separately so one disallowed field doesn't wipe the others. (Fixed in the uncommitted diff.)
- **Provisioning profile name must match `PROVISIONING_PROFILE_SPECIFIER` exactly.** Pass `provisioning_name:` to `get_provisioning_profile` so it doesn't auto-name into a mismatch.
- **`v1/apps/{id}/relationships/dataUsagesPublishState` is wrong** — the correct path is `v1/apps/{id}/dataUsagePublishState` (singular), and even that isn't accessible via the API key on this account.

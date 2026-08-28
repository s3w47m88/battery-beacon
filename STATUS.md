# Battery Beacon — Headless Release Pipeline

**Status: LIVE and verified.** Tag `v1.0.7` produced App Store Connect build **16**
(state VALID) via GitHub Actions with zero human involvement.

## How to deploy

```bash
git tag v1.2.3 && git push origin v1.2.3            # -> TestFlight
git tag v1.2.3-appstore && git push origin v1.2.3-appstore   # -> TestFlight + App Store review
```

The tag drives the marketing version (`v1.2.3` -> `1.2.3`). The build number is
computed automatically as (latest App Store Connect build + 1). Nothing else to do.

## Tag -> destination

| Tag pattern        | Result                                             |
| ------------------ | -------------------------------------------------- |
| `v*`               | Build, sign, upload to TestFlight                  |
| `v*-appstore`      | Same, then attach build to a new App Store version and submit for review |

## How it works (all headless)

- **Auth:** App Store Connect API key only — key `XG3FW9LT9Q`, issuer
  `178bab61-1c45-4f62-9525-55f8ed15a98d`. No Apple ID in Xcode, no Xcode Cloud, no OAuth.
- **Signing certs:** an `Apple Distribution` + `3rd Party Mac Developer Installer`
  identity pair, exported from the login keychain to a `.p12` and stored as a base64
  GitHub secret. CI imports it into a throwaway keychain each run.
- **Provisioning profile:** fetched and installed fresh every run from App Store
  Connect via the API key (`fastlane ci_profile`, readonly). Nothing committed, so it
  can never go stale.
- **Xcode project:** regenerated from `project.yml` with `xcodegen` in CI (the
  `.xcodeproj` is gitignored). `project.yml` is the source of truth.
- **App is macOS** (menu-bar utility, `LSUIElement`). Export method `app-store`
  produces a signed `.pkg`, uploaded with `xcrun altool -t macos`.

Workflow: `.github/workflows/release.yml`. Runs on `macos-15`, ~2–3 min to a VALID build.

## GitHub secrets (set on `s3w47m88/battery-beacon`)

`APPLE_CERTS_P12_BASE64`, `APPLE_CERTS_P12_PASSWORD`, `ASC_API_KEY_P8_BASE64`,
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `KEYCHAIN_PASSWORD`.

## What a human still must do

- **Nothing** for TestFlight — it is fully automatic on a `v*` tag.
- **App Store review** (`-appstore` tags): the submit step is best-effort and never
  fails the TestFlight upload. First-time submissions may still need App Store
  metadata/screenshots set in App Store Connect; existing metadata is reused.
- The signing certificate expires (~1 year). When it does, re-export the login
  keychain identities to a `.p12` and update `APPLE_CERTS_P12_BASE64` /
  `APPLE_CERTS_P12_PASSWORD`. The provisioning profile renews itself each run.

## Verification (2026-08-28)

- Run `33215628227` — conclusion **success**.
- App Store Connect build **16**, state **VALID**, uploaded 2026-08-28.

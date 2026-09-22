# Shared App Privacy ("nutrition label") declaration for Battery Beacon.
#
# Single source of truth for what we tell App Store Connect the app collects,
# used by both the `bb_privacy` lane and step 8.5 of the release lane so the
# two can't drift. Keep this in sync with PRIVACY.md — every entry here should
# have a matching line in the "What we collect" section there.
#
# Format follows fastlane's `upload_app_privacy_details_to_app_store` JSON
# shape (category / purposes / data_protections), one entry per data
# category. We post each category/purpose/protection combination individually
# via Spaceship::ConnectAPI.post_app_data_usage, since that's the primitive
# the existing lanes already use.
#
# The app collects opt-in, anonymous product-usage analytics (Umami) — see
# UmamiAnalytics.swift and PRIVACY.md. None of it is linked to identity and
# none of it is used for tracking (no ad identifiers, no cross-app/cross-site
# correlation).
#
# NOTE: App Store Connect rejects /apps/{id}/dataUsages for API-key tokens
# ("The relationship 'dataUsages' does not exist"), and the callers rescue
# errors, so under CI's API key this is a no-op. It only works with an Apple ID
# session. Set the label in the App Store Connect web UI (App Privacy) and keep
# it matching this list.
BB_PRIVACY_DECLARATIONS = [
  {
    # App usage events (app_launched, alert fired, app_quit) and first-launch
    # state — how the app is used.
    category: Spaceship::ConnectAPI::AppDataUsageCategory::ID::PRODUCT_INTERACTION,
    purposes: [Spaceship::ConnectAPI::AppDataUsagePurpose::ID::ANALYTICS],
    protections: [Spaceship::ConnectAPI::AppDataUsageDataProtection::ID::DATA_NOT_LINKED_TO_YOU]
  },
  {
    # Anonymous, app-local install UUID — the join key for events. Not an
    # Apple ID, device serial, or account identifier.
    category: Spaceship::ConnectAPI::AppDataUsageCategory::ID::DEVICE_ID,
    purposes: [Spaceship::ConnectAPI::AppDataUsagePurpose::ID::ANALYTICS],
    protections: [Spaceship::ConnectAPI::AppDataUsageDataProtection::ID::DATA_NOT_LINKED_TO_YOU]
  },
  {
    # App version and macOS version sent with each event.
    category: Spaceship::ConnectAPI::AppDataUsageCategory::ID::OTHER_DIAGNOSTIC_DATA,
    purposes: [Spaceship::ConnectAPI::AppDataUsagePurpose::ID::ANALYTICS],
    protections: [Spaceship::ConnectAPI::AppDataUsageDataProtection::ID::DATA_NOT_LINKED_TO_YOU]
  },
  {
    # Coarse, city-level location the analytics server derives from the
    # request IP at receive time. The IP itself is never stored.
    category: Spaceship::ConnectAPI::AppDataUsageCategory::ID::COARSE_LOCATION,
    purposes: [Spaceship::ConnectAPI::AppDataUsagePurpose::ID::ANALYTICS],
    protections: [Spaceship::ConnectAPI::AppDataUsageDataProtection::ID::DATA_NOT_LINKED_TO_YOU]
  }
].freeze

# Clears any existing App Store Connect data-usage declarations for `app` and
# replaces them with BB_PRIVACY_DECLARATIONS. Does not publish — callers
# decide when to flip dataUsagesPublishState.
def apply_bb_privacy_declarations(app)
  (Spaceship::ConnectAPI.get_app_data_usages(app_id: app.id).to_models rescue []).each do |u|
    Spaceship::ConnectAPI.delete_app_data_usage(app_data_usage_id: u.id) rescue nil
  end

  BB_PRIVACY_DECLARATIONS.each do |entry|
    entry[:purposes].each do |purpose_id|
      entry[:protections].each do |protection_id|
        Spaceship::ConnectAPI.post_app_data_usage(
          app_id: app.id,
          app_data_usage_category_id: entry[:category],
          app_data_usage_purpose_id: purpose_id,
          app_data_usage_protection_id: protection_id
        )
      end
    end
  end
end

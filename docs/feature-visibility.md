# Temporary messaging mode

`lib/config/app_features.dart` is the single source of product visibility.
Messaging, Contacts and Profile are enabled; Calls is disabled; Services, Shopping and Discover are disabled.
These are client visibility flags, not authorization rules.

The existing dock keeps its original design and original screen indices, rendering
only enabled entries: Chats | Contacts | Profile. Chat remains index 0 and the default after authentication;
Contacts uses appended index 5, preserving all original indices. Profile remains index 4 (the existing Huru account/settings screen). Contact
matching and the new-chat flow are independent of the Discover module.

Profile's service grid, food/shopping carts, offers, seller shortcuts, order
history and seller account actions are hidden while their modules are disabled.
The messaging overflow menu links to the existing account profile and settings.
Authentication, messaging, calling, notifications and backend code are unchanged.

`lib/config/feature_routes.dart` guards the existing registered named routes before
building module screens, including initial named links. Disabled routes show the
messaging home. No custom deep-link handler exists; notification taps currently
log payloads and do not open modules. Future direct navigation entry points must
also respect the flags; do not bypass this policy with new screen pushes.

## Re-enable modules

1. In `lib/config/app_features.dart`, set `services`, `shopping`, and/or `discover`
   to `true` for the desired modules.
2. Rebuild/restart the app. Their original dock entries and related shortcuts
   return, and their registered routes become available. No routes, module
   implementations, APIs, data models or backend services need to be recreated.
3. Update the disabled-mode test expectations if changing the release defaults.

## Verification

`flutter test` covers flag defaults, dock selection across Chats/Contacts/Profile at 320px width, settings/account shortcut visibility, and guarded named/initial routes.
The tests do not verify live authentication, message delivery, calls, push
notifications or device keyboard behavior; those require a device/backend session.

## Files changed

- `lib/config/app_features.dart`: feature defaults, visible indices, route policy.
- `lib/config/feature_routes.dart`: shared named-route guard.
- `lib/main.dart`: apply the guard without removing route definitions; register Contacts.
- `lib/screens/home/home_bottom_nav.dart`: filter existing dock items.
- `lib/screens/home/home_screen.dart`: validate tab selection, reuse Contacts, and handle menu links.
- `lib/screens/home/home_appbar.dart`: reuse profile/settings from the overflow menu.
- `lib/screens/huru/huru_screen.dart`: filter service and commerce shortcuts.
- `lib/screens/profile/account_screen.dart`: hide seller management entry.
- `lib/screens/profile/profile_actions.dart`: hide commerce actions.
- `lib/screens/connection/connection_screen.dart`: optional Contacts mode using accepted connections, search by name/phone, and existing message/profile cards.
- `test/widget_test.dart`: replace the obsolete counter test with visibility/navigation tests.
- `docs/feature-visibility.md`: behavior, restoration and verification notes.

## Architecture and readiness audit

- Flutter/Dart with StatefulWidget state and Navigator/MaterialPageRoute; entry:
  `lib/main.dart`. No remote-config package or router framework was found.
- Authentication sends users to HomeScreen (Chats at index 0). Existing
  Firebase authentication, Firestore/Hive messaging, Provider cart state,
  FCM/local notifications, backend triggers and data models are preserved.
- Contacts reuses ConnectionScreen and accepted `users/{uid}/connections`.
  Search matches profile names/phone numbers. Existing profile fields and chat
  actions are reused. Chat IDs sort both user IDs and join with `_`, matching
  Chats, so opening the same contact addresses the same conversation.
- Contacts mode does not request device permissions. The existing new-chat
  contact-discovery flow is preserved separately, including its pre-existing
  permission handling, requests and invitations. Original Connections mode
  retains Pending, Sent, Connected and Rejected views.
- Calls is incomplete: voice/video buttons have empty callbacks. No calling SDK,
  signaling, incoming/outgoing call lifecycle, call history, missed-call tracking
  or call-status implementation was found in the inspected app/backend code.
  Keep `calls = false`. Enabling a Calls tab requires a real implementation and
  route/screen integration; changing this flag alone cannot create those pieces.
  Existing conversation call buttons are unchanged.
- Voice-message recording is also incomplete: the mic icon has no tap handler
  without text. It is preserved, not represented as tested or functional.
- Existing account/profile editing, settings and logout remain intact. No new
  privacy-settings functionality or duplicated profile screen was introduced.

## Verification results for messaging-first navigation

- `flutter test`: all 5 tests passed (flags/disabled routes, named and initial
  route guards, three-tab selection at narrow width, settings shortcuts,
  account actions).
- Formatting and `git diff --check` completed.
- Full analysis retains pre-existing warnings/lint notices; no compiler errors.
- Physical-device/backend testing still required: authenticated startup, Contacts
  data/search and opening/resuming real conversations, message delivery, logout,
  notification behavior, keyboard and platform back handling. Widget tests use
  a navigation harness; they do not authenticate against production services.
- No modules, APIs, schemas or existing uncommitted edits were removed. Nothing
  was pushed or deployed.

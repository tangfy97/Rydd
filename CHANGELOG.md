# Changelog

All notable changes to Rydd are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [1.0.0] - 2026-10-22

Build 2 (2026-10-31), for the Mac App Store: drops the Downloads entitlement, which App Review flagged as unused; Downloads is reached through the home folder you allow in the welcome window. The welcome window now continues only once every folder you chose is covered.

The first release, the free basic version, for the Mac App Store and as a download from tang-spark.no.

- A menu bar app that tidies the folders you choose, such as Downloads and Desktop.
- Suggests where each file belongs by learning from the folders you already have: rules for screenshots, installers and duplicates, matching against similar file names, and optionally Apple's on-device model.
- A review window lists every suggestion. Nothing moves until you tick it and choose Tidy; every tidy can be undone.
- A short welcome on first launch; nothing is read before you choose folders.
- English, English (UK), Simplified Chinese and Traditional Chinese, following the system language.
- Runs in the App Sandbox with no network access. File contents are read only if you turn that on, and never leave your Mac.

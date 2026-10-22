# Contributing to Rydd

Thanks for helping. Bug reports, translations and small, focused pull requests are all welcome.

## Building

Requires Xcode 26 or later (Swift 6, macOS 26 SDK).

```sh
Scripts/build_app.sh          # build/Rydd.app, ad-hoc signed to run locally
swift build -c release        # the engine, the CLI and the app
```

The CLI and the test folders in `Fixtures/` check suggestions against expected answers; see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Pull requests

- Keep one change per pull request, and describe how you tested it.
- Rydd stays offline: no network access, analytics or third-party code. The only model is Apple's on-device `SystemLanguageModel`.
- If a change affects what the privacy notes in the app say, update them and [PRIVACY.md](PRIVACY.md) in the same pull request.
- New user-facing text goes into `Resources/*.lproj` in English and Simplified Chinese.
- Rydd uses standard macOS controls. Please don't add custom styling.

By contributing you agree that your work is licensed under the [Apache License 2.0](LICENSE).

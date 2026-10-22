# Contributing to Rydd

Thanks for helping. Bug reports, translations and small, focused pull requests are all welcome.

## Building

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh       # build/Rydd.app, sandboxed and signed to run locally
scripts/preflight.sh   # builds both release configurations and checks them
scripts/dev-app.sh     # unsandboxed development build with --home test folders
```

Edit `project.yml`, not the `.xcodeproj`. The CLI and the test folders in `Fixtures/` check suggestions against expected answers; see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Pull requests

- Keep one change per pull request, and describe how you tested it.
- `scripts/preflight.sh` must pass.
- Rydd stays offline and sandboxed: no network entitlement, analytics or third-party code. The only model is Apple's on-device `SystemLanguageModel`.
- If a change affects what the privacy notes in the app say, update them and [PRIVACY.md](PRIVACY.md) in the same pull request.
- New user-facing text goes into `Resources/*.lproj` in Simplified and Traditional Chinese (and British English where it differs).
- Rydd uses standard macOS controls. Please don't add custom styling.

By contributing you agree that your work is licensed under the [Apache License 2.0](LICENSE).

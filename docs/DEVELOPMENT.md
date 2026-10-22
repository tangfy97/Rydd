# Rydd — development notes

## Menu bar app

```bash
scripts/dev-app.sh && open build/dev/Rydd.app
```

The user journey is written up in `docs/user-journey.md`. In short:

- First launch opens a three-step welcome window (welcome → choose folders → "Rydd lives in the menu bar").
  Nothing is read until the user presses "Start"; no folder is pre-selected.
- Native controls only: the menu bar item is a standard menu; the review window is a table (tick · name ·
  "Move To" pop-up) with "Tidy N Files"; Settings has General and Folders tabs in System Settings style,
  including Open at Login.
- English and Simplified Chinese, following the system language (`Resources/*.lproj`).
- Rescans 5 s after a chosen folder changes; folder profiles and per-file AI verdicts are cached.
- Undo history (last 20) survives restarts; moves never overwrite; "delete" means the Trash.
- Development: `open build/dev/Rydd.app --args --home <fixture> [-AppleLanguages "(en)"] [--open-review]
  [--open-settings] [--welcome-step N]` runs against a test folder with its own settings.

## Privacy

Rydd 1.0 is the free basic version. Premium features may come later; there is no paywall code yet.

What the app tells users (the ⓘ next to every AI or content setting, and the About panel) must stay true of
the code:
- The only model is `SystemLanguageModel` (on-device). `PrivateCloudComputeLanguageModel` is never used.
- There is no networking code in any target.
- File contents are read only with "Read File Contents" on, only for files names can't place, and are kept
  in memory only. Folder profiles cached on disk are derived from folder and file *names*.

## Icons

- App icon "Skuff" (drawer): `Design/AppIcon.svg` → `swift scripts/icon.swift` → `Design/AppIcon.icns`
  (the asset catalog for Xcode builds, the .icns for `scripts/dev-app.sh`). Layered SVGs for Icon Composer are in `Design/IconComposer/`.
- Menu bar icon: drawn in code as a template image (`Sources/RyddApp/MenuBarIcon.swift`), so macOS tints it
  for light/dark menu bars. Open drawer with files sticking out = files to tidy (with a count); closed
  cabinet = all tidy.

## Engine and CLI

Dry-run CLI that suggests where each file in Downloads should go. It never moves, deletes or uploads
anything, and the binary contains no networking code. Requires macOS 26+; the LLM layer needs Apple
Intelligence enabled (it is skipped automatically otherwise).

What it reads by default: filename, type, size, dates, download-source **domain** (from Spotlight metadata).
File contents are read only with `--allow-content`, only for files nothing else could place, and only locally.

Pipeline:
0. **Folder scan** (`LocalLLM.profile`): the on-device model describes each existing folder (purpose +
   keywords) from its path and the names inside it. Cached with `--profile-cache`; only changed folders are
   re-described. Code projects are name-only and never targets for the LLM.
1. **Rules** (`Rules.swift`): screenshots, installers already installed, extracted zips, duplicate downloads, .ics/.torrent, apps.
2. **Similarity** (`Matcher.swift`): TF-IDF of the filename against files already in your folders.
3. **Local LLM** (`LocalLLM.place`): Apple's on-device `SystemLanguageModel`, filename only, output constrained
   to the shortlisted folders or NONE. Names with no usable words and installers/archives are never sent.
4. **Content, opt-in** (`ContentReader.swift`): keywords from a local excerpt, matched like layer 2.
5. **QA** (`LocalLLM.review`): every LLM placement and every low-score (< 0.65) similarity match is classified
   again from scratch among the proposed folder, a few look-alikes and "something else"; if the model doesn't
   land on the same folder, the file goes to "需要你决定".

Target: 80%+ of the suggestions shown are right; anything uncertain is left to the user. On the held-out
test fixture (63 files): 52 right, 4 wrong, 7 left to the user (93%); without the LLM: 42 / 4 / 17.

`PrivateCloudComputeLanguageModel` (Apple's server model) is deliberately not used.

```bash
swift build -c release
.build/release/rydd                    # your ~/Downloads, full preview
.build/release/rydd --summary          # numbers only, no filenames
.build/release/rydd -v                 # also prints the folder profiles and LLM errors

# Synthetic test sets with expected answers (dev for tuning, test held out)
Fixtures/make_fixture.py /tmp/rydd-test --split test
.build/release/rydd --home /tmp/rydd-test --min-age 0 --expect /tmp/rydd-test/expected.tsv --summary
```

Options: `--source DIR`, `--home DIR`, `--min-age DAYS` (default 3), `--threshold X` (default 0.45),
`--allow-content`, `--no-llm`, `--no-qa`, `--profile-cache FILE`, `--expect FILE`, `--summary`, `-v`.

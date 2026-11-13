# Rydd on tang-spark.no

The product and support pages live in the [tang-spark.no](https://github.com/tangfy97/tang-spark.no) repo, which Netlify deploys from `main`. Their source is here, so the copy, the version and the download stay in step with the app.

| Page | URL |
|---|---|
| Product (EN, 简体, 繁體) | `/rydd.html`, `/rydd-zh-cn.html`, `/rydd-zh-tw.html` |
| Support, privacy, terms | `/rydd-support.html` (+ `-zh-cn`, `-zh-tw`); privacy is `#privacy` |
| Download | `https://github.com/tangfy97/Rydd/releases/latest`; the site hosts no installers, and its `netlify.toml` redirects the old `/rydd/download` links there |

The app's menu links to the support page in the language it runs in ([Links.swift](../Sources/RyddApp/Links.swift)). In the downloaded version, Check for Updates… opens the product page with `?installed=<version>`.

## Files here

- `website/generate.py`: the copy in all three languages and the page templates, in the site's Plakat layout (`styles.css`). It reads the version from `project.yml`.
- `website/static/`: the icon and the screenshots used on the pages (`rydd-icon.png`, `rydd-shot*.jpg`).
- The homepage card for Rydd (the fourth app) is in the site's `index.html`.

## Publishing

```bash
scripts/release.sh                                  # notarized build/release/Rydd-<version>.dmg, .zip and SHA256SUMS
gh release create v<version> build/release/Rydd-<version>.dmg build/release/Rydd-<version>.zip build/release/SHA256SUMS \
  --repo tangfy97/Rydd --title "Rydd <version>" --target main
scripts/publish-website.sh ~/Documents/tang-spark.no
git -C ~/Documents/tang-spark.no add -A && git -C ~/Documents/tang-spark.no commit -m "Rydd <version>"
git -C ~/Documents/tang-spark.no push
```

The download button links to the latest GitHub release, so publish the release before the pages. `publish-website.sh` regenerates the pages and copies them with the images. It never copies a disk image, edits `netlify.toml`, commits or pushes.

Once the app is live on the App Store, set `APP_STORE_URL` in `website/generate.py` to show the Mac App Store button, and publish again.

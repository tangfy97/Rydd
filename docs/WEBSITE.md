# Rydd on tang-spark.no

The product and support pages live in the [tang-spark.no](https://github.com/tangfy97/tang-spark.no) repo, which Netlify deploys from `main`. Their source is here, so the copy, the version and the download stay in step with the app.

| Page | URL |
|---|---|
| Product (EN, 简体, 繁體) | `/rydd.html`, `/rydd-zh-cn.html`, `/rydd-zh-tw.html` |
| Support, privacy, terms | `/rydd-support.html` (+ `-zh-cn`, `-zh-tw`); privacy is `#privacy` |
| Latest disk image | `/rydd/download`, a redirect to `/downloads/Rydd-<version>.dmg` (once there is one) |

The app's menu links to the support page in the language it runs in ([Links.swift](../Sources/RyddApp/Links.swift)). In the downloaded version, Check for Updates… opens the product page with `?installed=<version>`.

## Files here

- `website/generate.py`: the copy in all three languages and the page templates, in the site's Plakat layout (`styles.css`). It reads the version from `project.yml`.
- `website/static/`: the icon and the screenshots used on the pages (`rydd-icon.png`, `rydd-shot*.jpg`).
- The homepage card for Rydd (the fourth app) is in the site's `index.html`.

## Publishing

```bash
scripts/release.sh                                  # optional: notarized build/release/Rydd-<version>.dmg
scripts/publish-website.sh ~/Documents/tang-spark.no
git -C ~/Documents/tang-spark.no add -A && git -C ~/Documents/tang-spark.no commit -m "Rydd <version>"
git -C ~/Documents/tang-spark.no push
```

`publish-website.sh` regenerates the pages and copies them with the images. With a notarized disk image it also copies that, adds a Download button and points `/rydd/download` at it in `netlify.toml`; it refuses one that isn't notarized. It never commits or pushes.

Once the app is live on the App Store, set `APP_STORE_URL` in `website/generate.py` to show the Mac App Store button, and publish again.

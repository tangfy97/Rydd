# Releasing Rydd

Rydd ships two ways from the same code: the **Mac App Store** (the `AppStore` build configuration) and a **download on tang-spark.no** (the `Release` configuration, signed with Developer ID and notarized). Both run in the App Sandbox with no network entitlement; they differ only in signing and in the menu, where the website build has Check for Updates… linking to its download page.

The Swift package in the same folder builds the same code without the sandbox, for development and for the `rydd` command-line tool. It is never shipped.

## Every release

1. Bump `MARKETING_VERSION` (and for the App Store, `CURRENT_PROJECT_VERSION`) in `project.yml`, and add the release to `CHANGELOG.md` and the release notes in `website/generate.py`.
2. Check everything:
   ```bash
   scripts/preflight.sh
   ```
3. App Store: build, then upload.
   ```bash
   scripts/appstore.sh upload
   ```
4. Website: build, sign, notarize and staple, then copy the pages and the disk image to the site.
   ```bash
   scripts/release.sh
   scripts/publish-website.sh ~/Documents/tang-spark.no
   ```
   Review with `git -C ~/Documents/tang-spark.no status`, then commit and push (see [WEBSITE.md](WEBSITE.md)).

## One-time setup

| What | Status |
|---|---|
| Developer ID Application certificate (Feiyang Tang, X933P26489) | In the login keychain (shared with Kvikkshot) |
| Notarization profile | `kvikkshot` in the keychain, shared by the team's apps; `scripts/release.sh` uses it by default |
| App Store distribution signing | Cloud-managed by Xcode |
| Bundle ID `com.feiyangtang.Rydd` | Registered automatically by the first `scripts/appstore.sh` (`-allowProvisioningUpdates`) |
| App record | **To do:** create it in App Store Connect with the values below, then upload |

## App Store Connect

| Field | Value |
|---|---|
| Platform | macOS |
| Bundle ID | `com.feiyangtang.Rydd` |
| SKU | `rydd-macos` |
| Primary language | English (U.S.) |
| Primary category | Productivity |
| Secondary category | Utilities |
| Price | Free |
| Availability | Everywhere except China mainland, which needs an ICP filing number (as Kvikkshot) |
| Age rating | 4+ (no objectionable content) |
| App Privacy | Data Not Collected |
| Export compliance | No encryption (`ITSAppUsesNonExemptEncryption` is false) |
| Copyright | 2026 TangSpark |
| Support URL | https://tang-spark.no/rydd-support.html |
| Marketing URL | https://tang-spark.no/rydd.html |
| Privacy Policy URL | https://tang-spark.no/rydd-support.html#privacy |
| Localizations | English (U.S.), English (U.K.), Chinese (Simplified), Chinese (Traditional) |

### Screenshots

2880 × 1800, in [appstore/screenshots/](appstore/screenshots): `en` for both English localizations, `zh-Hans` and `zh-Hant`. Upload 1, 2, 3 in order. The files in them are sample files made for the screenshots, not anyone's real files. To redo them after a UI change, see [Remaking the screenshots](#remaking-the-screenshots).

### English (U.S.)

**Name** (30): Rydd: Tidy Your Folders

**Subtitle** (30): Private, offline file sorter

**Promotional text** (170):
Rydd learns from the folders you already have and suggests where each new file belongs. You review, it tidies, and you can always undo. Nothing ever leaves your Mac.

**Keywords** (100):
organize,organizer,downloads,desktop,clean up,declutter,files,folders,sort,tidy,menu bar,cleaner

**Description**:

Rydd keeps the folders you choose tidy. It lives in the menu bar, learns from the folders you already have, and suggests where each new file in Downloads or on your Desktop belongs. Nothing moves until you say so.

YOUR FOLDERS, YOUR SYSTEM
• Choose the folders to tidy, such as Downloads and Desktop; Rydd reads nothing before you do
• Suggestions follow the folders you already have, not a fixed scheme
• Screenshots, installers you've already installed and duplicate downloads are spotted at once

REVIEW FIRST
• Every suggestion is listed in one window: tick what should move, change where a file goes, and tidy
• Files Rydd isn't sure about are left for you to choose
• Undo any tidy, even after a restart
• Nothing is ever overwritten, and nothing is deleted for good

PRIVATE BY DESIGN
• Rydd has no network access at all: no accounts, no analytics, no tracking
• Optional sorting with Apple Intelligence uses Apple's on-device model, works offline and only sees file names
• File contents are never read unless you turn that on, and even then they never leave your Mac

Rydd needs macOS 26 Tahoe; sorting with Apple Intelligence needs a Mac with Apple Intelligence turned on. It speaks English, Simplified Chinese and Traditional Chinese, and it is free.

Made by TangSpark, a small software studio in Norway. Rydd is Norwegian for tidy up.

**What's New** (1.0.0): First release.

### English (U.K.)

The same as English (U.S.): the copy uses no words that differ between US and UK English. (The app itself says Bin instead of Trash in British English.)

### Chinese (Simplified)

**名称**（30）：Rydd：整理你的文件夹

**副标题**（30）：私密、离线的文件整理工具

**推广文本**（170）：
Rydd 从你已有的文件夹中学习，为每个新文件建议该去的地方。你确认，它整理，随时可以撤销。所有处理都在你的 Mac 上完成，什么都不会上传。

**关键词**（100）：
整理,文件整理,下载,桌面,清理,归类,分类,文件夹,菜单栏,收纳,organize,downloads

**描述**：

Rydd 让你选择的文件夹保持整洁。它待在菜单栏里，从你已有的文件夹中学习，为 Downloads 和桌面上的每个新文件建议该去的地方。你不点头，什么都不会动。

你的文件夹，你的习惯
• 选择要整理的文件夹，比如 Downloads 和桌面；选之前什么都不读取
• 建议跟着你已有的文件夹走，而不是套用固定的分类
• 截图、已经安装过的安装包和重复下载的文件，一眼就能认出来

先看再动
• 所有建议列在一个窗口里：勾选要移动的文件，改一改去处，然后整理
• Rydd 没把握的文件，留给你来决定
• 任何一次整理都能撤销，重启之后也可以
• 从不覆盖文件，删除永远是移到废纸篓

隐私
• Rydd 完全没有联网权限：没有账号，没有统计，没有追踪
• 可选的 Apple 智能归类使用 Apple 设备端模型，离线运行，只看文件名
• 除非你打开相应开关，否则从不读取文件内容；即使读取，内容也不会离开你的 Mac

Rydd 需要 macOS 26 Tahoe；使用 Apple 智能归类需要开启了 Apple 智能的 Mac。支持英文、简体中文和繁体中文，完全免费。

由挪威的小型软件工作室 TangSpark 制作。Rydd 在挪威语里是“收拾一下”。

**新功能**（1.0.0）：首次发布。

### Chinese (Traditional)

**名稱**（30）：Rydd：整理你的檔案夾

**副標題**（30）：私密、離線的檔案整理工具

**宣傳文字**（170）：
Rydd 從你現有的檔案夾中學習，為每個新檔案建議該去的地方。你確認，它整理，隨時可以還原。所有處理都在你的 Mac 上完成，什麼都不會上傳。

**關鍵字**（100）：
整理,檔案整理,下載,桌面,清理,歸類,分類,檔案夾,選單列,收納,organize,downloads

**描述**：

Rydd 讓你選擇的檔案夾保持整潔。它待在選單列裡，從你現有的檔案夾中學習，為「下載項目」和桌面上的每個新檔案建議該去的地方。你不點頭，什麼都不會動。

你的檔案夾，你的習慣
• 選擇要整理的檔案夾，例如「下載項目」和桌面；選擇之前什麼都不讀取
• 建議依照你現有的檔案夾，而不是套用固定的分類
• 截圖、已經安裝過的安裝檔和重複下載的檔案，一眼就能認出來

先看再動
• 所有建議列在一個視窗中：勾選要移動的檔案，改一改去處，然後整理
• Rydd 沒把握的檔案，留給你來決定
• 任何一次整理都能還原，重新啟動之後也可以
• 從不覆寫檔案，刪除一律是丟到垃圾桶

隱私
• Rydd 完全沒有連網權限：沒有帳號，沒有統計，沒有追蹤
• 可選的 Apple Intelligence 分類使用 Apple 裝置端模型，離線運作，只看檔案名稱
• 除非你開啟相應選項，否則從不讀取檔案內容；即使讀取，內容也不會離開你的 Mac

Rydd 需要 macOS 26 Tahoe；使用 Apple Intelligence 分類需要開啟 Apple Intelligence 的 Mac。支援英文、簡體中文和繁體中文，完全免費。

由挪威的小型軟體工作室 TangSpark 製作。Rydd 在挪威語裡是「收拾一下」。

**新功能**（1.0.0）：首次發佈。

## Notes for App Review

> Rydd is a menu bar app that suggests where files in folders the user chooses (such as Downloads and Desktop) belong, and moves them only after the user confirms. It needs no account, has no in-app purchases, and has no network access.
>
> To try it: on first launch a short welcome window asks which folders to tidy, then asks the user to allow access to their home folder in a standard Open panel (click Allow). Rydd then appears in the menu bar as a drawer icon. Choose Review… to see the suggestions in a table, tick files, and click Tidy. Undo Last Tidy puts them back. New files wait three days by default; set Settings › General › Wait Before Tidying to Right Away to see suggestions for files just added to Downloads.
>
> It runs in the App Sandbox with user-selected read-write access, app-scoped bookmarks (to keep the folders the user allowed across launches) and read-write access to Downloads. "Sort with Apple Intelligence" uses the on-device Foundation Models framework (SystemLanguageModel) only; file contents are read only if the user turns on "Read File Contents". Nothing is sent anywhere.
>
> The menu's Rydd Help link opens the support page in the browser.

## Remaking the screenshots

1. Make the sample folders (realistic names, empty files) and build the development app:
   ```bash
   scripts/dev-app.sh
   ```
   The sample home used for the 1.0 screenshots has `Documents/Finance/Invoices`, `Documents/Travel/Japan 2025`, `Documents/Work/Meetings`, `Documents/Career/CV`, `Pictures/Wallpapers`, `Desktop/Receipts` with a few files each, and a `Downloads` folder with about a dozen new files.
2. For each language, run `build/dev/Rydd.app/Contents/MacOS/Rydd --home <sample home> -AppleLanguages "(en)" -AppleLocale en_US` (or `zh-Hans`/`zh_CN`, `zh-Hant`/`zh_TW`) with `--open-review` (wait for the scan to finish), `--welcome-step 1`, and `--open-settings --show-privacy`, and capture each window with `screencapture -o -l <window id>`.
3. Compose each capture:
   ```bash
   swift scripts/storeshot.swift capture.png docs/appstore/screenshots/en/1.jpg "Headline" "Subline"
   ```
   The headlines are in the screenshots themselves; keep them in step with the listing copy.

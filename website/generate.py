#!/usr/bin/env python3
"""Generates Rydd's pages for tang-spark.no in English, Simplified and Traditional Chinese.

    website/generate.py            # writes website/dist/*.html

The pages use the site's own styles.css (the Plakat layout shared with Kvikkshot and Glimt).
The version comes from project.yml. Set APP_STORE_URL once the app is live to show the
Mac App Store button; the download button appears when publish-website.sh copies a notarized disk image.
"""
import html
import os
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "website" / "dist"
VERSION = re.search(r'MARKETING_VERSION: "([^"]+)"', (ROOT / "project.yml").read_text()).group(1)
APP_STORE_URL = ""
# scripts/publish-website.sh sets this when it copies a notarized disk image to the site.
DOWNLOAD_URL = os.environ.get("RYDD_DOWNLOAD_URL", "")
GITHUB = "https://github.com/tangfy97/Rydd"

LANGS = {
    "en": {"suffix": "", "html": "en", "other": [("zh-cn", "中文")]},
    "zh-cn": {"suffix": "-zh-cn", "html": "zh-Hans", "other": [("en", "EN"), ("zh-tw", "繁體")]},
    "zh-tw": {"suffix": "-zh-tw", "html": "zh-Hant", "other": [("en", "EN"), ("zh-cn", "简体")]},
}

COPY = {
    "en": {
        "title": "Rydd — Every file, back where it belongs.",
        "description": "Rydd lives in the menu bar and keeps the folders you choose tidy. It learns from the folders you already have, suggests where each new file goes, and moves only what you confirm. Free, private and offline.",
        "label": "macOS 26+ · Free · Open source",
        "headline": "Every file, back where it belongs.",
        "lead": "Rydd lives in the menu bar and keeps the folders you choose tidy. It learns from the folders you already have, suggests where each new file goes, and moves only what you confirm. Rydd is Norwegian for tidy up.",
        "facts": [("Platform", "macOS 26 or later"), ("Price", "Free, Apache 2.0"), ("Network", "None at all"), ("Languages", "EN, 简体, 繁體")],
        "shot_alt": "Rydd's review window suggesting folders for files in Downloads",
        "what": "What it does",
        "features": [
            ("Your folders", "Pick what to tidy, such as Downloads and Desktop. Nothing is read before you do."),
            ("Learns your system", "Suggestions follow the folders you already have, not a fixed scheme."),
            ("Review first", "Every move is listed. Tick, tidy, and undo if you change your mind."),
            ("Never loses a file", "Nothing is overwritten, and deleting always means the Trash."),
            ("On-device AI", "Optional sorting with Apple Intelligence runs offline and only sees file names."),
        ],
        "get": "Get Rydd",
        "get_text_store": "Free on the Mac App Store, and as a signed, notarized download.",
        "get_text_soon": "Free and open source. Coming soon to the Mac App Store; until then, Rydd can be built from the source on GitHub.",
        "btn_store": "Mac App Store", "btn_download": "Download for Mac", "btn_source": "Source on GitHub", "btn_support": "Support & privacy",
        "nav_apps": "Apps", "nav_support": "Support",
        # support page
        "s_title": "Rydd support, privacy and terms",
        "s_hero": "Support",
        "s_headline": "Support, privacy and terms.",
        "s_lead": "Answers to common questions, the privacy policy and the terms. If something isn't covered here, write to us and we'll reply.",
        "s_facts": [("Version", VERSION), ("Data collected", "None"), ("Network", "None at all"), ("Contact", '<a href="mailto:support@tang-spark.no">support@tang-spark.no</a>')],
        "toc": [("start", "Getting started"), ("faq", "Questions"), ("privacy", "Privacy"), ("terms", "Terms"), ("release-notes", "Release notes"), ("contact", "Contact")],
        "start": [
            "Open Rydd and choose the folders to tidy, such as Downloads and Desktop.",
            "When macOS asks, allow access to your home folder, so Rydd can file things into your folders.",
            "Click the drawer in the menu bar and choose Review. Tick what should move, then Tidy.",
        ],
        "faq": [
            ("How does Rydd decide where a file goes?", "It looks at the folders you already have and the names of the files in them. Screenshots, installers that are already installed and duplicate downloads follow simple rules; other files are matched by name. With Sort with Apple Intelligence on, Apple's on-device model helps with names that don't match anything. Files Rydd isn't sure about are left for you to choose."),
            ("Why are some files not listed?", "New files wait a few days, so nothing you're working on moves. Change this in Settings › General › Wait Before Tidying. Folders inside the folders you tidy are never moved."),
            ("Can I undo a tidy?", "Yes. Choose Undo Last Tidy in the menu or in the review window. Rydd remembers the last 20 tidies and puts the files back where they were, even after a restart."),
            ("Does Rydd delete files?", "No. Move to Trash uses the macOS Trash, and Rydd never overwrites a file: if a name is taken, the moved file gets a number."),
            ("Why does Rydd ask for my home folder?", "Rydd runs in the App Sandbox, so macOS only lets it use folders you choose in an Open panel. Choosing your home folder lets it tidy the folders you picked and file things into Documents, Pictures and the rest. You can choose narrower folders instead."),
            ("Does Rydd use AI in the cloud?", "No. Sort with Apple Intelligence uses Apple's on-device model, works offline and only sees file and folder names. It needs a Mac with Apple Intelligence turned on; without it, Rydd sorts by rules and names."),
            ("How do I update?", "The Mac App Store version updates through the App Store. In the downloaded version, choose Check for Updates… in the menu; it opens this website in your browser, because Rydd itself never goes online."),
            ("How do I uninstall it?", "Quit Rydd and drag it from Applications to the Bin. Its settings and undo history are in ~/Library/Containers/com.feiyangtang.Rydd, which you can delete too."),
        ],
        "privacy_title": "Privacy policy",
        "privacy": [
            "Last updated 22 October 2026. This policy covers the Mac App Store version and the version downloaded from this website.",
            "<b>Rydd collects no data.</b> It has no network access: the App Sandbox does not let it connect to the internet. There are no accounts, analytics, telemetry, crash reporting, advertising or update checks, and no third-party code.",
            "Rydd uses only the folders you allow, and tidies only the ones you choose. It reads the names of files and folders and basic details such as size, dates and the website a download came from. If you turn on Sort with Apple Intelligence, those names are given to Apple's on-device model on your Mac; Rydd never uses Apple's cloud model. File contents are read only if you turn on Read File Contents, only when a name isn't enough, and are never saved.",
            "Rydd moves files only after you confirm. In its own container it keeps your settings, the folders you allowed, short descriptions of your folders made from their names, and the list of recent moves so they can be undone. All of this stays on your Mac.",
            "Links in the menu open in your browser, outside Rydd. Check for Updates… tells this website which version you have, so it can say whether a newer one exists.",
            "Rydd is suitable for all ages and collects nothing from anyone, including children. Questions about privacy: support@tang-spark.no.",
        ],
        "terms_title": "Terms",
        "terms": [
            "Rydd is free. You may use it for personal and commercial work.",
            "It is provided as is, without warranty. Rydd moves files only after you confirm, never overwrites them and can undo its moves, but TangSpark is not liable for loss of data or other damages from using it, as far as the law allows. Keep backups of files that matter.",
            "Mac App Store downloads are also covered by Apple's standard licence agreement.",
        ],
        "notes_title": "Release notes",
        "notes": [(f"Version {VERSION}", "22 October 2026", "First release: tidies the folders you choose by learning from the folders you already have, a review window with undo, optional on-device Apple Intelligence, four languages.")],
        "contact_title": "Contact",
        "contact": "Write to <a href=\"mailto:support@tang-spark.no\">support@tang-spark.no</a>. It helps to include your macOS version and the Rydd version (Rydd menu › About Rydd).",
        "footer_support": "Support & privacy",
    },
    "zh-cn": {
        "title": "Rydd — 每个文件，都回到该在的地方。",
        "description": "Rydd 待在菜单栏里，让你选择的文件夹保持整洁。它从你已有的文件夹里学习，为每个新文件建议去处，只移动你确认过的文件。免费、私密、离线。",
        "label": "macOS 26+ · 免费 · 开源",
        "headline": "每个文件，都回到该在的地方。",
        "lead": "Rydd 待在菜单栏里，让你选择的文件夹保持整洁。它从你已有的文件夹里学习，为每个新文件建议去处，只移动你确认过的文件。Rydd 在挪威语里是“收拾一下”。",
        "facts": [("平台", "macOS 26 或更新版本"), ("价格", "免费，Apache 2.0"), ("网络", "完全不联网"), ("语言", "EN, 简体, 繁體")],
        "shot_alt": "Rydd 的整理窗口，为 Downloads 里的文件建议文件夹",
        "what": "它能做什么",
        "features": [
            ("由你决定", "选择要整理的文件夹，比如 Downloads 和桌面。选之前什么都不读取。"),
            ("学习你的习惯", "建议跟着你已有的文件夹走，而不是套用固定的分类。"),
            ("先看再动", "每一项移动都列出来。勾选、整理，改主意了随时撤销。"),
            ("不会弄丢文件", "从不覆盖文件，删除永远是移到废纸篓。"),
            ("设备端 AI", "可选的 Apple 智能归类离线运行，只看文件名。"),
        ],
        "get": "获取 Rydd",
        "get_text_store": "可在 Mac App Store 免费获取，也可以下载经过签名和公证的版本。",
        "get_text_soon": "免费、开源。即将登陆 Mac App Store；在那之前，可以从 GitHub 上的源代码构建。",
        "btn_store": "Mac App Store", "btn_download": "下载 Mac 版", "btn_source": "GitHub 源代码", "btn_support": "支持与隐私",
        "nav_apps": "Apps", "nav_support": "支持",
        "s_title": "Rydd 支持、隐私与条款",
        "s_hero": "支持",
        "s_headline": "支持、隐私与条款。",
        "s_lead": "常见问题、隐私政策和使用条款。如果这里没有你要的答案，请写信给我们。",
        "s_facts": [("版本", VERSION), ("收集的数据", "无"), ("网络", "完全不联网"), ("联系", '<a href="mailto:support@tang-spark.no">support@tang-spark.no</a>')],
        "toc": [("start", "开始使用"), ("faq", "常见问题"), ("privacy", "隐私"), ("terms", "条款"), ("release-notes", "更新说明"), ("contact", "联系")],
        "start": [
            "打开 Rydd，选择要整理的文件夹，比如 Downloads 和桌面。",
            "macOS 询问时，允许访问你的个人文件夹，Rydd 才能把文件归入你的文件夹。",
            "点按菜单栏中的抽屉图标，选择“查看”。勾选要移动的文件，然后点“整理”。",
        ],
        "faq": [
            ("Rydd 怎么决定文件该放哪里？", "它会看你已有的文件夹，以及里面文件的名字。截图、已经安装过的安装包和重复下载的文件按简单的规则处理；其他文件按名字匹配。打开“使用 Apple 智能归类”后，Apple 设备端模型会帮忙处理名字匹配不上的文件。Rydd 没把握的文件会留给你来决定。"),
            ("为什么有些文件没有列出来？", "新文件会等几天再整理，正在用的文件不会被挪走。可以在“设置 › 通用 › 整理前等待”中修改。被整理的文件夹里的子文件夹永远不会被移动。"),
            ("可以撤销整理吗？", "可以。在菜单或整理窗口中选择“撤销上次整理”。Rydd 会记住最近 20 次整理，即使重启之后也能把文件放回原处。"),
            ("Rydd 会删除文件吗？", "不会。“移到废纸篓”用的是 macOS 的废纸篓，而且 Rydd 从不覆盖文件：如果名字已被占用，移过去的文件会加上编号。"),
            ("为什么 Rydd 要访问我的个人文件夹？", "Rydd 运行在 App 沙盒中，macOS 只允许它使用你在“打开”面板中选择的文件夹。选择个人文件夹后，它才能整理你选的文件夹，并把文件归入“文稿”“图片”等文件夹。你也可以只选择更小范围的文件夹。"),
            ("Rydd 会使用云端 AI 吗？", "不会。“使用 Apple 智能归类”用的是 Apple 设备端模型，离线运行，只看文件名和文件夹名。它需要开启了 Apple 智能的 Mac；没有的话，Rydd 会按规则和名字来整理。"),
            ("怎么更新？", "Mac App Store 版本通过 App Store 更新。下载版请在菜单中选择“检查更新…”，它会在浏览器中打开这个网站，因为 Rydd 自己从不联网。"),
            ("怎么卸载？", "退出 Rydd，把它从“应用程序”拖到废纸篓。它的设置和撤销记录在 ~/Library/Containers/com.feiyangtang.Rydd，也可以一起删除。"),
        ],
        "privacy_title": "隐私政策",
        "privacy": [
            "最后更新：2026 年 10 月 22 日。本政策适用于 Mac App Store 版本和从本网站下载的版本。",
            "<b>Rydd 不收集任何数据。</b>它完全没有网络权限：App 沙盒不允许它连接互联网。没有账号、统计、遥测、崩溃报告、广告或更新检查，也没有任何第三方代码。",
            "Rydd 只使用你允许的文件夹，只整理你选择的文件夹。它读取文件和文件夹的名字，以及大小、日期、下载来源网站等基本信息。打开“使用 Apple 智能归类”后，这些名字会交给你 Mac 上的 Apple 设备端模型；Rydd 从不使用 Apple 的云端模型。只有打开“读取文件内容”后才会读取文件内容，且只在名字不足以判断时读取，从不保存。",
            "Rydd 只在你确认后才移动文件。在它自己的容器中，它保存你的设置、你允许的文件夹、根据名字生成的文件夹简短描述，以及最近的移动记录（用于撤销）。这些都留在你的 Mac 上。",
            "菜单中的链接会在浏览器中打开，与 Rydd 无关。“检查更新…”会把你的版本号告诉本网站，以便显示是否有新版本。",
            "Rydd 适合所有年龄，不收集任何人的数据，包括儿童。隐私相关问题：support@tang-spark.no。",
        ],
        "terms_title": "使用条款",
        "terms": [
            "Rydd 免费，可用于个人和商业用途。",
            "Rydd 按“现状”提供，不附带任何保证。Rydd 只在你确认后移动文件，从不覆盖文件，并且可以撤销移动；但在法律允许的范围内，TangSpark 不对因使用本软件造成的数据丢失或其他损失负责。重要的文件请保留备份。",
            "从 Mac App Store 下载的版本同时适用 Apple 的标准许可协议。",
        ],
        "notes_title": "更新说明",
        "notes": [(f"版本 {VERSION}", "2026 年 10 月 22 日", "首次发布：从你已有的文件夹中学习，整理你选择的文件夹；整理窗口与撤销；可选的设备端 Apple 智能；四种语言。")],
        "contact_title": "联系",
        "contact": "请写信至 <a href=\"mailto:support@tang-spark.no\">support@tang-spark.no</a>。附上 macOS 版本和 Rydd 版本（Rydd 菜单 › 关于 Rydd）会很有帮助。",
        "footer_support": "支持与隐私",
    },
    "zh-tw": {
        "title": "Rydd — 每個檔案，都回到該在的地方。",
        "description": "Rydd 待在選單列裡，讓你選擇的檔案夾保持整潔。它從你現有的檔案夾中學習，為每個新檔案建議去處，只移動你確認過的檔案。免費、私密、離線。",
        "label": "macOS 26+ · 免費 · 開源",
        "headline": "每個檔案，都回到該在的地方。",
        "lead": "Rydd 待在選單列裡，讓你選擇的檔案夾保持整潔。它從你現有的檔案夾中學習，為每個新檔案建議去處，只移動你確認過的檔案。Rydd 在挪威語裡是「收拾一下」。",
        "facts": [("平台", "macOS 26 或以上版本"), ("價格", "免費，Apache 2.0"), ("網路", "完全不連網"), ("語言", "EN, 简体, 繁體")],
        "shot_alt": "Rydd 的整理視窗，為「下載項目」中的檔案建議檔案夾",
        "what": "它能做什麼",
        "features": [
            ("由你決定", "選擇要整理的檔案夾，例如「下載項目」和桌面。選擇之前什麼都不讀取。"),
            ("學習你的習慣", "建議依照你現有的檔案夾，而不是套用固定的分類。"),
            ("先看再動", "每一項移動都會列出。勾選、整理，改變主意時隨時還原。"),
            ("不會遺失檔案", "從不覆寫檔案，刪除一律是丟到垃圾桶。"),
            ("裝置端 AI", "可選的 Apple Intelligence 分類離線運作，只看檔案名稱。"),
        ],
        "get": "取得 Rydd",
        "get_text_store": "可在 Mac App Store 免費取得，也可以下載經過簽署和公證的版本。",
        "get_text_soon": "免費、開源。即將登上 Mac App Store；在那之前，可以從 GitHub 上的原始碼建置。",
        "btn_store": "Mac App Store", "btn_download": "下載 Mac 版", "btn_source": "GitHub 原始碼", "btn_support": "支援與隱私",
        "nav_apps": "Apps", "nav_support": "支援",
        "s_title": "Rydd 支援、隱私與條款",
        "s_hero": "支援",
        "s_headline": "支援、隱私與條款。",
        "s_lead": "常見問題、隱私權政策和使用條款。如果這裡沒有你要的答案，請寫信給我們。",
        "s_facts": [("版本", VERSION), ("收集的資料", "無"), ("網路", "完全不連網"), ("聯絡", '<a href="mailto:support@tang-spark.no">support@tang-spark.no</a>')],
        "toc": [("start", "開始使用"), ("faq", "常見問題"), ("privacy", "隱私"), ("terms", "條款"), ("release-notes", "版本說明"), ("contact", "聯絡")],
        "start": [
            "打開 Rydd，選擇要整理的檔案夾，例如「下載項目」和桌面。",
            "macOS 詢問時，允許取用你的個人專屬檔案夾，Rydd 才能把檔案歸入你的檔案夾。",
            "按一下選單列中的抽屜圖像，選擇「檢視」。勾選要移動的檔案，然後按「整理」。",
        ],
        "faq": [
            ("Rydd 怎麼決定檔案該放哪裡？", "它會參考你現有的檔案夾，以及其中檔案的名稱。截圖、已經安裝過的安裝檔和重複下載的檔案依簡單規則處理；其他檔案依名稱比對。開啟「使用 Apple Intelligence 分類」後，Apple 裝置端模型會協助處理名稱比對不到的檔案。Rydd 沒把握的檔案會留給你決定。"),
            ("為什麼有些檔案沒有列出？", "新檔案會等幾天再整理，正在使用的檔案不會被移走。可以在「設定 › 一般 › 整理前等待」中更改。被整理的檔案夾中的子檔案夾永遠不會被移動。"),
            ("可以還原整理嗎？", "可以。在選單或整理視窗中選擇「還原上次整理」。Rydd 會記住最近 20 次整理，即使重新啟動後也能把檔案放回原處。"),
            ("Rydd 會刪除檔案嗎？", "不會。「丟到垃圾桶」使用 macOS 的垃圾桶，而且 Rydd 從不覆寫檔案：如果名稱已被使用，移過去的檔案會加上編號。"),
            ("為什麼 Rydd 要取用我的個人專屬檔案夾？", "Rydd 在 App 沙盒中運作，macOS 只允許它使用你在「打開」面板中選擇的檔案夾。選擇個人專屬檔案夾後，它才能整理你選的檔案夾，並把檔案歸入「文件」「圖片」等檔案夾。你也可以只選擇範圍更小的檔案夾。"),
            ("Rydd 會使用雲端 AI 嗎？", "不會。「使用 Apple Intelligence 分類」使用 Apple 裝置端模型，離線運作，只看檔案和檔案夾名稱。它需要開啟 Apple Intelligence 的 Mac；沒有的話，Rydd 會依規則和名稱來整理。"),
            ("怎麼更新？", "Mac App Store 版本透過 App Store 更新。下載版請在選單中選擇「檢查更新項目…」，它會在瀏覽器中打開這個網站，因為 Rydd 本身從不連網。"),
            ("怎麼解除安裝？", "結束 Rydd，把它從「應用程式」拖到垃圾桶。它的設定和還原記錄在 ~/Library/Containers/com.feiyangtang.Rydd，也可以一併刪除。"),
        ],
        "privacy_title": "隱私權政策",
        "privacy": [
            "最後更新：2026 年 10 月 22 日。本政策適用於 Mac App Store 版本和從本網站下載的版本。",
            "<b>Rydd 不收集任何資料。</b>它完全沒有網路權限：App 沙盒不允許它連上網際網路。沒有帳號、統計、遙測、當機報告、廣告或更新檢查，也沒有任何第三方程式碼。",
            "Rydd 只使用你允許的檔案夾，只整理你選擇的檔案夾。它讀取檔案和檔案夾的名稱，以及大小、日期、下載來源網站等基本資訊。開啟「使用 Apple Intelligence 分類」後，這些名稱會交給你 Mac 上的 Apple 裝置端模型；Rydd 從不使用 Apple 的雲端模型。只有開啟「讀取檔案內容」後才會讀取檔案內容，且只在名稱不足以判斷時讀取，從不儲存。",
            "Rydd 只在你確認後才移動檔案。在它自己的容器中，它會保存你的設定、你允許的檔案夾、依名稱產生的檔案夾簡短描述，以及最近的移動記錄（用於還原）。這些都留在你的 Mac 上。",
            "選單中的連結會在瀏覽器中打開，與 Rydd 無關。「檢查更新項目…」會把你的版本號碼告訴本網站，以便顯示是否有新版本。",
            "Rydd 適合所有年齡，不收集任何人的資料，包括兒童。隱私相關問題：support@tang-spark.no。",
        ],
        "terms_title": "使用條款",
        "terms": [
            "Rydd 免費，可用於個人和商業用途。",
            "Rydd 依「現狀」提供，不附帶任何保證。Rydd 只在你確認後移動檔案，從不覆寫檔案，並且可以還原移動；但在法律允許的範圍內，TangSpark 不對因使用本軟體造成的資料遺失或其他損失負責。重要的檔案請保留備份。",
            "從 Mac App Store 下載的版本同時適用 Apple 的標準授權協議。",
        ],
        "notes_title": "版本說明",
        "notes": [(f"版本 {VERSION}", "2026 年 10 月 22 日", "首次發佈：從你現有的檔案夾中學習，整理你選擇的檔案夾；整理視窗與還原；可選的裝置端 Apple Intelligence；四種語言。")],
        "contact_title": "聯絡",
        "contact": "請寫信至 <a href=\"mailto:support@tang-spark.no\">support@tang-spark.no</a>。附上 macOS 版本和 Rydd 版本（Rydd 選單 › 關於 Rydd）會很有幫助。",
        "footer_support": "支援與隱私",
    },
}

e = html.escape


def head(lang, title, description, page):
    alternates = "".join(
        f'<link rel="alternate" hreflang="{LANGS[k]["html"]}" href="https://tang-spark.no/{page}{LANGS[k]["suffix"]}.html">'
        for k in LANGS)
    return (f'<!doctype html>\n<html lang="{LANGS[lang]["html"]}"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f'<title>{e(title)} | TangSpark</title><meta name="description" content="{e(description)}">\n'
            f'{alternates}\n<link rel="icon" type="image/svg+xml" href="./favicon.svg"><link rel="stylesheet" href="./styles.css"></head>\n'
            f'<body><div class="wrap">\n')


def nav(lang, page, items):
    langs = "".join(f'<a href="./{page}{LANGS[k]["suffix"]}.html" hreflang="{LANGS[k]["html"]}">{label}</a>'
                    for k, label in LANGS[lang]["other"])
    return f'<header><a class="mark" href="./index.html">TangSpark</a><nav>{items}{langs}</nav></header>\n'


def facts(rows):
    return '<div class="facts">' + "".join(f"<div><span>{e(k)}</span><span>{v}</span></div>" for k, v in rows) + "</div>"


def product(lang):
    c, s = COPY[lang], LANGS[lang]["suffix"]
    support = f"./rydd-support{s}.html"
    if APP_STORE_URL or DOWNLOAD_URL:
        text = c["get_text_store"]
        buttons = (f'<a class="btn red" href="{APP_STORE_URL}">{e(c["btn_store"])}</a>' if APP_STORE_URL else "") + \
                  (f'<a class="btn{"" if APP_STORE_URL else " red"}" href="{DOWNLOAD_URL}">{e(c["btn_download"])}</a>' if DOWNLOAD_URL else "")
    else:
        text, buttons = c["get_text_soon"], f'<a class="btn red" href="{GITHUB}">{e(c["btn_source"])}</a>'
    buttons += f'<a class="btn" href="{support}">{e(c["btn_support"])}</a>'
    shot = "img/rydd-shot.jpg" if lang == "en" else f"img/rydd-shot{s}.jpg"
    features = "".join(f"<li><b>{e(a)}</b><span>{e(b)}</span></li>" for a, b in c["features"])
    return (head(lang, c["title"], c["description"], "rydd")
            + nav(lang, "rydd", f'<a href="./index.html#apps">{c["nav_apps"]}</a><a href="{support}">{c["nav_support"]}</a>')
            + f'<div class="title"><img src="img/rydd-icon.png" alt=""><span class="label">{e(c["label"])}</span></div>\n'
            + '<div class="hero-name">Rydd</div>\n'
            + f'<section class="grid poster"><div class="block"><h1 class="cond">{e(c["headline"])}</h1><p>{e(c["lead"])}</p></div>\n{facts([(k, e(v)) for k, v in c["facts"]])}</section>\n'
            + f'<section class="grid"><div class="big"><img src="{shot}" alt="{e(c["shot_alt"])}"></div></section>\n'
            + f'<section class="part rule grid cols"><h2 class="cond">{e(c["what"])}</h2><ul class="list">{features}</ul></section>\n'
            + f'<section id="download" class="part rule grid cols"><h2 class="cond">{e(c["get"])}</h2><div style="grid-column: 5 / span 8"><p>{e(text)}</p><div class="cta">{buttons}</div></div></section>\n'
            + f'<footer><span>© 2026 TangSpark</span><a href="{support}">{e(c["footer_support"])}</a></footer>\n</div></body></html>\n')


def support(lang):
    c, s = COPY[lang], LANGS[lang]["suffix"]
    section = lambda id, title, body: f'<section id="{id}" class="part rule grid cols"><h2 class="cond">{e(title)}</h2><div class="doc">{body}</div></section>\n'
    toc = "".join(f'<a href="#{id}">{e(t)}</a>' for id, t in c["toc"])
    start = "<ol class=\"steps\">" + "".join(f"<li>{e(x)}</li>" for x in c["start"]) + "</ol>"
    faq = "".join(f"<h3>{e(q)}</h3><p>{e(a)}</p>" for q, a in c["faq"])
    privacy = "".join(f"<p>{p}</p>" for p in c["privacy"])
    terms = "".join(f"<p>{e(p)}</p>" for p in c["terms"])
    notes = "".join(f"<h3>{e(v)}</h3><p class=\"meta\">{e(d)}</p><p>{e(t)}</p>" for v, d, t in c["notes"])
    return (head(lang, c["s_title"], c["s_lead"], "rydd-support")
            + nav(lang, "rydd-support", f'<a href="./rydd{s}.html">Rydd</a><a href="#privacy">{e(c["toc"][2][1])}</a><a href="#terms">{e(c["toc"][3][1])}</a>')
            + f'<div class="title"><img src="img/rydd-icon.png" alt=""><span class="label">Rydd {VERSION}</span></div>\n'
            + f'<div class="hero-name">{e(c["s_hero"])}</div>\n'
            + f'<section class="grid poster"><div class="block"><h1 class="cond">{e(c["s_headline"])}</h1><p>{e(c["s_lead"])}</p></div>{facts(c["s_facts"])}</section>\n'
            + f'<nav class="toc">{toc}</nav>\n'
            + section("start", c["toc"][0][1], start)
            + section("faq", c["toc"][1][1], faq)
            + section("privacy", c["privacy_title"], privacy)
            + section("terms", c["terms_title"], terms)
            + section("release-notes", c["notes_title"], notes)
            + section("contact", c["contact_title"], f"<p>{c['contact']}</p>")
            + f'<footer><span>© 2026 TangSpark</span><a href="./rydd{s}.html">Rydd</a></footer>\n</div></body></html>\n')


if __name__ == "__main__":
    DIST.mkdir(parents=True, exist_ok=True)
    for lang in LANGS:
        s = LANGS[lang]["suffix"]
        (DIST / f"rydd{s}.html").write_text(product(lang))
        (DIST / f"rydd-support{s}.html").write_text(support(lang))
    print(f"wrote {len(LANGS) * 2} pages for Rydd {VERSION} to {DIST.relative_to(ROOT)}")

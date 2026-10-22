#!/usr/bin/env python3
"""Builds a fake home with existing folders and a messy Downloads, plus expected.tsv for `rydd --expect`.

    make_fixture.py <dir> [--split dev|test|all]

Each Downloads case belongs to the dev split (used to tune prompts), the test split (held out, only
used to confirm), or both (rule cases). Expected answers may list alternatives separated by "|" when a
human would accept either.
"""
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile

FOLDERS = {
    "Documents/Finance/Invoices": ["Telia faktura 2026-08.pdf", "Telia faktura 2026-09.pdf",
                                   "Fjordkraft strøm august.pdf", "Stripe invoice 4411.pdf"],
    "Documents/Finance/发票": ["发票_淘宝_9月.pdf", "发票_京东_8月.pdf"],
    "Documents/Finance/Bank statements": ["DNB kontoutskrift januar.pdf", "Nordea statement Q2.pdf"],
    "Documents/Finance/Payslips": ["Lønnsslipp august 2026.pdf", "Payslip July 2026.pdf"],
    "Documents/Tax": ["Skattemelding 2024.pdf", "Skatteoppgjør 2024.pdf"],
    "Documents/Insurance": ["Gjensidige innboforsikring.pdf", "Travel insurance certificate 2025.pdf"],
    "Documents/Health": ["体检报告2025.pdf", "legeerklæring 2024.pdf", "Blood test results March.pdf"],
    "Documents/Health/Dental": ["Dental x-ray 2025.png", "Tannlege regning mars.pdf"],
    "Documents/Housing/Contracts": ["Leiekontrakt Majorstuen 2024.pdf", "Depositum kvittering.pdf"],
    "Documents/Travel/Japan 2025": ["Tokyo itinerary.pdf", "Kyoto hotel booking.pdf", "JR pass receipt.pdf"],
    "Documents/Travel/Italy 2024": ["Rome flight tickets.pdf", "Florence Airbnb.pdf", "Uffizi tickets.pdf"],
    "Documents/Career/CV": ["CV_2025_EN.docx", "Cover letter Equinor.docx"],
    "Documents/Career/Certificates": ["AWS Solutions Architect certificate.pdf", "Vitnemål master.pdf", "毕业证书.pdf"],
    "Documents/Work/Kvikkshot Marketing": ["Kvikkshot App Store screenshot 1.png", "Kvikkshot press release.pages"],
    "Documents/Work/Glimt Design": ["Glimt logo.svg", "Glimt onboarding mockup.png", "Glimt icon 1024.png"],
    "Documents/Work/Meetings": ["Standup notes 2026-09-12.md", "Q3 planning agenda.docx"],
    "Documents/School/Thesis": ["Thesis draft chapter 2.docx", "Literature review.docx"],
    "Documents/School/INF1000": ["INF1000 oblig 1.pdf", "Lecture 3 slides.pdf"],
    "Documents/Car": ["EU-kontroll 2024.pdf", "Bilforsikring Tesla.pdf"],
    "Documents/Recipes": ["Pasta carbonara.pdf", "红烧肉做法.pdf", "Kanelboller oppskrift.pdf"],
    "Documents/Manuals": ["Dyson V15 manual.pdf", "IKEA Malm instructions.pdf"],
    "Pictures/Wallpapers": ["wallpaper-forest-4k.jpg", "mountain wallpaper 5k.png"],
    "Pictures/Family": ["Mamma bursdag 2024.jpg", "春节合影.jpg", "Christmas dinner 2025.heic"],
    "Movies/Tutorials": ["SwiftUI tutorial part 1.mp4", "Blender donut tutorial.mp4"],
    "Desktop/Receipts": ["Elkjøp kvittering.pdf", "Apple Store receipt.pdf"],
    "Music": [],
}
PROJECTS = {
    "Documents/Kvikkshot": ["Package.swift", "Sources/main.swift"],
    "Documents/Glimt": ["Package.swift", "Sources/App.swift"],
}

INV, TRAVEL_JP = "Documents/Finance/Invoices", "Documents/Travel/Japan 2025"

# (name, expected, split, extra)  split: d = dev, t = test, b = both
CASES = [
    # ── Rules
    ("Screenshot 2026-10-01 at 10.22.11.png", "Pictures/Screenshots", "b", {}),
    ("Skjermbilde 2026-09-20 kl. 14.03.55.png", "Pictures/Screenshots", "b", {}),
    ("Screen Recording 2026-10-03 at 09.10.00.mov", "Movies/Screen Recordings", "b", {}),
    ("GoogleChrome.dmg", "trash", "b", {"size": 90000}),
    ("Glimt-1.3.dmg", "trash", "b", {"size": 90000}),
    ("SomeTool-2.0.dmg", "ask", "b", {"size": 90000}),
    ("project-assets.zip", "trash", "b", {"sibling_dir": "project-assets"}),
    ("report.pdf", "ask", "b", {"size": 33000}),
    ("report (1).pdf", "trash", "b", {"size": 33000}),
    ("ubuntu-24.04.iso.torrent", "trash", "b", {}),
    ("meeting.ics", "trash", "b", {}),
    ("big-file.zip.crdownload", "keep", "b", {}),
    ("Figma.app", "/Applications", "b", {"app": True}),

    # ── Name shares words with the right folder (layer ②)
    ("telia faktura oktober.pdf", INV, "d", {"from": "https://www.telia.no/minside/faktura?id=88213&token=abc"}),
    ("Fjordkraft strøm september.pdf", INV, "t", {}),
    ("invoice_8823.pdf", INV, "t", {"from": "https://pay.stripe.com/invoice/acct_1/pdf"}),
    ("发票_京东_10月.pdf", "Documents/Finance/发票", "d", {}),
    ("Skattemelding 2025.pdf", "Documents/Tax", "d", {"from": "https://www.skatteetaten.no/person/skatt/"}),
    ("体检报告2026.pdf", "Documents/Health", "t", {}),
    ("Blood test results September.pdf", "Documents/Health", "d", {}),
    ("Leiekontrakt Grünerløkka 2026.pdf", "Documents/Housing/Contracts", "t", {}),
    ("Osaka itinerary.pdf", TRAVEL_JP, "d", {}),
    ("CV_2026_NO.docx", "Documents/Career/CV", "t", {}),
    ("Kvikkshot App Store screenshot 2.png", "Documents/Work/Kvikkshot Marketing", "d", {}),
    ("wallpaper-ocean-4k.jpg", "Pictures/Wallpapers", "t", {}),
    ("Nordea statement Q3.pdf", "Documents/Finance/Bank statements", "d", {}),
    ("Kontoutskrift oktober.pdf", "Documents/Finance/Bank statements", "t", {}),
    ("Payslip October 2026.pdf", "Documents/Finance/Payslips", "t", {}),
    ("INF1000 oblig 2.pdf", "Documents/School/INF1000", "t", {}),
    ("Glimt app icon dark.png", "Documents/Work/Glimt Design", "d", {}),
    ("Glimt onboarding mockup v2.png", "Documents/Work/Glimt Design", "t", {}),
    ("Netflix kvittering.pdf", "Desktop/Receipts", "d", {}),
    ("Sonos setup instructions.pdf", "Documents/Manuals", "t", {}),
    ("Lasagne recipe.pdf", "Documents/Recipes", "d", {}),
    ("Thesis draft chapter 3.docx", "Documents/School/Thesis", "t", {}),
    ("Elkjøp ordrebekreftelse.pdf", "Desktop/Receipts", "t", {}),
    ("Home contents insurance renewal.pdf", "Documents/Insurance", "t", {}),
    ("Tax deduction summary.pdf", "Documents/Tax", "t", {}),

    # ── Meaning is in the name, but no shared word (layer ③)
    ("Shinkansen ticket Shin-Osaka.pdf", TRAVEL_JP, "d", {}),
    ("japansk visum søknad.pdf", TRAVEL_JP, "t", {}),
    ("大阪酒店确认.pdf", TRAVEL_JP, "d", {}),
    ("Universal Studios Osaka tickets.pdf", TRAVEL_JP, "t", {}),
    ("Strømregning oktober.pdf", INV, "d", {}),
    ("Electricity bill September.pdf", INV, "t", {}),
    ("Internet bill Altibox.pdf", INV, "d", {}),
    ("Mobilregning Telenor.pdf", INV, "t", {}),
    ("Bank transactions export.csv", "Documents/Finance/Bank statements", "d", {}),
    ("Salary slip October.pdf", "Documents/Finance/Payslips", "d", {}),
    ("Lønn september.pdf", "Documents/Finance/Payslips", "t", {}),
    ("Skattekort 2026.pdf", "Documents/Tax", "d", {}),
    ("Forsikringsbevis reise.pdf", "Documents/Insurance", "d", {}),
    ("MRI knee report.pdf", "Documents/Health", "d", {}),
    ("Vaccination certificate.pdf", "Documents/Health", "t", {}),
    ("疫苗接种记录.pdf", "Documents/Health", "d", {}),
    ("Resept Ibux.pdf", "Documents/Health", "t", {}),
    ("Tannlege timebestilling.pdf", "Documents/Health/Dental|Documents/Health", "d", {}),
    ("Root canal invoice.pdf", "Documents/Health/Dental|" + INV, "t", {}),
    ("Lease renewal 2026.pdf", "Documents/Housing/Contracts", "d", {}),
    ("租房合同.pdf", "Documents/Housing/Contracts", "t", {}),
    ("Resume_2026.pdf", "Documents/Career/CV", "d", {}),
    ("Søknad utvikler Vipps.docx", "Documents/Career/CV", "t", {}),
    ("Coursera Machine Learning completion.pdf", "Documents/Career/Certificates", "d", {}),
    ("Bachelor diploma.pdf", "Documents/Career/Certificates", "t", {}),
    ("Retro minutes sprint 14.docx", "Documents/Work/Meetings", "d", {}),
    ("1-on-1 talking points.docx", "Documents/Work/Meetings|ask", "t", {}),
    ("Masteroppgave kapittel 3.docx", "Documents/School/Thesis", "d", {}),
    ("论文初稿.docx", "Documents/School/Thesis", "t", {}),
    ("Dekkskift timebestilling.pdf", "Documents/Car", "d", {}),
    ("Tesla service invoice.pdf", "Documents/Car|" + INV, "t", {}),
    ("Banana bread.pdf", "Documents/Recipes", "d", {}),
    ("宫保鸡丁.pdf", "Documents/Recipes", "t", {}),
    ("Bosch dishwasher user guide.pdf", "Documents/Manuals", "d", {}),
    ("AirPods Pro brukerveiledning.pdf", "Documents/Manuals", "t", {}),
    ("Bestemor 90 år.jpg", "Pictures/Family", "d", {}),
    ("家庭聚会2026.jpg", "Pictures/Family", "t", {}),
    ("Python crash course lesson 2.mp4", "Movies/Tutorials", "d", {}),
    ("Figma auto layout walkthrough.mp4", "Movies/Tutorials", "t", {}),
    ("Order confirmation Zalando.pdf", "Desktop/Receipts|ask", "d", {}),

    # ── Traps: share a word with a folder but don't belong
    ("Apple Store opening hours.pdf", "ask", "d", {}),
    ("Kyoto protocol essay.docx", "ask|Documents/School/Thesis", "t", {}),
    ("Telia Arena concert tickets.pdf", "ask", "d", {}),
    ("Italian grammar exercises.pdf", "ask", "t", {}),
    ("Japan population statistics.xlsx", "ask", "d", {}),
    ("Tesla stock analysis.xlsx", "ask", "t", {}),
    ("Insurance industry overview.pdf", "ask", "d", {}),
    ("Blood orange sorbet.pdf", "Documents/Recipes|ask", "t", {}),
    ("Tokyo Olympics wallpaper.jpg", "Pictures/Wallpapers|Pictures", "d", {}),
    ("Netflix Japan documentary.mp4", "Movies|ask", "t", {}),
    ("Dyson vacuum invoice.pdf", INV + "|Desktop/Receipts", "d", {}),
    ("Glimt competitor analysis.pdf", "ask", "t", {}),
    ("Health app privacy policy.pdf", "ask", "t", {}),
    ("Car wallpaper 4k.jpg", "Pictures/Wallpapers|Pictures", "d", {}),
    ("Family Guy episode list.pdf", "ask", "t", {}),

    # ── Names that say nothing
    ("document(3).pdf", "ask", "b", {}),
    ("a8f3e2d1-77b2.pdf", "ask", "b", {}),
    ("IMG_2034.HEIC", "Pictures", "b", {}),
    ("Movie trailer.mp4", "Movies", "b", {}),
    ("untitled.docx", "ask", "d", {}),
    ("image (2).png", "Pictures", "d", {}),
    ("Download.pdf", "ask", "t", {}),
    ("output.csv", "ask", "t", {}),

    # ── Only the opt-in content layer can place these
    ("scan0012.pdf", INV, "b", {"pdf": "Telia Norge AS\nFaktura oktober 2026\nFakturanummer 88213\nMobilabonnement Telia X  Beløp 449 kr"}),
    ("booking-HTL88213.pdf", TRAVEL_JP, "b", {"pdf": "Booking confirmation\nOsaka Namba hotel, Japan\nCheck-in 12 March\nKyoto Tokyo itinerary rail pass"}),
    ("notes.txt", TRAVEL_JP, "b", {"text": "Trip notes: Kyoto temples, Tokyo itinerary day 3, JR pass, Osaka food"}),
]


def blank(path, size=20000):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\0" * size)


def where_from(path, url):
    data = plistlib.dumps([url], fmt=plistlib.FMT_BINARY).hex()
    subprocess.run(["xattr", "-wx", "com.apple.metadata:kMDItemWhereFroms", data, path], check=True)


def pdf(path, text):
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as t:
        t.write(text)
    with open(path, "wb") as out:
        subprocess.run(["cupsfilter", "-m", "application/pdf", t.name], stdout=out, stderr=subprocess.DEVNULL, check=True)
    os.unlink(t.name)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = os.path.abspath(sys.argv[1])
    split = sys.argv[sys.argv.index("--split") + 1] if "--split" in sys.argv else "all"
    shutil.rmtree(root, ignore_errors=True)

    for folder, names in {**FOLDERS, **PROJECTS}.items():
        os.makedirs(os.path.join(root, folder), exist_ok=True)
        for n in names:
            blank(os.path.join(root, folder, n))

    dl = os.path.join(root, "Downloads")
    os.makedirs(dl)
    picked = [c for c in CASES if split == "all" or c[2] == "b" or c[2] == split[0]]
    with open(os.path.join(root, "expected.tsv"), "w") as exp:
        for name, expected, _, extra in picked:
            path = os.path.join(dl, name)
            if extra.get("app"):
                blank(os.path.join(path, "Contents/Info.plist"))
            elif "pdf" in extra:
                pdf(path, extra["pdf"])
            elif "text" in extra:
                with open(path, "w") as f:
                    f.write(extra["text"])
            else:
                blank(path, extra.get("size", 20000))
            if "from" in extra:
                where_from(path, extra["from"])
            if "sibling_dir" in extra:
                blank(os.path.join(dl, extra["sibling_dir"], "logo.png"))
            exp.write(f"{name}\t{expected}\n")
    print(f"fixture ready: {root} (split {split}, {len(picked)} expected answers)")


if __name__ == "__main__":
    main()

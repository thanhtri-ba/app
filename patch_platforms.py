#!/usr/bin/env python3
"""Adds the photo-library permissions to the generated Android / iOS projects."""
import plistlib
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent

# ---------- Android ----------
manifest = root / "android/app/src/main/AndroidManifest.xml"
if manifest.exists():
    xml = manifest.read_text(encoding="utf-8")
    perms = [
        '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>',
        '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>',
        '<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>',
        '<uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION"/>',
    ]
    missing = [p for p in perms if p.split('"')[1] not in xml]
    if missing:
        xml = xml.replace("<application", "\n    ".join(missing) + "\n    <application", 1)
    if "requestLegacyExternalStorage" not in xml:
        xml = xml.replace("<application", '<application android:requestLegacyExternalStorage="true"', 1)
    manifest.write_text(xml, encoding="utf-8")
    print("patched", manifest)
else:
    print("AndroidManifest.xml not found, skipped", file=sys.stderr)

# ---------- iOS ----------
plist = root / "ios/Runner/Info.plist"
if plist.exists():
    with plist.open("rb") as f:
        data = plistlib.load(f)
    data["NSPhotoLibraryUsageDescription"] = (
        "Photo Cleaner analyses your photos on this device so you can review and clean them up."
    )
    data["NSPhotoLibraryAddUsageDescription"] = "Photo Cleaner may save edited photos to your library."
    with plist.open("wb") as f:
        plistlib.dump(data, f)
    print("patched", plist)
else:
    print("Info.plist not found, skipped", file=sys.stderr)

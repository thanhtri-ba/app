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

# ---------- Android: notifications ----------
if manifest.exists():
    xml = manifest.read_text(encoding="utf-8")
    if "POST_NOTIFICATIONS" not in xml:
        xml = xml.replace(
            "<application",
            '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application',
            1,
        )
        manifest.write_text(xml, encoding="utf-8")
        print("added POST_NOTIFICATIONS")

# flutter_local_notifications needs core library desugaring
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    g = root / name
    if not g.exists():
        continue
    txt = g.read_text(encoding="utf-8")
    kts = name.endswith(".kts")
    if "coreLibraryDesugaring" in txt:
        break
    flag = "isCoreLibraryDesugaringEnabled = true" if kts else "coreLibraryDesugaringEnabled true"
    txt = re.sub(r"(compileOptions\s*\{)", r"\1\n        " + flag, txt, count=1)
    dep = (
        'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        if kts
        else "dependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    )
    txt = txt.rstrip() + "\n\n" + dep
    g.write_text(txt, encoding="utf-8")
    print("enabled core library desugaring in", name)
    break

# ---------- Vault: biometrics, screenshot blocking, no cloud backup ----------
if manifest.exists():
    xml = manifest.read_text(encoding="utf-8")
    if "USE_BIOMETRIC" not in xml:
        xml = xml.replace(
            "<application",
            '<uses-permission android:name="android.permission.USE_BIOMETRIC"/>\n    <application',
            1,
        )
        print("added USE_BIOMETRIC")
    # Encrypted vault files restored from a backup would be useless without the Keystore key.
    if "android:allowBackup" not in xml:
        xml = xml.replace("<application", '<application android:allowBackup="false"', 1)
        print("disabled allowBackup")
    manifest.write_text(xml, encoding="utf-8")

# local_auth needs a FragmentActivity; the channel below toggles FLAG_SECURE for the vault.
kt_files = list((root / "android/app/src/main").glob("**/MainActivity.kt"))
for kt in kt_files:
    src = kt.read_text(encoding="utf-8")
    if "photo_cleaner/secure" in src:
        print("MainActivity already patched")
        continue
    m = re.search(r"^package\s+([\w.]+)", src, re.M)
    if not m:
        print("MainActivity: package line not found, skipped", file=sys.stderr)
        continue
    kt.write_text(
        f"""package {m.group(1)}

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "photo_cleaner/secure")
            .setMethodCallHandler {{ call, result ->
                if (call.method == "setSecure") {{
                    val on = call.arguments as? Boolean ?: false
                    runOnUiThread {{
                        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }}
                    result.success(null)
                }} else {{
                    result.notImplemented()
                }}
            }}
    }}
}}
""",
        encoding="utf-8",
    )
    print("patched", kt)

if plist.exists():
    with plist.open("rb") as f:
        data = plistlib.load(f)
    data["NSFaceIDUsageDescription"] = "Unlock your private vault with Face ID."
    with plist.open("wb") as f:
        plistlib.dump(data, f)
    print("added NSFaceIDUsageDescription")

# ---------- iOS: ML Kit text recognition needs iOS 15.5+ ----------
podfile = root / "ios/Podfile"
if podfile.exists():
    txt = podfile.read_text(encoding="utf-8")
    new = re.sub(r"^\s*#?\s*platform :ios, '[\d.]+'", "platform :ios, '15.5'", txt, count=1, flags=re.M)
    if new != txt:
        podfile.write_text(new, encoding="utf-8")
        print("Podfile: platform :ios, '15.5'")
    elif "platform :ios" not in txt:
        podfile.write_text("platform :ios, '15.5'\n" + txt, encoding="utf-8")
        print("Podfile: added platform :ios, '15.5'")
pbx = root / "ios/Runner.xcodeproj/project.pbxproj"
if pbx.exists():
    txt = pbx.read_text(encoding="utf-8")
    new = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = (\d+\.\d+);", "IPHONEOS_DEPLOYMENT_TARGET = 15.5;", txt)
    if new != txt:
        pbx.write_text(new, encoding="utf-8")
        print("project.pbxproj: IPHONEOS_DEPLOYMENT_TARGET = 15.5")

# ---------- Android: light_compressor_v2 needs minSdk 24 ----------
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    g = root / name
    if not g.exists():
        continue
    txt = g.read_text(encoding="utf-8")
    new = re.sub(r"minSdk(Version)?(\s*=\s*|\s+)flutter\.minSdkVersion", lambda m: "minSdk" + (m.group(1) or "") + m.group(2) + "maxOf(24, flutter.minSdkVersion)" if name.endswith(".kts") else "minSdkVersion" + m.group(2) + "Math.max(24, flutter.minSdkVersion)", txt, count=1)
    if new != txt:
        g.write_text(new, encoding="utf-8")
        print("minSdk raised to >= 24 in", name)
    else:
        print("minSdk unchanged in", name, "(check it is >= 24 manually)")
    break

# ---------- Auth: internet, deep link for e-mail links / OAuth (photocleaner://login-callback) ----------
if manifest.exists():
    xml = manifest.read_text(encoding="utf-8")
    changed = False
    if "android.permission.INTERNET" not in xml:
        # Release builds do not get INTERNET from the debug manifest.
        xml = xml.replace(
            "<application",
            '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
            1,
        )
        changed = True
    if 'android:scheme="photocleaner"' not in xml:
        block = (
            '<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>\n'
            "            <intent-filter>\n"
            '                <action android:name="android.intent.action.VIEW"/>\n'
            '                <category android:name="android.intent.category.DEFAULT"/>\n'
            '                <category android:name="android.intent.category.BROWSABLE"/>\n'
            '                <data android:scheme="photocleaner" android:host="login-callback"/>\n'
            "            </intent-filter>\n"
            "        </activity>"
        )
        if "</activity>" in xml:
            xml = xml.replace("</activity>", block, 1)
            changed = True
        else:
            print("no </activity> found, add the deep-link intent-filter manually", file=sys.stderr)
    if changed:
        manifest.write_text(xml, encoding="utf-8")
        print("added INTERNET permission / deep link intent-filter")

if plist.exists():
    with plist.open("rb") as f:
        data = plistlib.load(f)
    want = [{"CFBundleURLName": "photocleaner", "CFBundleURLSchemes": ["photocleaner"]}]
    if data.get("CFBundleURLTypes") != want or data.get("FlutterDeepLinkingEnabled") is not False:
        data["CFBundleURLTypes"] = want
        data["FlutterDeepLinkingEnabled"] = False
        with plist.open("wb") as f:
            plistlib.dump(data, f)
        print("added URL scheme photocleaner:// to Info.plist")

#!/usr/bin/env python3
"""上架前静态检查，只读源码，Linux 上可跑。

用法：python3 scripts/preflight.py            检查源码
      python3 scripts/preflight.py --app X.app 额外检查构建产物（macOS CI 用）
"""
import json, plistlib, re, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "App"
SOURCE_DIRS = [APP_DIR, *(ROOT / "Packages").glob("*/Sources")]

# 代码里出现 → Info.plist 必须有对应的权限说明，否则调用时直接崩溃
USAGE_KEYS = {
    r"AVCaptureDevice|AVCaptureSession": "NSCameraUsageDescription",
    r"AVAudioRecorder|requestRecordPermission|AVAudioApplication": "NSMicrophoneUsageDescription",
    r"CLLocationManager|CLLocationUpdate": "NSLocationWhenInUseUsageDescription",
    r"PHPhotoLibrary|PHAsset": "NSPhotoLibraryUsageDescription",
    r"CNContactStore": "NSContactsUsageDescription",
    r"EKEventStore": "NSCalendarsFullAccessUsageDescription",
    r"CBCentralManager|CBPeripheralManager": "NSBluetoothAlwaysUsageDescription",
    r"HKHealthStore": "NSHealthShareUsageDescription",
    r"\.faceID|biometryType": "NSFaceIDUsageDescription",
    r"ATTrackingManager": "NSUserTrackingUsageDescription",
    r"CMMotionManager|CMPedometer": "NSMotionUsageDescription",
    r"SFSpeechRecognizer": "NSSpeechRecognitionUsageDescription",
    r"NFCNDEFReaderSession|NFCTagReaderSession": "NFCReaderUsageDescription",
}

# 代码里出现 → 隐私清单必须申报对应的 required-reason API 类别，否则拒审
REQUIRED_REASON = {
    r"UserDefaults|@AppStorage": "NSPrivacyAccessedAPICategoryUserDefaults",
    r"creationDate|modificationDate|attributesOfItem|\.fileModificationDate": "NSPrivacyAccessedAPICategoryFileTimestamp",
    r"systemUptime|mach_absolute_time": "NSPrivacyAccessedAPICategorySystemBootTime",
    r"volumeAvailableCapacity|systemFreeSize|statfs": "NSPrivacyAccessedAPICategoryDiskSpace",
    r"activeInputModes": "NSPrivacyAccessedAPICategoryActiveKeyboards",
}

results = []
def check(ok, msg):
    results.append((ok, msg))

def sources():
    text = ""
    for d in SOURCE_DIRS:
        for f in d.rglob("*.swift"):
            text += f.read_text() + "\n"
    return text

def png_info(path):
    data = path.read_bytes()[:33]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    w, h, _depth, color_type = struct.unpack(">IIBB", data[16:26])
    return w, h, color_type in (4, 6)  # 4/6 = 带 alpha

def main():
    project = (ROOT / "project.yml").read_text()
    info_plist_path = APP_DIR / "Info.plist"
    info = plistlib.loads(info_plist_path.read_bytes()) if info_plist_path.exists() else {}
    code = sources()

    def has_info_key(key):
        return key in info or re.search(rf"INFOPLIST_KEY_{key}\s*:", project) is not None

    # 1. 权限说明
    for pattern, key in USAGE_KEYS.items():
        if re.search(pattern, code):
            check(has_info_key(key), f"代码用到 /{pattern}/ → 需要 {key}")

    # 2. 隐私清单
    manifest_path = APP_DIR / "PrivacyInfo.xcprivacy"
    check(manifest_path.exists(), "隐私清单 App/PrivacyInfo.xcprivacy 存在")
    declared = set()
    if manifest_path.exists():
        manifest = plistlib.loads(manifest_path.read_bytes())
        for entry in manifest.get("NSPrivacyAccessedAPITypes", []):
            if entry.get("NSPrivacyAccessedAPITypeReasons"):
                declared.add(entry.get("NSPrivacyAccessedAPIType"))
        check("NSPrivacyTracking" in manifest, "隐私清单声明了 NSPrivacyTracking")
    for pattern, category in REQUIRED_REASON.items():
        if re.search(pattern, code):
            check(category in declared, f"代码用到 /{pattern}/ → 隐私清单需申报 {category}（含理由码）")

    # 3. 图标：1024×1024，无透明通道
    icons = list(APP_DIR.glob("**/AppIcon.appiconset/*.png"))
    big = [i for i in icons if (p := png_info(i)) and p[:2] == (1024, 1024)]
    check(bool(big), "AppIcon 有 1024×1024 PNG")
    for i in big:
        check(not png_info(i)[2], f"{i.name} 无透明通道（App Store 拒收带 alpha 的图标）")

    # 4. 加密合规：不声明则每次上传都要手动回答
    check("ITSAppUsesNonExemptEncryption" in info, "Info.plist 声明了 ITSAppUsesNonExemptEncryption")

    # 5. iPad：支持 iPad 时须支持全部四个方向（否则要声明 UIRequiresFullScreen）
    family = re.search(r'TARGETED_DEVICE_FAMILY:\s*"?([\d,]+)', project)
    if family and "2" in family.group(1).split(","):
        ipad = re.search(r"INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad:\s*\"?([^\"\n]+)", project)
        orientations = set(ipad.group(1).split()) if ipad else set()
        check(len(orientations) == 4 or has_info_key("UIRequiresFullScreen"), "iPad 支持全部四个方向")

    # 6. 本地化完整性
    for catalog in APP_DIR.rglob("*.xcstrings"):
        cat = json.loads(catalog.read_text())
        langs = {l for s in cat["strings"].values() for l in s.get("localizations", {})}
        for key, entry in cat["strings"].items():
            if entry.get("shouldTranslate") is False:
                continue
            for lang in langs:
                unit = entry.get("localizations", {}).get(lang, {}).get("stringUnit", {})
                check(unit.get("state") == "translated", f"{catalog.name}: \"{key}\" 已翻译为 {lang}")
        # 代码里的字面量文本应在字符串目录里
        for literal in set(re.findall(r'(?:Text|Button)\("([^"\\]+)"', code)):
            check(literal in cat["strings"], f"界面文本 \"{literal}\" 已加入 {catalog.name}")

    # 7. 构建产物检查（可选）
    if "--app" in sys.argv:
        app = Path(sys.argv[sys.argv.index("--app") + 1])
        built = plistlib.loads((app / "Info.plist").read_bytes())
        check((app / "PrivacyInfo.xcprivacy").exists(), "产物包含 PrivacyInfo.xcprivacy")
        check("CFBundleIcons" in built or "CFBundleIcons~ipad" in built, "产物 Info.plist 含图标声明")
        check((app / "Assets.car").exists(), "产物包含 Assets.car")
        for lang in info.get("CFBundleLocalizations", []):
            if lang != "en":
                check((app / f"{lang}.lproj").exists(), f"产物包含 {lang}.lproj")
        check(built.get("MinimumOSVersion") is not None, f"最低系统版本 {built.get('MinimumOSVersion')}")

    failed = [m for ok, m in results if not ok]
    for ok, msg in results:
        print(("  ✓ " if ok else "  ✗ ") + msg)
    print(f"\npreflight: {len(results) - len(failed)}/{len(results)} 通过")
    sys.exit(1 if failed else 0)

if __name__ == "__main__":
    main()

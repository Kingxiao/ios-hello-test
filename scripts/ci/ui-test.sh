#!/usr/bin/env bash
# 在指定机型和 iOS 版本的模拟器上编译、跑 UI 测试、导出截图。macOS CI 用。
# 用法：ui-test.sh <设备类型ID后缀，如 iPhone-17-Pro> [iOS 版本前缀，默认最新] [外观，默认 "light dark"]
# 第一个外观跑全部测试，其余外观只跑截图和无障碍审计。
# 注意：macOS 自带 bash 3.2，空数组展开要用 ${a[@]+"${a[@]}"}
set -euo pipefail
DEVICE=$1
OS=${2:-latest}
APPEARANCES=${3:-"light dark"}
mkdir -p logs out/screenshots

read -r RUNTIME VER < <(xcrun simctl list runtimes -j | python3 -c '
import json, sys
want = sys.argv[1]
rs = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]]
if want != "latest":
    rs = [r for r in rs if r["version"] == want or r["version"].startswith(want + ".")]
if not rs:
    sys.exit(f"没有可用的 iOS {want} 运行时")
rs.sort(key=lambda r: [int(p) for p in r["version"].split(".")])
print(rs[-1]["identifier"], rs[-1]["version"])
' "$OS")
[ -n "${RUNTIME:-}" ] || { echo "找不到 iOS $OS 运行时"; exit 1; }
echo "== $DEVICE / iOS $VER ($RUNTIME) / $(xcodebuild -version | head -1)"

UDID=$(xcrun simctl create "ci-$DEVICE" "com.apple.CoreSimulator.SimDeviceType.$DEVICE" "$RUNTIME")
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
DEST="platform=iOS Simulator,id=$UDID"

set -o pipefail
xcodebuild build-for-testing -project HelloApp.xcodeproj -scheme HelloApp \
  -destination "$DEST" -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  > logs/build.log 2>&1 || { tail -50 logs/build.log; exit 1; }
echo "build-for-testing OK"

python3 scripts/preflight.py --app build/Build/Products/Debug-iphonesimulator/HelloApp.app

rc=0
first=1
for appearance in $APPEARANCES; do
  xcrun simctl ui "$UDID" appearance "$appearance"
  only=()
  [ $first = 1 ] || only=(-only-testing:HelloAppUITests/HelloAppUITests/testScreenshotMatrix -only-testing:HelloAppUITests/HelloAppUITests/testAccessibilityAudit)
  first=0
  bundle="build/$appearance.xcresult"
  echo "== tests ($appearance)"
  TEST_RUNNER_SHOT_PREFIX="$DEVICE-ios$VER-$appearance" \
    xcodebuild test-without-building -project HelloApp.xcodeproj -scheme HelloApp \
    -destination "$DEST" -derivedDataPath build -resultBundlePath "$bundle" \
    ${only[@]+"${only[@]}"} > "logs/test-$appearance.log" 2>&1 || rc=1
  grep -E "Test Case .*(passed|failed)|\*\* TEST" "logs/test-$appearance.log" || true

  # 失败详情（无障碍审计的问题会列在这里）
  xcrun xcresulttool get test-results summary --path "$bundle" 2>/dev/null | python3 -c '
import json, sys
for f in json.load(sys.stdin).get("testFailures", []):
    print("  FAIL", f.get("testName"), "→", f.get("failureText"))
' || true

  # 导出截图，按 attachment 名重命名
  raw="out/raw-$appearance"
  mkdir -p "$raw"
  xcrun xcresulttool export attachments --path "$bundle" --output-path "$raw" >/dev/null 2>&1 || continue
  python3 - "$raw" <<'PY'
import json, shutil, sys
raw = sys.argv[1]
for test in json.load(open(f"{raw}/manifest.json")):
    for a in test["attachments"]:
        name = a["suggestedHumanReadableName"].split("_")[0]
        if name.startswith("Screenshot"):  # 系统在失败时自动截的图，保留但加前缀
            name = "auto-" + a["exportedFileName"].rsplit(".", 1)[0]
        shutil.copy(f"{raw}/{a['exportedFileName']}", f"out/screenshots/{name}.png")
PY
done
ls out/screenshots
exit $rc

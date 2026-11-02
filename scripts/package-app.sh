#!/bin/bash
set -euo pipefail
package_failure() {
  printf '打包失败（退出码 %s，行 %s）：%s\n' "$1" "$2" "$3" >&2
  exit "$1"
}
trap 'package_failure "$?" "$LINENO" "$BASH_COMMAND"' ERR
cd "$(dirname "$0")/.."
input_app="$PWD/build/QingType.app"
version=$(python3 scripts/version.py read)
python3 scripts/version.py check-bundles "$input_app" "$input_app/Contents/Applications/QingType Settings.app"
test -x "$input_app/Contents/MacOS/QingType"
codesign --verify --deep --strict "$input_app"
distribution="${QINGTYPE_DISTRIBUTION_DIR:-$PWD/build/distribution}"
app="$distribution/清言.app"
mkdir -p "$distribution"
rm -rf "$app"
ditto "$input_app/Contents/Applications/QingType Settings.app" "$app"
mkdir -p "$app/Contents/Resources/InputMethod"
ditto "$input_app" "$app/Contents/Resources/InputMethod/QingType.app"
python3 - "$app" <<'PY'
import plistlib, sys
from pathlib import Path
p = Path(sys.argv[1]) / 'Contents/Info.plist'
info = plistlib.loads(p.read_bytes())
info.update(CFBundleIdentifier='org.qingtype.app', CFBundleName='清言', CFBundleDisplayName='清言', LSApplicationCategoryType='public.app-category.utilities')
p.write_bytes(plistlib.dumps(info))
PY
# Sign from inner libraries outwards when a Developer ID is supplied.
identity="${QINGTYPE_SIGN_IDENTITY:--}"
if [[ "$identity" != "-" ]]; then
  payload="$app/Contents/Resources/InputMethod/QingType.app"
  while IFS= read -r -d '' library; do
    codesign --force --options runtime --timestamp --sign "$identity" "$library"
  done < <(find "$payload/Contents/Frameworks" -type f -name '*.dylib' -print0)
  codesign --force --options runtime --timestamp --sign "$identity" "$payload/Contents/Applications/QingType Settings.app"
  codesign --force --options runtime --timestamp --sign "$identity" "$payload"
  codesign --force --options runtime --timestamp --sign "$identity" "$app"
else
  codesign --force --sign - "$app"
fi
codesign --verify --deep --strict "$app"
python3 scripts/version.py check-bundles "$app" "$app/Contents/Resources/InputMethod/QingType.app" "$app/Contents/Resources/InputMethod/QingType.app/Contents/Applications/QingType Settings.app"
image="$distribution/$(python3 scripts/version.py package-name "$(uname -m)")"
stage=$(mktemp -d "$PWD/build/dmg-stage-XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/清言.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/安装说明.txt" <<'TEXT'
将「清言.app」拖入「Applications」，然后打开清言。
在「开始使用」点击「安装并启用清言」，再从系统输入菜单选择清言。
基础输入可离线使用。雾凇拼音与万象模型可以跳过，之后在软件内按需下载安装。

TEXT
if [[ "$identity" == "-" ]]; then
  echo '此构建为本地预览版，采用临时签名，尚未完成 Developer ID 签名与 Apple 公证。' >> "$stage/安装说明.txt"
fi
rm -f "$image"
hdiutil create -volname "清言 $version" -srcfolder "$stage" -format UDZO "$image"
if [[ "$identity" != "-" ]]; then codesign --force --timestamp --sign "$identity" "$image"; fi
(cd "$distribution" && shasum -a 256 "$(basename "$image")" > "$(basename "$image").sha256")
echo "已生成：$image"

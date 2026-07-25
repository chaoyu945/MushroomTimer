#!/bin/sh
# 從 repo 根目錄的 icon.jpeg（正方形、任意尺寸）重建 app icon 資產。
# icon 圖檔與 Assets.xcassets 皆不進版控（私人照片），
# 換機器或 fresh clone 後執行本腳本即可重建。
set -eu
cd "$(dirname "$0")/.."

if [ ! -f icon.jpeg ]; then
  echo "找不到 icon.jpeg，請放一張正方形照片到 repo 根目錄" >&2
  exit 1
fi

ICONSET=MushroomTimer/Assets.xcassets/AppIcon.appiconset
mkdir -p "$ICONSET"

cat > MushroomTimer/Assets.xcassets/Contents.json <<'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > "$ICONSET/Contents.json" <<'EOF'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

sips -z 1024 1024 -s format png icon.jpeg --out "$ICONSET/AppIcon.png" >/dev/null
xcodegen generate
echo "完成：AppIcon 已更新，Xcode 專案已重新產生"

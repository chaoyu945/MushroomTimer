#!/bin/sh
# 從 repo 根目錄的 icon.jpeg（正方形、任意尺寸）重建 app icon 資產。
# icon 圖檔與 Assets.xcassets 皆不進版控（私人照片），
# 換機器或 fresh clone 後執行本腳本即可重建。
#
# 這裡刻意產生**完整的**尺寸組，而不是只放一張 1024 讓 Xcode 自己衍生。
# 只放 1024 時實測結果是 Assets.car 裡只有那一張原圖，通知用的 20pt 小圖示
# 根本沒被產生出來——桌面圖示正常（另有一張鬆散的 120×120），
# 但通知中心顯示空白圖示。
set -eu
cd "$(dirname "$0")/.."

if [ ! -f icon.jpeg ]; then
  echo "找不到 icon.jpeg，請放一張正方形照片到 repo 根目錄" >&2
  exit 1
fi

ICONSET=MushroomTimer/Assets.xcassets/AppIcon.appiconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

cat > MushroomTimer/Assets.xcassets/Contents.json <<'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# 每一列是「輸出檔名 像素尺寸」。
# 20pt 是通知、29pt 是設定、40pt 是 Spotlight、60pt 是桌面、1024 是 App Store。
render() {
  sips -z "$2" "$2" -s format png icon.jpeg --out "$ICONSET/$1" >/dev/null
}

render icon-20@2x.png 40
render icon-20@3x.png 60
render icon-29@2x.png 58
render icon-29@3x.png 87
render icon-40@2x.png 80
render icon-40@3x.png 120
render icon-60@2x.png 120
render icon-60@3x.png 180
render icon-1024.png 1024

cat > "$ICONSET/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "icon-20@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "filename" : "icon-20@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "filename" : "icon-29@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon-29@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "icon-40@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "icon-40@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "icon-60@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "icon-60@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "icon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

xcodegen generate
echo "完成：AppIcon 已重建為完整尺寸組，Xcode 專案已重新產生"

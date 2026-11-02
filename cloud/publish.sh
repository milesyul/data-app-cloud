#!/bin/bash
# 把 cloud/ 下的数据 JSON 与最新 APK 推送到 GitHub 公开仓库，
# 实现「配置数据云端托管 + 本地缓存」与「App 内在线更新」。
#
# 用法：  bash cloud/publish.sh [仓库名] [APK路径]
#   - 仓库名默认 toolkit-app-cloud
#   - APK 默认 /workspace/ToolkitApp-debug.apk（不存在则只推送数据）
#   - 需先登录 gh： gh auth login
set -e

REPO="${1:-toolkit-app-cloud}"
APK="${2:-/workspace/ToolkitApp-debug.apk}"
BRANCH=main
SRC=/workspace/cloud

USER=$(gh api user --jq .login 2>/dev/null || true)
if [ -z "$USER" ]; then
  echo "未检测到 gh 登录，请先执行： gh auth login" >&2
  exit 1
fi
echo "GitHub 账号: $USER   仓库: $REPO"

TMP=$(mktemp -d)
cp -r "$SRC/." "$TMP/"
if [ -f "$APK" ]; then
  cp "$APK" "$TMP/ToolkitApp-debug.apk"
  URL="https://raw.githubusercontent.com/$USER/$REPO/$BRANCH/ToolkitApp-debug.apk"
  # 把 version.json 的 apkUrl 替换为真实地址
  python3 - "$TMP/version.json" "$URL" <<'PY'
import json, sys
p, url = sys.argv[1], sys.argv[2]
d = json.load(open(p, encoding='utf-8'))
d['apkUrl'] = url
open(p, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2))
PY
  echo "已设置 apkUrl = $URL"
else
  echo "未找到 APK（$APK），仅推送数据 JSON。"
fi

cd "$TMP"
git init -q
git add -A
git -c user.email=ci@example.com -c user.name=ci commit -qm "cloud data + apk"
gh repo create "$REPO" --public --source . --remote origin --push \
  || git push -u origin "HEAD:$BRANCH"

rm -rf "$TMP"
echo
echo "===== 完成 ====="
echo "云端数据根地址（请把下面这行填到 CloudSync.BASE_URL）："
echo "https://raw.githubusercontent.com/$USER/$REPO/$BRANCH/cloud/"

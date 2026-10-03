#!/usr/bin/env bash
# 从聚合仓 r-y-ren/web-3d-stack 拉取最新 web-3d-stack 技能目录，覆盖本仓副本。
# 同步链：四上游 →（聚合仓 scripts/sync-upstream.sh，先跑并推送）→ 聚合仓 → 本脚本 → 本仓。
# 用法: scripts/sync-web-3d-stack.sh [--no-commit]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

src="https://github.com/r-y-ren/web-3d-stack.git"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone --depth 1 "$src" "$tmp/w"
rm -rf skills/web-3d-stack
cp -r "$tmp/w/skills/web-3d-stack" skills/
rm -rf docs/licenses
mkdir -p docs/licenses
cp -r "$tmp/w/docs/licenses/." docs/licenses/ 2>/dev/null || true

git add -A skills/web-3d-stack docs/licenses
if [ "${1:-}" != "--no-commit" ]; then
  git commit -m "chore(sync): refresh web-3d-stack from aggregation repo" || echo "(无变更)"
fi
echo "完成。核对 toolbox 路由表与 web-3d-stack/SKILL.md 描述是否仍一致。"

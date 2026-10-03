#!/usr/bin/env bash
# 四上游 → 本仓直连同步：重建 skills/web-3d-stack/refs/，刷新 docs/licenses/。
# 同步后自动校验路由 SKILL.md 分派表引用的路径仍全部存在，失效则报错退出。
# 用法: scripts/sync-web-3d-stack.sh [--no-commit]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

declare -A UP=(
  [threejs]="https://github.com/cloudai-x/threejs-skills.git"
  [threejs-game]="https://github.com/majidmanzarpour/threejs-game-skills.git"
  [webgpu-tsl]="https://github.com/dgreenheck/webgpu-claude-skill.git"
  [shadcn]="https://github.com/shadcn-ui/ui.git"
)

REFS="skills/web-3d-stack/refs"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for seg in threejs threejs-game webgpu-tsl shadcn; do
  echo "== $seg <- ${UP[$seg]}"
  git clone --depth 1 "${UP[$seg]}" "$tmp/$seg" 2>/dev/null
  rm -rf "$REFS/$seg"
  mkdir -p "$REFS/$seg"
  # 四个上游的技能都在各自仓库的 skills/ 下
  cp -r "$tmp/$seg/skills/." "$REFS/$seg/"
done

# 许可文本（threejs/webgpu 上游无 LICENSE 文件，许可为 README/plugin.json 声明式记录，见 SKILL.md 来源表）
mkdir -p docs/licenses
cp "$tmp/threejs-game/LICENSE"   docs/licenses/threejs-game-skills-MIT 2>/dev/null || true
cp "$tmp/shadcn/LICENSE.md"      docs/licenses/shadcn-ui-MIT          2>/dev/null || true

# 分派表路径完整性校验：路由 SKILL.md 引用的 refs/**/SKILL.md 必须都存在
python3 - <<'PY'
import re, pathlib, sys
root = pathlib.Path("skills/web-3d-stack")
s = (root / "SKILL.md").read_text()
paths = set(re.findall(r"refs/[A-Za-z0-9_\-/]+/SKILL\.md", s))
missing = sorted(p for p in paths if not (root / p).exists())
if missing:
    sys.exit("分派表失效——路由 SKILL.md 引用的文档已不存在:\n  " + "\n  ".join(missing) + "\n请先更新 skills/web-3d-stack/SKILL.md 再提交。")
print(f"分派表 {len(paths)} 个路径全部有效")
PY

git add -A "$REFS" docs/licenses
if [ "${1:-}" != "--no-commit" ]; then
  git commit -m "chore(sync): refresh web-3d-stack refs from 4 upstreams" || echo "(无变更)"
fi
echo "完成。"

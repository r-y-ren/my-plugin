#!/usr/bin/env bash
# my-plugin 新机初始化 / 迁移落地：把技能依赖的本机面一次搭好，随后全量自检。
# 幂等：重复执行安全，已就绪的项跳过。只做加法（建目录/装工具/部署脚本/拷模板/追加 ssh 配置块），
# 不删改已有内容。远端面（WSL/Windows/tailnet）与系统包无法全自动，会打印手操指引。
# 用法: scripts/bootstrap.sh [--check]    # --check 只跑自检不改本机（远端链路自愈照跑）
# 迁移全流程见 docs/MIGRATION.md。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

BIN="$HOME/.local/bin"
CFG="$HOME/.config/my-plugin"
RC_CFG="$HOME/.config/remote-compute"

# 工具 pin 版本（升级改这里 + docs/MIGRATION.md 验收版本）
DUCKDB_VER=1.5.5
AST_GREP_VER=0.45.3

PASS=0; WARN=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '[OK]   %-20s %s\n' "$1" "${2:-}"; }
warn() { WARN=$((WARN+1)); printf '[WARN] %-20s %s\n' "$1" "${2:-}"; }
fail() { FAIL=$((FAIL+1)); printf '[FAIL] %-20s %s\n' "$1" "${2:-}"; }
note() { printf '       → %s\n' "$*"; }

# ~/.ssh/config 是否已有该 Host 别名（Host 行可并列多别名，按 token 精确判）
have_host() { grep -E '^Host ' "$HOME/.ssh/config" 2>/dev/null | tr ' ' '\n' | grep -qx "$1"; }

# ── 搭建（--check 跳过）─────────────────────────────────────────
if [ "$CHECK_ONLY" -eq 0 ]; then
  echo "== 搭建本机面 =="
  mkdir -p "$BIN" "$CFG" "$RC_CFG"

  # 机器档案：事实唯一来源，不覆盖已有档案
  if [ -f "$CFG/machine.env" ]; then
    note "机器档案已存在，保留: $CFG/machine.env"
  else
    cp docs/machine.env.example "$CFG/machine.env"
    note "机器档案已生成: $CFG/machine.env（换人/换拓扑时逐字段改；同人换机照抄旧机）"
  fi

  arch=$(uname -m)
  case "$arch" in
    x86_64)  DDB_ARCH=amd64; SG_ARCH=x86_64 ;;
    aarch64|arm64) DDB_ARCH=arm64; SG_ARCH=aarch64 ;;
    *) warn "arch" "未知架构 $arch，二进制下载项跳过" ;;
  esac

  # duckdb：官方 release 单二进制
  if command -v duckdb >/dev/null 2>&1; then
    note "duckdb 已在 PATH（$(duckdb --version 2>/dev/null | head -1)），跳过"
  elif [ -n "${DDB_ARCH:-}" ]; then
    url="https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_VER}/duckdb_cli-linux-${DDB_ARCH}.zip"
    tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/duckdb.zip" "$url" && unzip -qo "$tmp/duckdb.zip" -d "$tmp"; then
      install -m 755 "$tmp/duckdb" "$BIN/duckdb"
      note "duckdb ${DUCKDB_VER} 已装入 $BIN"
    else
      warn "duckdb" "下载失败，手动装：$url 解压出的 duckdb 放进 $BIN"
    fi
    rm -rf "$tmp"
  fi

  # ast-grep：官方 release（zip 内含 ast-grep 与 sg）
  if command -v ast-grep >/dev/null 2>&1; then
    note "ast-grep 已在 PATH（$(ast-grep --version 2>/dev/null | head -1)），跳过"
  elif [ -n "${SG_ARCH:-}" ]; then
    url="https://github.com/ast-grep/ast-grep/releases/download/${AST_GREP_VER}/app-${SG_ARCH}-unknown-linux-gnu.zip"
    tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/sg.zip" "$url" && unzip -qo "$tmp/sg.zip" -d "$tmp"; then
      install -m 755 "$tmp/ast-grep" "$BIN/ast-grep"
      install -m 755 "$tmp/sg" "$BIN/sg" 2>/dev/null || true
      note "ast-grep ${AST_GREP_VER} 已装入 $BIN"
    else
      warn "ast-grep" "下载失败，手动装：$url 解压出的 ast-grep 放进 $BIN"
    fi
    rm -rf "$tmp"
  fi

  # mineru：venv 部署（python3.12 优先——torch 类依赖对新 Python 常无轮子），再上 PATH
  if command -v mineru >/dev/null 2>&1; then
    note "mineru 已在 PATH，跳过"
  elif [ -x "$HOME/.venvs/mineru/bin/mineru" ]; then
    ln -sfn "$HOME/.venvs/mineru/bin/mineru" "$BIN/mineru"
    ln -sfn "$HOME/.venvs/mineru/bin/mineru-models-download" "$BIN/mineru-models-download" 2>/dev/null || true
    note "mineru 复用现有 venv ~/.venvs/mineru，已上 PATH"
  else
    vpy=$(command -v python3.12 || command -v python3 || true)
    if [ -z "$vpy" ]; then
      warn "mineru" "无 python3，先装 python3.12（MinerU 4 的已知可用档）"
    else
      note "创建 venv ~/.venvs/mineru 并安装 mineru（torch 依赖大，可能要几分钟到几十分钟）…"
      "$vpy" -m venv "$HOME/.venvs/mineru"
      if "$HOME/.venvs/mineru/bin/pip" install -q -U 'mineru>=4'; then
        ln -sfn "$HOME/.venvs/mineru/bin/mineru" "$BIN/mineru"
        ln -sfn "$HOME/.venvs/mineru/bin/mineru-models-download" "$BIN/mineru-models-download" 2>/dev/null || true
        note "mineru 已装（$("$BIN/mineru" --version 2>/dev/null | head -1)）；模型首跑下载，国内源：mineru-models-download -s modelscope"
      else
        warn "mineru" "pip 安装失败，手动：$vpy -m venv ~/.venvs/mineru && ~/.venvs/mineru/bin/pip install -U 'mineru>=4'"
      fi
    fi
  fi

  # trafilatura：优先复用现有 venv（本机在 ~/.venvs/autoc），否则独立 venv
  if command -v trafilatura >/dev/null 2>&1; then
    note "trafilatura 已在 PATH，跳过"
  elif [ -x "$HOME/.venvs/autoc/bin/trafilatura" ]; then
    ln -sfn "$HOME/.venvs/autoc/bin/trafilatura" "$BIN/trafilatura"
    note "trafilatura 复用现有 venv ~/.venvs/autoc，已上 PATH"
  else
    vpy=$(command -v python3 || true)
    if [ -z "$vpy" ]; then
      warn "trafilatura" "无 python3，先装 python3"
    else
      "$vpy" -m venv "$HOME/.venvs/trafilatura"
      if "$HOME/.venvs/trafilatura/bin/pip" install -q -U trafilatura; then
        ln -sfn "$HOME/.venvs/trafilatura/bin/trafilatura" "$BIN/trafilatura"
        note "trafilatura 已装（独立 venv ~/.venvs/trafilatura）"
      else
        warn "trafilatura" "pip 安装失败，手动：$vpy -m venv ~/.venvs/trafilatura && ~/.venvs/trafilatura/bin/pip install -U trafilatura"
      fi
    fi
  fi

  # 系统包：只能检测，缺失给指引（发行版包名各异）
  for spec in "bwrap:bubblewrap" "soffice:libreoffice" "tesseract:tesseract(+tesseract-data-chi_sim/eng)"; do
    cmd=${spec%%:*}; pkg=${spec#*:}
    command -v "$cmd" >/dev/null 2>&1 || note "缺系统包 $cmd —— 用包管理器装 $pkg（bwrap=沙箱、soffice=Office 后备链、tesseract=OCR 降级）"
  done

  # 部署 helper 脚本（权威源在 skills/*/scripts/，这里即"部署副本"同步动作）
  install -m 700 skills/remote-compute/scripts/wsl-sudo "$BIN/wsl-sudo"
  install -m 755 skills/remote-compute/scripts/wsl-link-check "$BIN/wsl-link-check"
  install -m 755 skills/mineru/scripts/to-markdown.sh "$BIN/mineru-to-markdown"
  note "helper 已同步: $BIN/wsl-sudo（700） $BIN/wsl-link-check $BIN/mineru-to-markdown（755）"

  # remote-compute 本地面：凭据模板（不覆盖已有）+ ssh 配置块（只补缺的 Host）
  if [ -f "$RC_CFG/env" ]; then
    note "凭据文件已存在，保留: $RC_CFG/env"
  else
    install -m 600 skills/remote-compute/scripts/env.template "$RC_CFG/env"
    note "凭据模板已拷: $RC_CFG/env —— 打开填 FW_PASS（wsl-sudo 用）/ WIN_PASS（备援），别留 <…> 占位符"
  fi

  if [ -f "$CFG/machine.env" ]; then
    set -a; . "$CFG/machine.env"; set +a
  fi
  ssh_cfg="$HOME/.ssh/config"
  block=""
  have_host win || block="$block
Host win
    HostName ${REMOTE_TAILNET:-<REMOTE_TAILNET>}
    User ${SSH_WIN_USER:-<SSH_WIN_USER>}
    ServerAliveInterval 15
    ServerAliveCountMax 4
    TCPKeepAlive yes"
  have_host wsl || block="$block
Host wsl
    HostName ${REMOTE_TAILNET:-<REMOTE_TAILNET>}
    Port ${SSH_WSL_PORT:-2222}
    User ${SSH_WSL_USER:-<SSH_WSL_USER>}
    ServerAliveInterval 15
    ServerAliveCountMax 4
    TCPKeepAlive yes"
  if [ -n "$block" ]; then
    mkdir -p "$HOME/.ssh" && touch "$ssh_cfg" && chmod 600 "$ssh_cfg"
    printf '\n# >>> my-plugin bootstrap（值来自机器档案；改档案后手工同步本块）>>>%s\n# <<< my-plugin bootstrap <<<\n' "$block" >> "$ssh_cfg"
    note "ssh config 已补 win/wsl Host 块: $ssh_cfg"
  else
    note "ssh config 的 win/wsl Host 已在，跳过"
  fi
  echo
fi

# ── 自检（--check 只跑这段）──────────────────────────────────────
echo "== 自检 =="

case ":$PATH:" in
  *":$BIN:"*) ok "PATH" "$BIN 在 PATH" ;;
  *) fail "PATH" "$BIN 不在 PATH —— 把 export PATH=\"\$HOME/.local/bin:\$PATH\" 写进 shell profile" ;;
esac

if [ -f "$CFG/machine.env" ]; then
  if . "$CFG/machine.env" 2>/dev/null; then
    ok "machine.env" "已就绪（${LOCAL_NICK:-未命名}）"
  else
    fail "machine.env" "存在但无法 source: $CFG/machine.env"
  fi
else
  fail "machine.env" "缺失 —— 跑 scripts/bootstrap.sh 生成，或从 docs/machine.env.example 拷"
fi

if [ -f "$RC_CFG/env" ]; then
  if grep -q "'<" "$RC_CFG/env" 2>/dev/null; then
    warn "remote 凭据" "$RC_CFG/env 还有 <…> 占位符 —— wsl-sudo 会拒跑"
  else
    ok "remote 凭据" "$RC_CFG/env"
  fi
else
  warn "remote 凭据" "缺失（用不到 remote-compute 可忽略）"
fi

# 命令可用性
for cmd in ast-grep duckdb trafilatura mineru bwrap soffice tesseract wsl-sudo mineru-to-markdown; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "cmd: $cmd" "$(command -v "$cmd")"
  else
    case "$cmd" in
      soffice|tesseract) warn "cmd: $cmd" "缺失（可选：Office 后备链/OCR 降级）" ;;
      *) fail "cmd: $cmd" "缺失 —— 跑 scripts/bootstrap.sh 装" ;;
    esac
  fi
done

# 功能探针（与各技能"自检"节同源）
probe() {  # $1=名 $2=期望描述 $3...=命令
  local name=$1 want=$2; shift 2
  local out msg
  if out=$("$@" 2>&1); then
    msg=$(printf '%s' "$out" | head -1 | cut -c1-40)
    ok "$name" "${msg:-探针通过}"
  else
    fail "$name" "探针失败（期望$want）: $(printf '%s' "$out" | head -1 | cut -c1-60)"
  fi
}

if command -v ast-grep >/dev/null 2>&1; then
  probe "ast-grep 探针" "输出匹配行" bash -c \
    "printf 'class A extends B {}\n' > /tmp/sg_check.js && ast-grep -p 'class \$N extends \$B' -l javascript /tmp/sg_check.js | grep -q 'class A'"
fi
if command -v duckdb >/dev/null 2>&1; then
  probe "duckdb 探针" "x=2/y=1" bash -c \
    "printf 'a,b\nx,1\nx,2\ny,3\n' > /tmp/ddb_check.csv && duckdb -csv -c \"SELECT a, count(*) FROM '/tmp/ddb_check.csv' GROUP BY 1 ORDER BY 2 DESC\" | head -2 | grep -q 'x,2'"
fi
if command -v bwrap >/dev/null 2>&1; then
  probe "bwrap 探针" "RO_OK/TMP_OK/NET_OK" bash -c \
    "bwrap --ro-bind / / --dev /dev --proc /proc --bind /tmp /tmp --unshare-net sh -c '(touch /__probe 2>/dev/null && echo LEAK) || echo RO_OK; touch /tmp/__p && echo TMP_OK; (curl -m3 -s https://example.com >/dev/null && echo NET_LEAK) || echo NET_OK' | grep -q RO_OK && echo RO_OK/TMP_OK/NET_OK"
fi
if command -v trafilatura >/dev/null 2>&1; then
  # 同 venv python 由 CLI 实际位置（readlink 解开 ~/.local/bin 符号链接）推导
  probe "trafilatura 探针" "非空正文" bash -c \
    "TRA=\$(readlink -f \"\$(command -v trafilatura)\"); printf '<html><body><article><h1>Probe Title</h1><p>This is the probe body sentence one. It carries enough words that the extractor will not treat the document as a short fragment. Body text continues with a second sentence for safety.</p></article></body></html>' | \"\$(dirname \"\$TRA\")/python\" -c \"import sys,trafilatura;print(trafilatura.extract(sys.stdin.read(),output_format='markdown'))\" | grep -q 'probe body'"
fi
if command -v mineru >/dev/null 2>&1; then
  probe "mineru 探针" "输出版本号" mineru --version
fi

# remote-compute 链路：先 win 后 wsl；wsl 不通但 win 通 → 经 win 自动修复（与 SKILL.md「自检」同序同 SOP）
if have_host wsl && [ -x "$BIN/wsl-sudo" ]; then
  ok "remote 配置" "Host wsl + wsl-sudo 就绪"
else
  warn "remote 配置" "缺 Host wsl 或 wsl-sudo（用不到 remote-compute 可忽略）"
fi
if command -v ssh >/dev/null 2>&1 && have_host win && have_host wsl; then
  DISTRO="${REMOTE_WSL_DISTRO:-Ubuntu}"
  ssh_try() { ssh -o BatchMode=yes -o ConnectTimeout=8 "$@"; }
  if ! ssh_try win 'echo ok' >/dev/null 2>&1; then
    warn "ssh win/wsl 链路" "win 不通 = 算力机睡眠/关机或链路断（叫人开盖/核 hosts 条目/查 tailscaled）——无修复通道，wsl 跳过"
  else
    ok "ssh win 链路" "ok"
    # wsl-hold 持有器存在性（零客户端实例约 15~20 分钟即被拆的根治件，见 SKILL「断线根因表」）
    if ssh_try win 'schtasks /Query /TN wsl-hold' >/dev/null 2>&1; then
      ok "wsl-hold 持有器" "计划任务在（5min 心跳）"
    else
      warn "wsl-hold 持有器" "缺持有器任务——实例会周期性被拆；按 remote-compute SKILL.md「重建」第 3 步建"
    fi
    repaired=""
    if ssh_try wsl 'echo ok' >/dev/null 2>&1; then
      ok "ssh wsl 链路" "ok"
    else
      # 先鉴别再动手（2222 瞬断会自愈，勿直接重启）；恢复动作自动执行、勿问用户
      if ssh_try win "wsl -d $DISTRO --list --running" 2>/dev/null | tr -d '\0\r' | grep -qi "$DISTRO"; then
        note "WSL 实例在跑但 2222 不通 = 路径抖动（会自愈），等 30s 重试"
        sleep 30
        ssh_try wsl 'echo ok' >/dev/null 2>&1 && repaired="抖动自愈"
      else
        note "WSL 实例没在跑（注销带走/崩溃），经 win 拉起 $DISTRO"
        ssh_try win "wsl -d $DISTRO --exec /bin/true" >/dev/null 2>&1 || true
        sleep 3
        ssh_try wsl 'echo ok' >/dev/null 2>&1 && repaired="实例拉起后通"
      fi
      if [ -z "$repaired" ]; then
        note "仍不通 = WSL 内 sshd 异常，经 win 重启 sshd 后重试"
        ssh_try win "wsl -d $DISTRO -u root systemctl restart ssh" >/dev/null 2>&1 || true
        sleep 3
        ssh_try wsl 'echo ok' >/dev/null 2>&1 && repaired="sshd 重启后通"
      fi
      if [ -n "$repaired" ]; then
        ok "ssh wsl 链路" "win 侧修复：$repaired"
      else
        warn "ssh wsl 链路" "win 通但修不通——按 remote-compute SKILL.md「自检」第 1/3 步人工介入"
      fi
    fi
  fi
fi

echo
echo "汇总: $PASS ok / $WARN warn / $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1

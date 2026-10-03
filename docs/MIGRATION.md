# 迁移手册（换机 / 换环境）

技能原先把"本机实况"（工具路径、venv 位置、ssh 主机、IP、GPU）直接写进 SKILL.md，换机即失效。现在拆成两层，**技能只写流程，机器状态全在机器面**：

| 层 | 内容 | 谁保证成立 |
|---|---|---|
| **约定路径** | `~/.local/bin/*`（工具与 helper）、`~/.venvs/*`（venv）、`~/.config/my-plugin/`（机器档案）、`~/.config/remote-compute/`（凭据）、ssh 别名 `win`/`wsl` | `scripts/bootstrap.sh` 在任何机器重建，路径本身跨机不变 |
| **机器档案** | 这台机器/这套远端是谁：主机昵称、tailnet 地址、账户、GPU、组网前提 | `~/.config/my-plugin/machine.env`（从 `docs/machine.env.example` 生成）——事实唯一来源 |

技能里的命令模板（`ssh wsl …`、`mineru-to-markdown …`）因此在任何机器原样可跑；具体身份值（哪个 IP、哪个用户）读机器档案。

## 两种模式

- **同人换机**（换轻薄本，远端算力机不变）：旧机 `~/.config/my-plugin/machine.env` 照抄到新机即可，远端身份一个字不用改。
- **换人 / 换拓扑**：`docs/machine.env.example` 逐字段改（里面保留着首发环境实况值作示例），并按 remote-compute SKILL.md「重建」重做远端面（WSL/Windows/tailnet）。

## 迁移三步

```bash
# ① 克隆并装插件（ZCode：设置 → 插件管理 → 发现 → + 添加市场，填本仓 Git URL）
git clone https://github.com/r-y-ren/my-plugin.git

# ② 一键落地 + 全量自检（幂等，重复跑安全；只做加法不删改已有内容）
cd my-plugin && scripts/bootstrap.sh

# ③ 填两个小文件（bootstrap 已生成好文件，填值即可）
$EDITOR ~/.config/my-plugin/machine.env            # 机器档案：同人换机照抄旧机；换人逐字段改
$EDITOR ~/.config/remote-compute/env               # 凭据：填 FW_PASS（wsl-sudo 用）/WIN_PASS（备援），600
```

`scripts/bootstrap.sh --check` 任何时刻只跑自检不改本机（远端链路自愈照跑）；迁移验收以它全绿（0 fail）为准。远端链路自检**先 `ssh win` 后 `ssh wsl`**，wsl 不通而 win 通时自动经 win 鉴别修复（抖动等待 / 拉起实例 / 重启 sshd，与 remote-compute SKILL.md「自检」同 SOP）；算力机关机时 WARN 不算 fail。

### bootstrap 做了什么

1. 生成机器档案 `~/.config/my-plugin/machine.env`（已存在则保留）
2. 装工具进 `~/.local/bin`：duckdb、ast-grep（官方 release 二进制）；mineru（venv `~/.venvs/mineru`，python3.12 优先，复用已有 venv）；trafilatura（优先复用 `~/.venvs/autoc`，否则独立 venv）；已在 PATH 的跳过
3. 部署 helper：`wsl-sudo`（700）、`wsl-link-check`（755）、`mineru-to-markdown`（755）——权威源在 `skills/*/scripts/`，bootstrap 即"部署副本"同步
4. 拷凭据模板 `~/.config/remote-compute/env`（600，不覆盖已有）；`~/.ssh/config` 补 `win`/`wsl` Host 块（只补缺的，值取机器档案，含保活参数）
5. 跑全量自检（PATH、命令可用性、每技能功能探针、remote 链路 win→wsl 顺序探活 + `wsl-hold` 持有器存在性）

### bootstrap 覆盖不了的（手操）

| 项 | 怎么做 |
|---|---|
| 系统包 | bwrap（沙箱）/ soffice（Office 后备链）/ tesseract+chi_sim（OCR 降级）——用发行版包管理器装，缺失自检会报 |
| MinerU 模型 | 首跑下载；国内源 `mineru-models-download -s modelscope`（HF 大文件在国内网络会卡死） |
| remote-compute 远端面 | WSL sshd（含保活 drop-in）、Windows OpenSSH、**持有器三件套**（wsl-hold 任务 / wsl-boot.bat / 电源常开）、`.wslconfig`、tailnet 入网——见 remote-compute SKILL.md「重建」第 2–4 步 |
| 宿主侧安装 | ZCode 市场添加 + 插件安装启用（见 README「安装」） |

## 逐技能验收（自检命令 → 期望）

| 技能 | 验收 | 期望 |
|---|---|---|
| 全局 | `scripts/bootstrap.sh --check` | 0 fail（远端未开机允许 1 warn） |
| `mineru` | `mineru-to-markdown 某.pdf -p '1-3'` | 同目录产出 markdown（带页码标记） |
| `duckdb` | `printf 'a,b\nx,1\nx,2\n' > /tmp/c.csv && duckdb -c "SELECT count(*) FROM '/tmp/c.csv'"` | 2 |
| `trafilatura` | `trafilatura -u 'https://en.wikipedia.org/wiki/Challenge_Cup' --markdown \| head -3` | 非空正文（离线用本地 HTML 路径测） |
| `ast-grep` | 技能「自检」节 | 输出匹配行 |
| `bwrap-run` | 技能「自检」节 | `RO_OK`/`TMP_OK`/`NET_OK` |
| `remote-compute` | 先 `ssh win 'echo win-ok'` 再 `ssh wsl 'echo ok'`（或 bootstrap --check 自动做）；分型诊断 `wsl-link-check` | `win-ok` 与 `ok`（wsl 不通时 bootstrap 会经 win 自动修复） |
| `web-3d-stack` | `ls skills/web-3d-stack/refs/` | 四上游目录齐（内容随仓走，无需迁移动作） |
| `toolbox` | 技能「自检」节 | 八技能 + 四二进制齐 |

## 维护纪律（迁移性靠这个保持）

1. **新事实进机器档案，不进 SKILL.md**。技能只写"怎么做"；"这台机器是谁"（IP/用户/GPU/昵称）一律 `machine.env`。写技能时出现"本机 `~/xxx`"字样 = 硬编码回潮，改掉。
2. **helper 脚本权威源在 `skills/*/scripts/`**，`~/.local/bin` 是部署副本——改动先改权威源，重跑 bootstrap 同步。
3. **工具一律走 PATH**（`command -v`），不在技能里写 venv 绝对路径；需要同 venv 的 python 时从 CLI 实际位置推导：`"$(dirname "$(readlink -f "$(command -v trafilatura)")")/python"`。
4. 升级 bootstrap pin 的工具版本时（`DUCKDB_VER`/`AST_GREP_VER`），同步本手册验收表。
5. 改完技能照 README「更新流程」抬双版本号，宿主里刷新更新插件（技能装在插件缓存，不 bump 宿主看不到变更）。

## 已知坑

- `~/.local/bin` 不在 PATH：自检首项会 FAIL——把 `export PATH="$HOME/.local/bin:$PATH"` 写进 shell profile。
- `trafilatura` 符号链接失效（venv 换了位置）：重跑 bootstrap，或 `ln -sfn <venv>/bin/trafilatura ~/.local/bin/trafilatura`。
- 插件缓存带版本号路径（`~/.zcode/cli/plugins/cache/my-plugin/my-plugin/<ver>/…`）：不要在文档里写死它，技能内引用一律"本技能目录相对路径"或 PATH 命令。
- ssh 别名 `win`/`wsl` 是约定名（技能命令模板靠它）：机器档案可以改 IP/用户/端口，别改别名。

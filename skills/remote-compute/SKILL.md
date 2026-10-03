---
name: remote-compute
description: 调用远端算力机的 GPU/CPU——ssh wsl=WSL2 Ubuntu 计算主入口（bash+CUDA），ssh win=Windows 管理，wsl-sudo=提权（密码自动取自凭据文件）；机器身份/IP/GPU 等事实见机器档案 ~/.config/my-plugin/machine.env。何时用：用远端算力、远程 GPU、跑训练、远程执行重任务，或出现 ssh win / ssh wsl / wsl-sudo——重计算默认远程跑，哪怕用户没点名。何时不用：组网设施项目自身管理、本机轻量任务（echo 级别不上远程）。
---

# remote-compute：调用远端算力

**首条规则：重计算任务一律 `ssh wsl` 远程跑，本机只做编排。** 算力在远端算力机上发生（机型/GPU 见机器档案）；只有 Windows 侧管理才碰 `ssh win`。

## 入口与命令模板

| 命令 | 进哪里 | 用途 |
|---|---|---|
| `ssh wsl '命令'` | 算力机 WSL2 Ubuntu | **计算主入口**：bash+CUDA，stdout 回本地 |
| `ssh wsl` | 同上 | 交互会话 |
| `ssh win '命令'` | 算力机 Windows | 管理/看 Windows 侧，cmd.exe 执行 |
| `wsl-sudo '命令'` | WSL 提权 | 密码自动取自凭据文件 |

```bash
ssh wsl 'python ~/train.py'                            # 远程跑计算
ssh wsl 'nohup python ~/train.py > ~/log.txt 2>&1 &'   # 长任务必须分离（nohup/setsid）
scp 模型.zip wsl:~/                                     # 传文件；WSL 里有 rsync 可增量
wsl-sudo 'systemctl restart ssh'                       # 提权（命令内勿用单引号）
ssh win 'wsl -d Ubuntu --exec /bin/true'               # WSL 掉了自动拉起（注销会带走实例）
ssh wsl '/usr/lib/wsl/lib/nvidia-smi -L'               # GPU 现场确认（nvidia-smi 不在 PATH）
```

## 自检（用即核验，链路死活当场暴露；顺序 = 先 win 后 wsl，wsl 不通经 win 修复）

```bash
grep -q '^Host wsl' ~/.ssh/config && test -x ~/.local/bin/wsl-sudo && echo cfg-ok
ssh -o BatchMode=yes -o ConnectTimeout=8 win 'echo win-ok'   # ① 先 win
ssh -o BatchMode=yes -o ConnectTimeout=8 wsl 'echo ok'       # ② 再 wsl
```

（命令里 `Ubuntu` = 机器档案 `REMOTE_WSL_DISTRO`。）期望：`cfg-ok` / `win-ok` / `ok` 三行。缺 `cfg-ok` = 本机配置丢，按"重建"节恢复。**恢复动作自动执行、勿问用户**，按序三条路径：

1. `win-ok` 在、`ok` 不在 → **先鉴别再动手**（mirrored/tailscale 路径偶发瞬断时 VM 活着但 2222 连不上，会自愈；勿直接重启）：
   - `ssh win 'wsl -d Ubuntu --list --running'` 在跑 = 路径抖动 → 等 30–60s 以 `ssh -o ConnectTimeout=30 wsl 'echo ok'` 重试，通常自愈
   - 没跑 = 实例退出（注销过/崩溃）→ `ssh win 'wsl -d Ubuntu --exec /bin/true'` 拉起，3 秒后重试（sshd 随 systemd 自起）
   - `wsl --list` 的 Stopped 读数会骗人，存活以 uptime 连续性 + Windows 本机 2222 端口实测为准
2. `win-ok` 不在 = 算力机睡眠/关机（叫人开盖；常开算力建议 `powercfg /change standby-timeout-ac 0`）或 tailnet 断（按"网络前提"核 hosts 的 board 条目、查 tailscaled）
3. 仍不通 = WSL 内 sshd 异常 → `ssh win 'wsl -d Ubuntu -u root systemctl restart ssh'` 后重试

仓库根 `scripts/bootstrap.sh --check` 走同一套 win→wsl 顺序与自动修复（迁移验收用）；分型诊断用 `wsl-link-check`。

重型任务起跑前先探活：`ssh -o ConnectTimeout=30 wsl 'echo ready'`。

## 坑（实测 2026-10-03）

- **不写端口走 22=Windows 侧，WSL 在 2222**（账户/端口值见机器档案）——`ssh <用户>@<IP>` 这类裸拼必错，一律用 `win`/`wsl` 别名
- `nvidia-smi` 不在 WSL 的 PATH：一律 `/usr/lib/wsl/lib/nvidia-smi`
- Windows 侧命令由 cmd.exe 执行：路径写 Windows 格式（`C:\...`）
- ssh 断开会话可能带走子进程：长任务 nohup/setsid 分离
- 注销（锁屏无碍）会带走 WSL 实例：`ssh wsl` 失败先按"自检"拉起恢复，勿直接报错
- WSL 空闲自灭（实测 2026-10-03）：零客户端实例被定时回收、sshd 随之消失——`vmIdleTimeout=3600000` **挡不住这条回收路径**（实测带它实例照样 15~20 分钟被拆）；根治 = 持有器（见「断线根因表」），`vmIdleTimeout` 仅兜底。副作用 = 末次使用后 vmmem 驻留，长期不用可 `ssh win 'wsl --shutdown'` 回收
- mirrored/tailscale 路径偶发 2222 瞬断（VM 活着但连不上，会自愈）：失败先按"自检"鉴别，勿重启、勿定性为掉线
- WSL sshd 固定 2222：mirrored 网络会与 Windows sshd 抢 22；`/run/sshd` 由 tmpfiles 持久化，缺目录 sshd 起不来

## 断线根因表（2026-10-03 实测定案，五种形态五套根治）

| 断线形态 | 根因 | 已部署的根治 |
|---|---|---|
| 离开十几分钟回来实例没了（boot 只活 15~20 分钟，最短 16 秒） | **零客户端实例被 WSL 定时回收**：`wsl --exec …` 瞬时命令拉起后无客户端驻留，`vmIdleTimeout` 挡不住 | **持有器**：计划任务 `wsl-hold`——5 分钟心跳 + `tail -f /dev/null` 常驻客户端 + IgnoreNew 防堆积 + 无执行时限；实例永不空闲 |
| 长会话僵死 / 中途掉线 | 双端无保活，路径抖动时连接悬死 | WSL 内 sshd `ClientAliveInterval 30×6`；本地 win/wsl Host `ServerAliveInterval 15×4 + TCPKeepAlive` |
| 深度睡眠后全断（临终日志"Clock change detected"每 34s 刷屏 = 宿主在睡） | 算力机睡眠策略 | 交流电源 standby/hibernate 超时归零（`powercfg /change …-timeout-ac 0`）；常开算力别改回去 |
| 2222 瞬断但 VM 活着（`--list --running` 显示在跑） | mirrored/tailscale 路径抖动，会自愈 | 「自检」第 1 步鉴别 SOP：在跑→等 30~60s 重试；勿直接重启 |
| 注销带走实例 | VM 随用户会话生命周期 | `wsl-boot.bat`（启动文件夹）登录即拉持有器；锁屏无碍 |

排障一把梭：**`wsl-link-check`**（自动分型 + 采样成功率；实例没跑会当场经 win 拉起）。持有器状态查 `ssh win 'schtasks /Query /TN wsl-hold'`（应为 Running）。

## 网络前提与维护点

当前部署拓扑（组网事实见机器档案 `NET_*` 字段）：本机 → **自持 headscale 组网**（控制面在板 `board:8080`，断外网可用；P2P 12ms，板上 DERP 兜底）→ 算力机。唯一维护点：**板校园 IP 漂移时同步各端 hosts 的 `board` 条目**（login-server 只写 `https://board:8080`，永不写 IP）。链路体检：

```bash
. ~/.config/my-plugin/machine.env
tailscale --socket=/run/ts-kvmhub/tailscaled.sock ping -c 2 "$REMOTE_TAILNET"
```

期望 pong（direct ~12ms 或 DERP）。全挂先拿板当前校园 IP 对 hosts。

## 环境事实（换环境只改机器档案）

事实不在本文件——**机器档案 `~/.config/my-plugin/machine.env` 是唯一来源**（bootstrap 从 `docs/machine.env.example` 生成；同人换机照抄旧机档案即可）。字段：本机/算力机昵称与描述、`REMOTE_TAILNET`（win/wsl 共用地址）、`SSH_WIN_USER`/`SSH_WSL_USER`/`SSH_WSL_PORT`、`REMOTE_GPU`、`REMOTE_WSL_DISTRO`、`NET_*` 组网项。命令模板里的 `win`/`wsl` 是约定别名（bootstrap 生成的 ssh 配置块保证成立），具体身份值一律读档案。凭据另存 `~/.config/remote-compute/env`（600；FW_PASS=wsl-sudo 用、WIN_PASS=ssh win 备援），与档案分离（事实可进 git 讨论，凭据永不）。

## 重建（新机器一把过）

脚本权威源在本技能 `scripts/`（`~/.local/bin/wsl-sudo`、`wsl-link-check` 是部署副本，改动先改权威源再跑 bootstrap 同步）：

1. 本机：跑仓库根 `scripts/bootstrap.sh`——部署 `wsl-sudo`（700）/`wsl-link-check`（755）、拷凭据模板 `env.template` → `~/.config/remote-compute/env`（600）填 FW_PASS/WIN_PASS、`~/.ssh/config` 补 `win`/`wsl` Host 块（值取机器档案，含保活参数）
2. WSL 侧：sshd_config `Port 2222` + `systemctl disable --now ssh.socket` + `systemctl enable ssh`；`echo 'd /run/sshd 0755 root root' | sudo tee /etc/tmpfiles.d/sshd.conf`；sshd 保活 drop-in `/etc/ssh/sshd_config.d/90-keepalive.conf` 写 `ClientAliveInterval 30`/`ClientAliveCountMax 6`/`TCPKeepAlive yes`，`sshd -t && systemctl reload ssh`
3. Windows 侧——**持有器三件套（缺一必断线）**：
   - 计划任务 `wsl-hold`（根治件）：`schtasks /Create /TN wsl-hold /SC MINUTE /MO 5 /TR "wsl.exe -d Ubuntu --exec /usr/bin/tail -f /dev/null" /F` + `schtasks /Run /TN wsl-hold`；PowerShell 再设 `ExecutionTimeLimit='PT0S'`、`MultipleInstances=2`（IgnoreNew 防持有器堆积）。效果 = 5 分钟心跳自愈 + 常驻客户端（实例永不空闲）
   - 启动文件夹 `wsl-boot.bat`（登录即持有）：内容 `start /min "" wsl.exe -d Ubuntu --exec /usr/bin/tail -f /dev/null`（发行版名用档案 `REMOTE_WSL_DISTRO`）
   - 电源常开：`powercfg /change standby-timeout-ac 0` + `powercfg /change hibernate-timeout-ac 0`
   - 其余照旧：OpenSSH Server（Automatic）；公钥入 `C:\ProgramData\ssh\administrators_authorized_keys`（icacls 收权）；`.wslconfig` 的 `[wsl2]` 写 `networkingMode=mirrored` + `vmIdleTimeout=3600000`（仅兜底），改完 `wsl --shutdown` 生效
4. 入网：各端 hosts 加 `board` 条目；`tailscale up --login-server=<档案 NET_LOGIN_SERVER> --accept-dns=false`（先信 CA，见组网设施仓 INSTALL.md）

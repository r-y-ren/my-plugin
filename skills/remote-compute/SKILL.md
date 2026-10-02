---
name: remote-compute
description: 调用性能本算力——轻薄本经 KVM-Hub 自持 headscale 用 first 的 GPU/CPU：ssh wsl=WSL2 Ubuntu 计算主入口（bash+CUDA），ssh win=Windows 管理，wsl-sudo=提权（密码自动取自凭据文件）。何时用：用性能本算力、远程 GPU、跑训练、远程执行重任务，或出现 ssh win / ssh wsl / wsl-sudo——重计算默认远程跑，哪怕用户没点名。何时不用：KVM-Hub 项目自身管理、本机轻量任务（echo 级别不上远程）。
---

# remote-compute：调用性能本算力

**首条规则：重计算任务一律 `ssh wsl` 远程跑，本机只做编排。** 算力在性能本 first 的 RTX 4070 上发生；只有 Windows 侧管理才碰 `ssh win`。

## 入口与命令模板

| 命令 | 进哪里 | 用途 |
|---|---|---|
| `ssh wsl '命令'` | first 的 WSL2 Ubuntu（renyxin） | **计算主入口**：bash+CUDA，stdout 回本地 |
| `ssh wsl` | 同上 | 交互会话 |
| `ssh win '命令'` | first 的 Windows（OSS） | 管理/看 Windows 侧，cmd.exe 执行 |
| `wsl-sudo '命令'` | WSL 提权 | 密码自动取自凭据文件 |

```bash
ssh wsl 'python ~/train.py'                            # 远程跑计算
ssh wsl 'nohup python ~/train.py > ~/log.txt 2>&1 &'   # 长任务必须分离（nohup/setsid）
scp 模型.zip wsl:~/                                     # 传文件；WSL 里有 rsync 可增量
wsl-sudo 'systemctl restart ssh'                       # 提权（命令内勿用单引号）
ssh win 'wsl -d Ubuntu --exec /bin/true'               # WSL 掉了自动拉起（注销会带走实例）
ssh wsl '/usr/lib/wsl/lib/nvidia-smi -L'               # GPU 现场确认（nvidia-smi 不在 PATH）
```

## 自检（用即核验，链路死活当场暴露）

```bash
grep -q '^Host wsl' ~/.ssh/config && test -x ~/.local/bin/wsl-sudo && echo cfg-ok; ssh -o BatchMode=yes -o ConnectTimeout=8 wsl 'echo ok'
```

期望：`cfg-ok` 与 `ok` 两行。缺 `cfg-ok` = 本机配置丢，按"重建"节恢复。缺 `ok` 按序自查，**恢复动作自动执行、勿问用户**：

1. `ssh win 'echo x'` 通、`ssh wsl` 不通 = WSL 实例退出（注销过/崩溃）→ `ssh win 'wsl -d Ubuntu --exec /bin/true'` 拉起，3 秒后重试（WSL 侧 sshd 随 systemd 自起，通常一次即恢复）
2. `ssh win` 也不通 = first 睡眠/关机（叫人开盖；常开算力建议 `powercfg /change standby-timeout-ac 0`）或 tailnet 断（按"网络前提"核 hosts 的 board 条目、查 tailscaled）
3. 仍不通 = WSL 内 sshd 异常 → `ssh win 'wsl -d Ubuntu -u root systemctl restart ssh'` 后重试

## 坑（实测 2026-10-03）

- **不写端口走 22=Windows（用户 OSS），WSL 在 2222（renyxin）**——`ssh renyxin@100.100.0.6` 这类裸拼必错，一律用 `win`/`wsl` 别名
- `nvidia-smi` 不在 WSL 的 PATH：一律 `/usr/lib/wsl/lib/nvidia-smi`
- Windows 侧命令由 cmd.exe 执行：路径写 Windows 格式（`C:\...`）
- ssh 断开会话可能带走子进程：长任务 nohup/setsid 分离
- 注销（锁屏无碍）会带走 WSL 实例：`ssh wsl` 失败先按"自检"拉起恢复，勿直接报错
- WSL sshd 固定 2222：mirrored 网络会与 Windows sshd 抢 22；`/run/sshd` 由 tmpfiles 持久化，缺目录 sshd 起不来

## 网络前提与维护点

链路：rypc（本机）→ **KVM-Hub 自持 headscale**（控制面在板 `board:8080`，断外网可用；P2P 12ms，板上 DERP 兜底）→ first-prod。唯一维护点：**板校园 IP 漂移时同步各端 hosts 的 `board` 条目**（login-server 只写 `https://board:8080`，永不写 IP）。链路体检：

```bash
tailscale --socket=/run/ts-kvmhub/tailscaled.sock ping -c 2 100.100.0.6
```

期望 pong（direct ~12ms 或 DERP）。全挂先拿板当前校园 IP 对 hosts。

## 环境事实（换环境只改这节）

| 事实 | 值 |
|---|---|
| 性能本 | first = Windows + WSL2 Ubuntu 24.04 |
| tailnet 地址 | win/wsl 同为 `100.100.0.6`（first-prod） |
| 入口 | `win`=:22/OSS；`wsl`=:2222/renyxin |
| 算力 | RTX 4070 Laptop，WSL2 CUDA（/dev/dxg + libcuda） |
| 凭据文件 | `~/.config/remote-compute/env`（600，wsl-sudo 读 FW_PASS） |
| 本机身份 | rypc = 轻薄本（rypc-prod=100.100.0.5） |

## 重建（新机器一把过）

脚本权威源在本技能 `scripts/`（`~/.local/bin/wsl-sudo` 是部署副本，改动先改权威源再同步）：

1. 本机：`scripts/wsl-sudo` → `~/.local/bin/`（700）；`scripts/env.template` 填值存 `~/.config/remote-compute/env`（600）；`~/.ssh/config` 加 `win`/`wsl` 两个 Host（值见环境事实）
2. WSL 侧：sshd_config `Port 2222` + `systemctl disable --now ssh.socket` + `systemctl enable ssh`；`echo 'd /run/sshd 0755 root root' | sudo tee /etc/tmpfiles.d/sshd.conf`
3. Windows 侧：OpenSSH Server（Automatic）；启动文件夹放 `wsl-boot.bat`（内容 `start /min "" wsl.exe -d Ubuntu --exec /bin/true`）；公钥入 `C:\ProgramData\ssh\administrators_authorized_keys`（icacls 收权）
4. 入网：各端 hosts 加 `board` 条目；`tailscale up --login-server=https://board:8080 --accept-dns=false`（先信 CA，见 KVM 仓 INSTALL.md）

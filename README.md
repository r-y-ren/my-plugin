# my-plugin

个人本机工具技能集（ZCode / Claude Code 兼容插件）。以插件形式分发，绕开宿主对用户级 `~/.zcode/skills` 的暴露限制——插件层技能在每个会话都会进入智能体的可用列表。

## 技能清单（8 个）

| 技能 | 用途 |
|---|---|
| `toolbox` | 工具路由向导：不确定该用哪个本地工具时查表；已明确时直调目标技能 |
| `mineru` | PDF/扫描件/Office/图片等 22 类文档转 Markdown（本地引擎，文档不出本机） |
| `duckdb` | CSV/Parquet/JSON 大表 SQL 聚合：count/group/join/抽样，毫秒级 |
| `trafilatura` | 静态网页正文降噪抽取（URL 直抓 / 本地 HTML 两条路径） |
| `ast-grep` | 按语法结构（AST）检索与批量改写代码，30+ 语言 |
| `bwrap-run` | bubblewrap 沙箱隔离执行不可信第三方代码（根只读、默认断网） |
| `remote-compute` | 调用远端算力机：ssh wsl 跑计算（bash+CUDA）、ssh win 管 Windows、wsl-sudo 提权、wsl-link-check 断线分型（持有器自愈链路，根因表见技能内） |
| `web-3d-stack` | Web 3D/图形前端全家桶单技能路由：Three.js 基础/游戏、WebGPU·TSL、shadcn/ui（聚合四上游 22 份参考文档，子内容不独立暴露） |

技能只写流程，机器状态分两层托管（详见 `docs/MIGRATION.md`）：**约定路径**（`~/.local/bin/*`、`~/.venvs/*` 等，`scripts/bootstrap.sh` 在任何机器重建）+ **机器档案**（`~/.config/my-plugin/machine.env`，主机/IP/账户/GPU 等事实唯一来源）。换机不再需要逐技能改内容。

## 迁移 / 换机

```bash
git clone https://github.com/r-y-ren/my-plugin.git
cd my-plugin && scripts/bootstrap.sh     # 装工具、部署 helper、生成机器档案，随后全量自检
$EDITOR ~/.config/my-plugin/machine.env  # 同人换机照抄旧机档案；换人/换拓扑逐字段改
$EDITOR ~/.config/remote-compute/env     # remote-compute 凭据（FW_PASS/WIN_PASS）
```

自检 0 fail 即迁移完成；`scripts/bootstrap.sh --check` 可随时只验不动。系统包、MinerU 模型、remote-compute 远端面等手操项见 `docs/MIGRATION.md`。

## web-3d-stack 上游同步

`scripts/sync-web-3d-stack.sh` 直连四上游（cloudai-x/threejs-skills、majidmanzarpour/threejs-game-skills、dgreenheck/webgpu-claude-skill、shadcn-ui/ui 的 `skills/`），重建 `skills/web-3d-stack/refs/` 并刷新 `docs/licenses/`，随后自动校验路由 SKILL.md 分派表引用的路径仍全部存在（上游改目录名会报错拦截），自动提交。上游新增/更名技能时，同步后手动更新 web-3d-stack 路由表与 toolbox 对应行。

## 安装（ZCode 桌面版）

**设置 → 插件管理 → 发现 → `+` 添加市场**，市场地址填 Git URL：

```
https://github.com/r-y-ren/my-plugin.git
```

然后在市场列表中安装 `my-plugin` 并启用。安装后技能以 `my-plugin:toolbox`（可简写 `toolbox`）等名称暴露。

## 更新流程

1. 修改 `skills/` 下的 SKILL.md（维护纪律见 `docs/MIGRATION.md`——新事实进机器档案，不进技能）
2. 同步抬版本号：`.zcode-plugin/plugin.json` 与 `marketplace.json` 两处 `version`
3. 提交推送
4. 宿主里刷新市场并更新插件

## 仓库结构

```
marketplace.json           # 市场清单（本仓库既是市场也是插件，source: "./"）
.zcode-plugin/plugin.json  # 插件清单（无 skills 字段 → 默认读 skills/ 目录）
skills/<技能名>/SKILL.md
skills/<技能名>/scripts/     # 可选：helper 脚本权威源（部署到 ~/.local/bin 由 bootstrap 同步）
scripts/bootstrap.sh       # 新机初始化/迁移落地 + 全量自检（幂等）
scripts/sync-web-3d-stack.sh # web-3d-stack 四上游直连同步
docs/MIGRATION.md          # 迁移手册（两层模型、三步流程、逐技能验收）
docs/machine.env.example   # 机器档案模板（事实唯一来源的字段定义）
docs/licenses/             # web-3d-stack 上游 MIT 许可文本
```

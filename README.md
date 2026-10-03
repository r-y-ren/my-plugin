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
| `remote-compute` | 调用性能本算力：ssh wsl 跑计算（bash+CUDA）、ssh win 管 Windows、wsl-sudo 提权 |
| `web-3d-stack` | Web 3D/图形前端全家桶单技能路由：Three.js 基础/游戏、WebGPU·TSL、shadcn/ui（聚合四上游 22 份参考文档，子内容不独立暴露） |

技能内容为本机定制：工具路径（`~/.local/bin/*`）、venv 位置（`~/.venvs/mineru`、`~/.venvs/autoc`）均为个人机器实况，换机需自行调整；`web-3d-stack` 为上游聚合内容，无本机定制。

## web-3d-stack 上游同步

两级同步链：四上游 → 聚合仓 [r-y-ren/web-3d-stack](https://github.com/r-y-ren/web-3d-stack)（跑其 `scripts/sync-upstream.sh` 并推送）→ 本仓（跑 `scripts/sync-web-3d-stack.sh`，拉聚合仓覆盖 `skills/web-3d-stack/` 与 `docs/licenses/`，自动提交）。同步后核对 toolbox 路由表与 web-3d-stack 分派描述是否仍一致。

## 安装（ZCode 桌面版）

**设置 → 插件管理 → 发现 → `+` 添加市场**，市场地址填 Git URL：

```
https://github.com/r-y-ren/my-plugin.git
```

然后在市场列表中安装 `my-plugin` 并启用。安装后技能以 `my-plugin:toolbox`（可简写 `toolbox`）等名称暴露。

## 更新流程

1. 修改 `skills/` 下的 SKILL.md
2. 同步抬版本号：`.zcode-plugin/plugin.json` 与 `marketplace.json` 两处 `version`
3. 提交推送
4. 宿主里刷新市场并更新插件

## 仓库结构

```
marketplace.json          # 市场清单（本仓库既是市场也是插件，source: "./"）
.zcode-plugin/plugin.json # 插件清单（无 skills 字段 → 默认读 skills/ 目录）
skills/<技能名>/SKILL.md
skills/<技能名>/scripts/    # 可选：helper 脚本（remote-compute 的 wsl-sudo 等）
scripts/sync-web-3d-stack.sh # web-3d-stack 从聚合仓同步
docs/licenses/             # web-3d-stack 上游 MIT 许可文本
```

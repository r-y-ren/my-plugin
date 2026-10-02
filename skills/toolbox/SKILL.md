---
name: toolbox
description: 本机工具技能路由向导——一表回答"这个任务该用哪个本地工具"：文档→mineru、大表→duckdb、网页正文→trafilatura、代码结构→ast-grep、不可信执行→bwrap-run、远程算力→remote-compute。可显式 /toolbox 调用；已明确该用哪个技能时直调该技能，勿经此向导二跳。
---

# toolbox：本机工具技能路由

**首条规则：具体技能已命中就直调它，不要经本向导二跳。** 本向导只在"不确定该用什么本地工具"或"点了工具却不在"时有用。

## 路由表（册面=2026-10-03）

| 任务语义 | 技能 | 何时用 / 排除 |
|---|---|---|
| 文档→Markdown（PDF/扫描件/Office/图片，含表格版面公式） | `mineru` | 排除：只要纯文本快检 → `pdftotext`（无技能，Bash 直呼） |
| 大表统计（CSV/Parquet/JSON 数千行+） | `duckdb` | 排除：几十行小表直接读文件 |
| 网页正文降噪（静态页 → markdown） | `trafilatura` | 排除：JS 渲染页 → 浏览器工具 |
| 代码结构检索/批量改写（按语法形状） | `ast-grep` | 排除：纯文本搜索 → rg |
| 执行不可信第三方代码（参赛开源仓库/外来包运行段） | `bwrap-run` | 排除：自家工程日常编译测试不套 |
| 远程算力（性能本 GPU/CPU：跑训练/重任务） | `remote-compute` | 排除：KVM-Hub 自身管理、本机轻任务 |

## 自检（用即核验，陈旧当场暴露）

```bash
ls ~/.zcode/skills/ | grep -vi 'eide\|fn-' ; command -v ast-grep duckdb trafilatura bwrap
```

期望：技能目录 = 本表六行技能（五工具 + remote-compute）+ 本技能自身（toolbox）；四个二进制都在。fn-ladder 系列（`fn-*` 与 `FN-LADDER.md`，插件或符号链接安装）不属工具路由范围，已随 EIDE 一并排除。任何不一致 = 本向导过期——以 `ls` 实况为准先修册面再继续用。

## 维护纪律

1. **新增/移除全局技能必须同步本表与自检期望**。本向导只索引技能层：裸 CLI 想入册，先为它建技能。
2. 二进制缺失时按对应技能"自检"节重建（如 trafilatura 符号链接）。
3. autoC 仓库内的增改另有 ENVIRONMENT 全局技能清单行联动登记。

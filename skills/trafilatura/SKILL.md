---
name: trafilatura
description: 静态网页正文降噪抽取——去掉导航/广告/页脚，毫秒级产出干净 markdown/txt；URL 直抓与本地 HTML 文件两条路径。何时用：提取网页正文、通知/章程页面降噪、抓内容存档；JS 渲染页（SPA）不适用，换浏览器工具。
---

# trafilatura：静态页正文降噪抽取

**功能**：静态网页 → 干净 markdown 正文；导航/广告/页脚全剥离，支持 URL 直抓与本地 HTML 文件两条路径。

本机经符号链接 `~/.local/bin/trafilatura` → `~/.venvs/autoc/bin/trafilatura`（2.2.0，autoc venv）。venv 升级自动跟随；若 `command -v trafilatura` 失效 = venv 迁移，用 `ln -sfn ~/.venvs/autoc/bin/trafilatura ~/.local/bin/trafilatura` 重建。

## 两条路径（均实测 2026-09-20）

**URL 直抓**：

```bash
trafilatura -u '<URL>' --markdown            # 正文 markdown
trafilatura -u '<URL>' --markdown --links    # 保留链接
```

**本地 HTML 文件**——注意 CLI 的 `-i` 吃的是"URL 清单文件"**不是** HTML 文档（整段 HTML 会被当 URL 丢弃），本地文件走 venv python：

```bash
~/.venvs/autoc/bin/python -c "import sys,trafilatura;print(trafilatura.extract(sys.stdin.read(),output_format='markdown'))" < page.html
```

## 边界

- **JS 渲染页（SPA）抽不到**：正文不在源码里，换浏览器工具
- **autoC 仓库内**工作时服从其 kb 流程：快照存档与 `.extract.md` sidecar 优先、引用纪律照旧——本技能面向仓库外通用抓取
- 无 title/正文过短的碎片文档会保守保留噪声或返回空；真实页面降噪显著

## 自检

```bash
trafilatura -u 'https://en.wikipedia.org/wiki/Challenge_Cup' --markdown | head -3
```

期望：非空正文（离线时改用上面"本地 HTML 文件"路径测）。

---
name: mineru
description: 本地通用文档解析——PDF/扫描件/图片/Office/HTML/EPUB 等 22 类输入转 Markdown（表格/版面/公式/OCR 全保留），解析一次后可按页查阅与跨文档检索，全程不出本机。何时用：用户提到任何文档文件，或要 读/转/提取/整理/引用 一个文档——哪怕没说"转换"或"MinerU"。
---

# MinerU：通用文档解析（转换 + 查阅）

本机 MinerU 4（`~/.venvs/mineru`，standard 档 VLM 引擎，纯 CPU 约 0.5~1s/页）。**一切解析都在本地完成，文档不出本机**。

## 支持的输入（22 类，原生直通）

pdf｜图片（jpg/png/webp/tiff 等）｜docx·doc｜pptx·ppt｜xlsx·xls｜odt·odp·ods｜rtf｜html｜csv·tsv｜epub｜ofd｜text·markdown·rst·tex·asciidoc

- `-p` 页码选择**仅 PDF 有效**；其余类型整文档解析
- Office 类原生解析失败时 wrapper 自动走 soffice→PDF 后备链
- 产出：带页码标记（`<!-- page N of M -->`）的 markdown，表格还原为 markdown 表，扫描件走内置 OCR（中英文）

## 快速用法：wrapper 脚本（转换首选）

```bash
~/.zcode/skills/mineru/scripts/to-markdown.sh 报告.pdf                  # → 同目录 报告.md
~/.zcode/skills/mineru/scripts/to-markdown.sh 章程.docx -o /tmp/zc.md   # Office/HTML/EPUB 原生直通
~/.zcode/skills/mineru/scripts/to-markdown.sh 大书.pdf -p '1-5'         # 先看目录/结构
~/.zcode/skills/mineru/scripts/to-markdown.sh 扫描件.jpg                 # 图片直接 OCR
```

## 查阅循环：解析一次，之后按需读（核心增值）

parse 会把文档自动入库缓存（同文件再 parse 秒回）。**已解析过的文档不要重复转换全文再整读**——用定位符按页读、按词搜：

```bash
M=~/.venvs/mineru/bin/mineru
$M list docs                                  # 拿文档 ID（含页数与自动提取的标题）
$M read doc:<id>/tier:standard/page:4 --context 2          # 读第 4 页±2 页
$M read doc:<id>/tier:standard/page:4 --format image -o /tmp/p4.png   # 直接吐页图
$M search 评审要点 --type pdf                  # 跨已解析文档检索关键词
```

- 定位符 `doc:<id>/tier:<档>/page:<N>`：**tier 段必填、顺序固定**（standard/basic 各有缓存时可任选档位读）；`$M read --help` 看全量
- `read --limit <字符数>`：控制读取量（默认 30000 软上限），省 token

**长文档套路**（几百页大 PDF）：先 `-p '1-5'` 看目录与结构 → 决定全量（`-p all`）或只解析关心的页段 → 用查阅循环读细节，不要一次把全文灌进上下文。

## 何时用什么

- 版面复杂 / 表格 / 扫描件 / 双栏 / 公式 → **MinerU**（本技能）
- 只要纯文本、文档简单且很大（几百页+）→ `pdftotext <pdf> -` 更快
- MinerU 不可用（venv 缺失等）→ 降级 `pdftotext`；扫描件降级 tesseract（本机 `~/.tessdata` 有 chi_sim+eng 用户包）

## 直接 CLI（高级场景）

```bash
M=~/.venvs/mineru/bin/mineru
$M server status || $M server start     # parse 不会自动拉服务，先确保服务在跑
$M parse <pdf> -p all -o <out.md>       # 解析——默认只前 10 页，务必 -p all 或指定页
$M parse <pdf> -p r3-r1 --force         # 倒数页码 / 强制重解析忽略缓存
```

`scan`/`watch`（目录批量摄入与监视）存在但**不建议用 watch**：常驻服务语义，且 blobs 缓存随服务 cwd 落盘；批量转换直接对 wrapper 循环调用。

## 纪律与坑

- **`blobs/` 内容缓存写在 MinerU 服务进程的 cwd**（不是 parse 客户端的 cwd）：从项目目录拉起/重启服务会持续污染该目录——拉服务与 parse 都先 `cd /tmp`；wrapper 已内置规避。
- **`--remote`（mineru.net 云解析）默认禁用**：本地引擎已够快；未公开/隐私文档不得上第三方云。
- 档位切换（basic=onnx 小模型 / standard=+VLM，当前 standard）须 `mineru config set parse_server.local.managed_tier <档>` + `mineru server restart`；`parse --tier` 不能跨服务已加载的档位，一般直接省略。
- 首次解析有模型加载等待（约 10~30s），之后同文件命中缓存秒回；重装环境时模型下载用 modelscope 源（`mineru-models-download -s modelscope`），HuggingFace 源的大文件在本机网络会卡死。

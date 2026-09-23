#!/usr/bin/env bash
# 通用文档 → Markdown 一步转换（MinerU 4 本地引擎）
# 原生支持 22 类输入：pdf / 图片 / docx / odt / xls / pptx / xlsx / odp / ods /
# rtf / doc / ppt / html / csv / tsv / epub / ofd / text / markdown / rst / tex / asciidoc
# Office 类原生解析失败时自动经 soffice 转 PDF 重试（后备链）
# 封装：/tmp 工作目录（blobs/ 写在服务进程 cwd，必须先 cd 再拉服务）/ 服务预检 /
#       PDF 默认全页解析 / 冷启动引擎加载退避重试
# 用法: to-markdown.sh <输入文件> [-o 输出.md] [-p '1-5,8'|all]（-p 仅 PDF 有效）
set -euo pipefail

MINERU="$HOME/.venvs/mineru/bin/mineru"
input="" out="" pages="all"
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="${2:?}"; shift 2 ;;
    -p) pages="${2:?}"; shift 2 ;;
    -h|--help) echo "用法: $0 <输入文档> [-o 输出.md] [-p '1-5,8'|all]（-p 仅 PDF）"; exit 0 ;;
    *) input="$1"; shift ;;
  esac
done
if [ -z "$input" ]; then
  echo "用法: $0 <输入文档> [-o 输出.md] [-p '1-5,8'|all]（-p 仅 PDF）" >&2; exit 2
fi
if [ ! -x "$MINERU" ]; then
  echo "错误: MinerU 未安装（$MINERU 不存在）；降级方案见 SKILL.md「何时用什么」" >&2; exit 3
fi
input_abs=$(realpath "$input") || exit 2
if [ ! -f "$input_abs" ]; then echo "错误: 文件不存在: $input" >&2; exit 2; fi
if [ -n "$out" ]; then out_abs=$(realpath -m "$out"); else out_abs="${input_abs%.*}.md"; fi

# 1) 先进 /tmp 工作目录，再做一切 MinerU 操作——blobs/ 内容缓存写在（服务进程的）
#    cwd，服务若从项目目录拉起会持续污染该目录，绝不能让服务继承工程目录 cwd
work=$(mktemp -d "${TMPDIR:-/tmp}/mineru-skill.XXXXXX")
cd "$work"

# 2) 服务预检（parse 不会自动拉起本地服务）
"$MINERU" server status >/dev/null 2>&1 || "$MINERU" server start >/dev/null 2>&1

# 3) 解析入口：-p 仅 PDF 支持（其余类型整文档解析），冷启动引擎加载 10~30s 时
#    对"服务未就绪/无引擎"类错误退避重试；成功打印结果并返回 0
parse_once() {
  if [[ "$1" == *.pdf ]]; then
    "$MINERU" parse "$1" -p "$pages" -o "$out_abs" --wait 900 2>&1
  else
    if [ "$pages" != "all" ] && [ "$1" == "$input_abs" ]; then
      echo "提示: -p 仅 PDF 有效，非 PDF 输入整文档解析" >&2
    fi
    "$MINERU" parse "$1" -o "$out_abs" --wait 900 2>&1
  fi
}
try_parse() {  # $1=待解析文件；成功 echo 结果返回 0
  local result attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if result=$(parse_once "$1"); then echo "$result"; return 0; fi
    case "$result" in
      *"not ready"*|*"未运行"*|*"not running"*|*"No basic"*|*"engine available"*|*"不可用"*)
        sleep 3
        "$MINERU" server start >/dev/null 2>&1 || true
        ;;
      *) LAST_ERROR="${result#错误: }"; return 1 ;;
    esac
  done
  LAST_ERROR="本地解析服务重试 10 次仍未就绪"
  return 1
}

LAST_ERROR=""
if try_parse "$input_abs"; then exit 0; fi

# 4) 后备链：Office 类原生失败 → soffice 无头转 PDF 再试一次
case "${input_abs,,}" in
  *.doc|*.docx|*.ppt|*.pptx|*.xls|*.xlsx|*.odt|*.odp|*.ods|*.rtf)
    if command -v soffice >/dev/null 2>&1; then
      echo "提示: 原生解析失败，尝试 soffice 转 PDF 后备链" >&2
      soffice --headless --convert-to pdf --outdir "$work" "$input_abs" >/dev/null 2>&1 || true
      pdf=$(find "$work" -maxdepth 1 -name '*.pdf' -print -quit)
      if [ -n "$pdf" ] && try_parse "$pdf"; then exit 0; fi
    fi
    ;;
esac
echo "错误: $LAST_ERROR" >&2; exit 6

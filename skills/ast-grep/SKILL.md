---
name: ast-grep
description: 按语法结构（AST）检索与批量改写代码——找"所有带返回注解的函数""继承 X 的类"这类代码形状而非文本匹配，Python/JS/TS/Java/Go/Rust 等 30+ 语言可用。何时用：精准/结构化代码检索、AST 模式匹配、按语法形状批量改写，或 rg 分不清注释/字符串与真代码时。
---

# ast-grep：AST 结构化代码检索与改写

**功能**：按语法形状搜代码（"所有带返回注解的函数"这类结构问题）与批量改写（预览 diff 后落盘）。与 rg 的分工——rg 找文本，本工具找结构。

工具走 PATH 直呼 `ast-grep`（单二进制，bootstrap 部署到 `~/.local/bin/ast-grep`；缺失跑仓库根 `scripts/bootstrap.sh`）。语法树匹配，是 rg 的结构化补充——rg 找"文本"，ast-grep 找"代码形状"。

## 何时用

- 找"所有带返回注解的函数""所有继承自 X 的类""所有两参相同的调用"这类**形状**问题
- 批量改写调用点/签名（rewrite），正则改跨行结构不可靠时
- 只找文本用 rg；"注释里的函数"和真函数分不清时用 ast-grep

## 命令模板

```bash
# 检索：模式 + 语言 + 目标路径（文件或目录）
ast-grep -p 'def $F($$$) -> $R: $$$' -l python src/        # 所有带返回注解的函数
ast-grep -p 'class $N extends $B' -l javascript src/      # 类继承结构
ast-grep -p '$F($A, $A)' -l python file.py                # 两参相同的调用（bug 味）

# 改写：-r 先预览 diff，确认后加 -U 落盘
ast-grep -p 'print($$$A)' -r 'log.info($$$A)' -l python src/    # 预览
ast-grep -p 'print($$$A)' -r 'log.info($$$A)' -l python -U src/ # 实改
```

元变量：`$F` 单节点｜`$A` 单个（一个参数/一个表达式）｜`$$$A` 多个（任意参数列表/语句块）。

## 坑（实测 2026-09-20）

- **模式必须贴合源码结构**：目标写 `def f(a: str) -> str:` 而模式不带注解/返回类型 → **零匹配且不报错**。先抓一个真实样本，照着它的结构写模式。
- **替换文本里 `$F_xxx` 不是"$F 加后缀"**：ast-grep 把它解析为一个整名的未定义元变量，**静默展开为空**，产出 `def (a):` 这种坏代码（实测 `-U` 真的会改坏文件）。元变量只能原样直传（`$F`→`$F`）；拼接前后缀要走 YAML 规则的 transform，速查层不碰。
- 匹配输出默认带整个匹配块，管道 `| head` 控量。

## 自检

```bash
printf 'class A extends B {}\n' > /tmp/sg_check.js && ast-grep -p 'class $N extends $B' -l javascript /tmp/sg_check.js
```

期望：输出该行匹配。

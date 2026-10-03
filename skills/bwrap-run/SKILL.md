---
name: bwrap-run
description: bubblewrap 沙箱隔离执行不可信第三方代码——根只读、仅工作目录与 /tmp 可写、默认断网；依赖装沙箱外、执行在沙箱内。适用：跑参赛开源仓库、外来 pip/npm 包运行段、未知爬虫脚本；日常自家工程编译测试不套用。
---

# bwrap-run：不可信代码隔离执行

bwrap（系统包，PATH 直呼；实测 0.13）。用途单一：**执行段的隔离**——根只读、仅工作目录与 /tmp 可写、默认断网。防的是"跑起来才知道它会干什么"的第三方代码；误写工程面另有 D14 守卫 + git 审计兜底，不靠本技能。缺失用发行版包管理器装 bubblewrap。

## 命令模板（默认：断网）

```bash
bwrap --ro-bind / / --dev /dev --proc /proc \
      --bind /tmp /tmp --bind <工作目录绝对路径> <工作目录绝对路径> \
      --unshare-net \
      <命令...>
```

例（跑参赛开源仓库）：

```bash
bwrap --ro-bind / / --dev /dev --proc /proc --bind /tmp /tmp \
      --bind /tmp/foreign-repo /tmp/foreign-repo --unshare-net \
      python /tmp/foreign-repo/run.py
```

## 铁则

- **依赖安装在 wrapper 外，执行在 wrapper 内**：pip/npm install 需要网络与写 venv——沙箱外装好后执行段再进沙箱（沙箱内 venv 只读可见，import 正常）。
- 需要联网的被测行为（真实网络回归等）→ 去掉 `--unshare-net` 前先自问：这步是不是非跑不可、能否 mock。
- 工作目录一律**绝对路径** bind；bind 集合之外的一切路径只读。
- 退出码即被隔离命令的退出码；怀疑沙箱本身问题时跑下面自检。

## 何时不用

- 日常编译/测试自家工程代码——harness 权限面 + 守卫 + git 审计已覆盖，套 wrapper 只会破坏路径解析与排障。
- 只读分析（读代码、grep、ast-grep）不需要沙箱：不可信的是"执行"，不是"阅读"。

## 自检（一条命令验证三隔离）

```bash
bwrap --ro-bind / / --dev /dev --proc /proc --bind /tmp /tmp --unshare-net sh -c \
  '(touch /__probe 2>/dev/null && echo ROOT_WRITE_LEAK) || echo RO_OK; touch /tmp/__p && echo TMP_OK; (curl -m3 -s https://example.com >/dev/null && echo NET_LEAK) || echo NET_OK'
```

期望输出：`RO_OK` / `TMP_OK` / `NET_OK`。

## 坑（冒烟实证 2026-09-20）

- `--ro-bind / /` 之后 `/dev` 也只读，`/dev/null` 不可写会让大量程序报"权限不够"——模板必须带 `--dev /dev --proc /proc`。
- 沙箱内 DNS 随 `--unshare-net` 一并消失，报错形态是解析失败而非超时，属预期。

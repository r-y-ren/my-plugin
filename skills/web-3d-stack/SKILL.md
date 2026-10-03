---
name: web-3d-stack
description: "现代 Web 3D/图形前端全家桶路由：Three.js（场景/相机/几何/材质/纹理/光照/动画/GLSL 着色器/后期/加载/交互）、Three.js 浏览器游戏整建（玩法/AAA 画质/游戏 UI/资产/音频/调试/发布）、WebGPU + TSL 节点材质/compute/WGSL、shadcn/ui 组件（init/registry/preset/聊天 UI/Radix 迁移）。凡涉及 Three.js、WebGPU、TSL、shadcn、3D 网页、网页游戏、组件库搭建的需求都用本技能；也作为上层向导技能（如工具路由/项目向导）的子技能目标，按本名路由进入。"
---

# Web 3D Stack 路由

本技能是唯一入口。四个上游技能集（共 22 份文档）收在 `refs/` 下作为内部参考资料，**它们不是独立技能**——任何场景都从本文件分派，绝不把子文档当技能调用。

## 分派表

按需求特征选一行，读对应 `SKILL.md` 并照做。路径均相对本目录。

### Three.js 基础（refs/threejs/）

| 需求 | 文档 |
|---|---|
| 场景搭建 / 相机 / 渲染器 / Object3D 层级 / 坐标系与变换 | `refs/threejs/threejs-fundamentals/SKILL.md` |
| 内置/自定义几何体 | `refs/threejs/threejs-geometry/SKILL.md` |
| 材质（MeshStandard/Physical/…） | `refs/threejs/threejs-materials/SKILL.md` |
| 纹理与贴图链 | `refs/threejs/threejs-textures/SKILL.md` |
| 灯光与阴影 | `refs/threejs/threejs-lighting/SKILL.md` |
| 关键帧/骨骼/补间动画 | `refs/threejs/threejs-animation/SKILL.md` |
| GLSL ShaderMaterial / 后期链前的着色逻辑 | `refs/threejs/threejs-shaders/SKILL.md` |
| 后期处理（EffectComposer/bloom/…） | `refs/threejs/threejs-postprocessing/SKILL.md` |
| 模型与资源加载（GLTF/DRACO/…） | `refs/threejs/threejs-loaders/SKILL.md` |
| 交互（raycast 拾取/拖拽/指针事件） | `refs/threejs/threejs-interaction/SKILL.md` |

### Three.js 游戏整建（refs/threejs-game/）

| 需求 | 文档 |
|---|---|
| **做一款完整的浏览器游戏（任意规模）** | `refs/threejs-game/threejs-game-director/SKILL.md`（入口，它会自行路由下列兄弟文档） |
| 玩法循环 / 游戏机制 | `refs/threejs-game/threejs-gameplay-systems/SKILL.md` |
| AAA 级画质 | `refs/threejs-game/threejs-aaa-graphics-builder/SKILL.md` |
| 游戏 UI/HUD | `refs/threejs-game/threejs-game-ui-designer/SKILL.md` |
| 3D 资产生成/绑定/转换 | `refs/threejs-game/threejs-3d-generator/SKILL.md` |
| 图像资产生成 | `refs/threejs-game/threejs-image-generator/SKILL.md` |
| 音频/音效 | `refs/threejs-game/threejs-audio-generator/SKILL.md` |
| 调试与性能剖析 | `refs/threejs-game/threejs-debug-profiler/SKILL.md` |
| 测试 / 冒烟 / 发布验收 | `refs/threejs-game/threejs-qa-release/SKILL.md` |

### WebGPU / TSL（refs/webgpu-tsl/）

| 需求 | 文档 |
|---|---|
| WebGPURenderer / TSL 节点材质 / compute shader / WGSL 集成 / WebGPU 后期 | `refs/webgpu-tsl/webgpu-threejs-tsl/SKILL.md` |

着色路线分界：项目用 `WebGLRenderer` → GLSL（走 threejs-shaders）；用 `WebGPURenderer` → TSL（走本表）。

### shadcn/ui（refs/shadcn/）

| 需求 | 文档 |
|---|---|
| shadcn 组件增删查改 / init / registry / preset / 聊天界面 / 项目上下文 | `refs/shadcn/shadcn/SKILL.md` |
| Radix UI → Base UI 迁移 | `refs/shadcn/migrate-radix-to-base/SKILL.md` |

## 阅读协议

1. 先读分派表命中的 `SKILL.md` 再动手写代码。
2. 子文档引用的相对路径（`scripts/`、`references/`、`templates/`、`examples/`、`docs/`）就在该文档同目录下，按需读取。
3. **指路改写**：子文档里出现的"技能 / skill / `$xxx` 调用"一律理解为"去读 `refs/**/<同名目录>/SKILL.md`"，不是调用独立技能。若指名的目录不在本 refs 中（如上游互指外部工具），按普通文档线索对待，找不到就跳过并继续当前文档的主线。
4. 子文档自身的 frontmatter（含 `user-invocable`、`allowed-tools` 等）是上游遗留元数据，对本技能无效，忽略即可。
5. 混合需求（常见：3D 主轴 + shadcn 界面壳）：先走 3D 主轴文档完成可运行核心，再按 `refs/shadcn/shadcn/SKILL.md` 配 UI 层；两层不要交叉读。

## 上游来源与许可

| refs 段 | 上游 | 许可 |
|---|---|---|
| `refs/threejs` | cloudai-x/threejs-skills | MIT（README 声明） |
| `refs/threejs-game` | majidmanzarpour/threejs-game-skills | MIT |
| `refs/webgpu-tsl` | dgreenheck/webgpu-claude-skill | MIT（plugin.json 声明，仓库无 LICENSE 文件） |
| `refs/shadcn` | shadcn-ui/ui `skills/` | MIT |

同步上游：仓库根 `scripts/sync-upstream.sh`。

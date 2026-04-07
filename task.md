# 优化 publish-skill 任务文档

## 目标
当用户说“项目远程发布skill”时，自动开启 `ALLOW_EXTERNAL_SKILL_DIR=1` 环境并发布当前项目中的 skill。

## 完成情况
- [x] 更新 `skills/publish-skill/SKILL.md`，增加触发词与特殊场景说明。
- [x] 更新 `skills/publish-skill/agents/openai.yaml`，明确 AI 在该场景下的处理逻辑（设置环境变量、查找本地路径）。

## 详情
- **触发词**: `项目远程发布skill`
- **逻辑变化**: 
    - 识别到该触发词时，AI 应当在当前操作系统的 Workspace（即项目目录）下的 `skills/` 目录寻找指定的 skill。
    - 在运行 `publish-skill.sh` 时，自动前缀环境变量 `ALLOW_EXTERNAL_SKILL_DIR=1`。

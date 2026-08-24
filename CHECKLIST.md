# AI Nexus 项目 · 手工验证与动手清单（CHECKLIST）

> 用途：你去网吧 / 用手机时，照着一步步做，做一项勾一项。所有需要"真机/电脑/你的账号"的事都在这里；写代码、编译、发布全由我（手机端 Trae）负责，不占用你时间。

---

## 一、环境：你只需要准备这几样（其余我云端自动装）

- [ ] 手机上安装 **Termux**（Android，给 App 提供 Linux/CLI 能力）
- [ ] 网吧电脑安装 **Node.js ≥ 18**（用于跑 DeepSeek Harness，可选等我有把握再装）
- [ ] 准备一个 **GitHub 账号**（已有 `wgr070402`）——用于后面下载 APK / 看进度

> 不需要你手动装的：Flutter、JDK、Android SDK、NDK、Gradle —— 编译时云端 CI 自动按代码里的版本配置安装。

---

## 二、Phase 1 验证（已完成阶段，先确认真机能用）

- [ ] 在手机浏览器打开 Releases，下载最新 APK
- [ ] 安装 APK（需要允许"安装未知来源"）
- [ ] 打开 App，确认：首页 / 底部 5 个导航（首页、会话、Agent、项目、设置）都能切换
- [ ] 记录遇到的任何报错或卡顿，反馈给我

---

## 三、待开发阶段（我写代码，你真机验证每一阶段）

### Phase 2 · 单聊
- [ ] （我实现：Provider、API Key 安全存储、流式输出、Markdown、历史记录）
- [ ] 你：真机发一条消息，看是否流式打字机输出、能换行显示 Markdown
- [ ] 你：重启 App，看聊天历史是否还在

### Phase 3 · Agent
- [ ] （我实现：创建/编辑/复制/删除/导入导出 Agent，身份+提示词+模型+技能+权限）
- [ ] 你：创建一个 Agent，配置名称/角色/提示词，保存后再编辑
- [ ] 你：用该 Agent 发起一次对话

### Phase 4 · 群聊（Multi-Agent）
- [ ] （我实现：Agent 调度、角色分工、任务管理）
- [ ] 你：建一个群，加 2 个 Agent，发一条任务，观察它们分工/回复

### Phase 5 · Terminal / Termux Bridge
- [ ] （我实现：Terminal UI、会话、命令历史、Termux 桥）
- [ ] 你：手机上装好 Termux，在 App 里跑一条命令（如 `echo hi`），确认输出能显示
- [ ] 你：若命令执行失败，把报错反馈给我（涉及真机通信，我只能做到这一步）

### Phase 6 · Workflow
- [ ] （我实现：节点式编辑器、执行引擎、Agent 调度）
- [ ] 你：拖一个简单流程（开始→Agent→结束）跑通

### Phase 7 · DeepSeek Harness Adapter
- [ ] （我实现：独立 Adapter，通过 ACP/API 连接）
- [ ] 你：按我给的步骤在电脑装 `npx @deepseek-ai/dsh web`，把连不通的报错反馈给我

### Phase 8 · Codex Adapter
- [ ] （我实现：Adapter；Android 若无法运行则如实说明，预留远程方案）
- [ ] 你：验证 App 内 Codex 入口是否如实提示"不可用/需要远程"，不伪造

### Phase 9 · 项目管理
- [ ] （我实现：文件管理、Git、活动日志）
- [ ] 你：在项目内新建/打开一个项目，看文件列表和日志

### Phase 10 · 整体测试 / 优化 / APK 打包
- [ ] （我实现：性能、UI、权限测试；APK 由云端 CI 打包）
- [ ] 你：完整过一遍所有页面，反馈最影响体验的问题

---

## 四、安全与合规（全程要求）

- [ ] **不要在任何代码里写死 API Key**——所有 Key 由你在 App 设置里填，用安全存储
- [ ] 遇到 Termux/Harness/Codex 在 Android 上跑不了时，**如实告诉我**，我会说明原因并给替代方案，绝不伪造
- [ ] 每个阶段我完成后都要：静态检查 ✅ → 单元测试 ✅ → 编译 APK ✅ → 确认不破坏上一阶段

---

## 五、当前进度速览

| 阶段 | 状态 |
|------|------|
| Phase 1 项目初始化 | ✅ 完成（APK 已出） |
| Phase 2 单聊 | ⏳ 待开始 |
| Phase 3 Agent | ⏳ 未做 |
| Phase 4 群聊 | ⏳ 未做 |
| Phase 5 Terminal/Termux | ⏳ 未做 |
| Phase 6 Workflow | ⏳ 未做 |
| Phase 7 Harness | ⏳ 未做 |
| Phase 8 Codex | ⏳ 未做 |
| Phase 9 项目管理 | ⏳ 未做 |
| Phase 10 优化打包 | ⏳ 未做 |
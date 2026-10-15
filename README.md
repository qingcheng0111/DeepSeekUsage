# DeepSeekUsage 🐳

[![License](https://img.shields.io/github/license/923106608-lang/DeepSeekUsage)](LICENSE)
[![Release](https://img.shields.io/github/v/release/923106608-lang/DeepSeekUsage)](https://github.com/923106608-lang/DeepSeekUsage/releases)
![macOS](https://img.shields.io/badge/macOS-14%2B-blue)

[English](README.en.md) · 简体中文

DeepSeekUsage 是一个轻量、注重隐私的 **macOS 菜单栏应用**：在菜单栏与弹出面板中实时查看 DeepSeek 开放平台账户的余额、消费与 Token 用量。数据只在本机与 DeepSeek 官方接口之间流转，不发送给任何第三方。

本项目基于开源项目 [DeepSeekMeter](https://github.com/CWNU-Open-Source-Community/DeepSeekMeter)（作者 pppolf，MIT 协议）深度定制：全中文界面、新增「时间维度」切换、指标口径与平台对齐、趋势图增强等（见下方「与上游差异」）。

当前版本 **v0.5.0**（macOS）。

## 功能特性

- **菜单栏常驻**：菜单栏图标旁直接显示账户余额（`¥xx.xx`）；余额低于阈值时自动变色（< ¥1 红色 / < ¥10 橙色）。点击图标弹出面板。
- **时间维度切换**：面板顶部「时间维度」按钮，可选 **今天 / 昨天 / 近7天 / 近30天 / 本月 / 上月**（默认近 30 天）；选项以覆盖式小弹窗展开，不改变主面板尺寸。
- **余额**：总余额 + 赠送余额 / 充值余额拆分，显示钱包币种。
- **用量指标**：
  - 今日费用 / 今日请求 / 今日 Token
  - 维度费用 / 维度请求 / 维度 Token（随所选时间维度动态变化）
  - Token 为**总 token 口径（输入 + 输出）**，与平台统计一致
- **按模型拆分**：显示各模型（如 flash / v4-pro）的调用次数与费用；费用支持同币种多 API Key 自动累加。
- **Token 用量趋势**：按天柱状图，可在 输出 / 缓存命中 / 总量（默认）之间切换；30 天视图横轴逐日标注；鼠标悬浮柱子显示「日期 · 当日 token 用量」。
- **点击面板外自动收起**：点击其他任意位置或切换应用，面板自动收回（已并入应用源码，无任何外部注入）。
- **官方登录**：面板内一键打开 DeepSeek 官方登录页，登录态仅保存在本机。
- **刷新间隔** 15 秒 – 10 分钟可选，支持手动刷新；支持开机自启。

## 截图

| 主面板（已登录 · 演示数据） | 时间维度选择器（覆盖式小弹窗） |
| :---: | :---: |
| ![主面板](images/panel-main.png) | ![时间维度选择器](images/dimension-picker.png) |
| **Token 趋势**：30 天全标注 + 柱状悬浮提示 | **未登录态**：一键登录引导 |
| ![趋势与悬浮提示](images/trend-hover.png) | ![未登录](images/login-prompt.png) |

> 截图为演示 / 测试数据，正式运行显示你自己的真实用量。

## 环境要求

| 用途 | 要求 |
| :--- | :--- |
| 直接使用 | macOS 14 或更高；Apple Silicon 或 Intel |
| 源码构建 | Xcode Command Line Tools（含 Swift 6 工具链；macOS target 不需要完整 Xcode） |

## 安装与使用

### 方式一：DMG 安装（推荐）

1. 在 [Releases](https://github.com/923106608-lang/DeepSeekUsage/releases) 下载 `DeepSeekUsage-0.5.0-macOS.dmg`；
2. 打开 DMG，把 `DeepSeekUsage` 拖入「应用程序」；
3. 首次启动被 Gatekeeper 拦截时，**右键 →「打开」**即可（当前为 ad-hoc 签名，未做 Developer ID 公证）；
4. 点击菜单栏图标 → 面板内「一键登录」→ 在 DeepSeek 官方页面登录；返回面板后数据自动加载。

### 方式二：源码构建并安装

```bash
bash Scripts/install.sh
```

等价于 `swift build -c release` + 组装 `.app` + 拷入 `/Applications` + 启动。

使用说明：

- 「时间维度」：点按钮弹出小选项窗 → 点任一选项立即生效并收起；
- 点击面板外任意位置或切换应用 → 面板自动收回；再次点击菜单栏图标可重新打开；
- 菜单栏找不到图标：多为 macOS 菜单栏空间不足被系统折叠（刘海机型常见），请在系统设置中精简菜单栏图标；
- 与上游 DeepSeekMeter 及任何旧版**互相独立**（Bundle ID 为 `com.deepseek.usage`），登录态与设置不互通，可并存使用。

## 从源码构建

```bash
# 构建（release）
swift build -c release

# 自测（无需 Xcode / XCTest，含模型逻辑用例）
bash Scripts/run-tests.sh

# 组装 .app（自动生成图标、ad-hoc 签名）
bash Scripts/build-app.sh release

# 直接运行组装的产物
open build/DeepSeekUsage.app
```

> 若钥匙串中存在 Developer ID Application 证书，`build-app.sh` 会自动改用它签名；再运行 `Scripts/notarize.sh` 可完成公证。

## 隐私与数据

- 请求由应用直接发往 DeepSeek 私有平台接口（`platform.deepseek.com`）：`/auth-api/v0/users/current`、`/api/v0/users/get_user_summary`、`/api/v0/usage/by_api_key/amount`、`/api/v0/usage/by_api_key/cost`。这些不是公开 API 契约，平台侧统计可能存在延迟。
- 应用**不会**把 Token、余额、用量、遥测或分析数据发送给本项目维护者或任何第三方。
- 登录态 Token 保存在本机：`~/Library/Preferences/com.deepseek.usage.plist`（UserDefaults），不写任何云端配置。
- 请不要把真实 Token 粘贴到 Issue、日志或截图中。

## 仓库结构

```text
Sources/DeepSeekUsage/   macOS SwiftUI + AppKit 菜单栏应用（唯一构建目标）
Scripts/                 构建 / 安装 / 自测 / 图标生成 / 公证脚本
windows/assets/          应用与菜单栏图标素材（鲸鱼娘；沿用上游目录，macOS 构建脚本引用，含来源说明）
images/                  界面截图
```

## 与上游差异（相对 DeepSeekMeter v0.3.1）

| 类别 | 变化 |
| :--- | :--- |
| 命名 | 更名 DeepSeekUsage；Bundle ID 改为 `com.deepseek.usage`（与上游版本并存互不影响） |
| 新增 | 「时间维度」选择器（今天 / 昨天 / 近7天 / 近30天 / 本月 / 上月，覆盖式小弹窗） |
| 指标 | 今日 / 维度 费用·请求·Token；Token 改为总 token 口径（输入+输出，与平台一致）；费用支持同币种多 API Key 累加 |
| 趋势 | 输出 / 缓存命中 / 总量切换（默认总量）；30 天横轴逐日标注；柱子悬浮提示 |
| 交互 | 「点击面板外自动收起」并入源码（不再依赖外部注入） |
| 界面 | 全中文 |
| 范围 | 本仓库仅保留 macOS 端；上游的 Windows / iOS / Android 源码见上游仓库 |

## 版本记录

| 日期 | 版本 | 变更 |
| :--- | :--- | :--- |
| 2026-10-15 | 0.5.0-r8 | 趋势图柱子新增悬浮提示（日期 · 当日 token 用量） |
| 2026-10-15 | 0.5.0-r7 | 趋势图 30 天横轴改为逐日全标注（自适应格宽与字号） |
| 2026-10-15 | 0.5.0-r6 | 横轴日期标签修复（后被 r7 取代） |
| 2026-10-15 | 0.5.0-r5 | 数据口径修正：总 token（输入+输出）、多 API Key 同币种累加、趋势默认「总量」、维度默认「近30天」 |
| 2026-10-15 | 0.5.0-r4 | 关闭 / 重开面板时复位「时间维度」小弹窗状态 |
| 2026-10-15 | 0.5.0-r3 | 小弹窗定稿：6 项预设、覆盖式浮层、尺寸 150×172、选项文字居中 |
| 2026-10-15 | 0.5.0 | 基于上游 v0.3.1：改名、时间维度、指标改造、点击外部关闭 |

## 常见问题

- **登录态过期 / 数据不更新？** 点「重新登录」重走官方登录；或点底部「刷新」。
- **首次打开提示「无法验证开发者」？** 当前为 ad-hoc 签名：右键 →「打开」，仅需一次。
- **菜单栏没有图标？** 检查菜单栏剩余空间（刘海机型空间不足会被系统折叠）；并确认进程正在运行（活动监视器中搜索 DeepSeekUsage）。
- **开机自启开关不生效？** 可在「系统设置 → 通用 → 登录项」中核对，开关状态与该列表保持一致。
- **如何卸载？** 退出应用 → 删除 `/Applications/DeepSeekUsage.app` → 删除 `~/Library/Preferences/com.deepseek.usage.plist`；若开启过开机自启，在系统设置登录项中移除。
- **为什么只有 macOS？** 本仓库是面向 macOS 的定制分支；Windows / iOS / Android 请见上游 [DeepSeekMeter](https://github.com/CWNU-Open-Source-Community/DeepSeekMeter)。

## 致谢与许可

- 基于开源项目 [DeepSeekMeter](https://github.com/CWNU-Open-Source-Community/DeepSeekMeter)（作者 pppolf，MIT）修改。
- 图标素材来源与授权说明见 [windows/assets/ATTRIBUTION.zh-CN.md](windows/assets/ATTRIBUTION.zh-CN.md)。
- 本仓库（含全部修改）同样以 [MIT](LICENSE) 协议发布。
- 本项目为第三方非官方工具，与 DeepSeek 官方无关联。

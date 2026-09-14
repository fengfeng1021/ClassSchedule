# 课表与教室速查工具 (ClassSchedule)

一款专为大学生与在校师生打造的 iOS / iPadOS 原生课程表与教室速览 App。

遵循 **Apple Human Interface Guidelines (HIG)** 与 **Apple UI Skills (v15.3.0)** 设计规范构建，支持 iPad 宽屏全周网格与 iPhone 紧凑单手操作。

---

## 🌟 核心特色与功能

1. **核心场景解决 ——「我现在要去哪个教室？」**
   - **今日聚焦大卡片 (Hero Card)**：根据系统实时时刻自动计算。
     - **正在上课**：显示鲜明绿标与已进行时间，以超大字号醒目呈现当前教室名称（如：`教三楼 302`）。
     - **即将上课**：计算剩余倒计时（如：`还有 25 分钟`），大字号指引即将前往的教室。
     - **课程结束/无课**：优雅的空闲闲暇卡片提示。
2. **多模式周课表**
   - **按日浏览**：星期胶囊快速滑动切换，卡片化展示当天所有课程详情。
   - **全周网格 (Timetable Grid)**：横纵时间轴无缝展开，特别针对 iPad 大屏优化，纵览周一至周日全景课表。
3. **课程库管理**
   - 支持全局搜索课程名、教室、任课教师或备注。
   - 原生滑动操作（左滑快速编辑或删除课程）。
4. **原生设计美学**
   - 原生连续曲率圆角 (`RoundedRectangle(cornerRadius: 16, style: .continuous)`)。
   - 官方 SF Symbols 图标语义化映射。
   - 动态色彩系统（Indigo、Blue、Teal、Mint、Purple、Orange 等）。
   - App Group 容器架构（为第二阶段 WidgetKit 桌面小工具无缝共享课程数据做好准备）。

---

## 📱 iPad 本地运行与调试指南 (无需 Mac)

通过 **Working Copy** 与 **Swift Playgrounds** 即可实现 Windows 编写、iPad 实时同步运行：

1. **在 iPad 上安装必要软件**：
   - App Store 搜索安装 **Swift Playgrounds** (免费)。
   - App Store 搜索安装 **Working Copy** (强大的 iOS Git 客户端，免费版即可满足 Clone 与 Pull)。
2. **克隆本仓库到 iPad**：
   - 打开 Working Copy，点击右上角 `+` -> **Clone repository**。
   - 输入 GitHub 仓库地址：`https://github.com/fengfeng1021/ClassSchedule.git`。
3. **在 Swift Playgrounds 中打开并运行**：
   - 在 Working Copy 中打开该仓库，点击右上角分享图标，选择 **在 Swift Playgrounds 中打开** (或者在“文件”应用中，进入 `Working Copy` 目录长按选择用 Playgrounds 打开)。
   - 点击 Playgrounds 顶部的 **▶ 运行** 按钮，即可在 iPad 上实时预览原生渲染效果！
4. **后续更新流程**：
   - 电脑端推送代码后，在 iPad 的 Working Copy 中点击 **Pull (拉取)**，Swift Playgrounds 将秒级热重载更新！

---

## 🛠️ 项目结构

```
ClassSchedule/
├── Package.swift                    # SwiftPM App 清单 (AppleProductTypes)
├── Sources/
│   └── AppModule/
│       ├── App.swift                # App 入口 (@main)
│       ├── Models/
│       │   ├── TimeOfDay.swift      # 时间模型 (小时:分钟, 比较与格式化)
│       │   └── Course.swift         # 课程模型 (名称、教室、教师、周期、色彩)
│       ├── Services/
│       │   └── CourseStore.swift    # 状态中心 (JSON 持久化 & App Group 共享)
│       └── Views/
│           ├── MainTabView.swift    # 根导航 TabView
│           ├── TodayView.swift      # 今日聚焦 (教室 Hero Card)
│           ├── WeeklyScheduleView.swift # 周课表 (按日/网格)
│           ├── CourseListView.swift # 课程库 (搜索/管理)
│           └── CourseEditSheet.swift# 新增/编辑课程表单
└── .github/
    └── workflows/
        └── build-ios.yml            # GitHub Actions 自动化编译流水线
```

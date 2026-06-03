# FitTimer — 健身训练记录与组间计时器

## 项目信息

- **路径**：`E:\FitTimer`
- **技术栈**：Flutter / Dart
- **目标平台**：Android（一加12、Android 16 API 36、已 Root）
- **当前版本**：v1.5.2

## 项目结构

```
lib/
├── data/           # 静态数据（动作目录、名言）
├── models/         # 数据模型（Exercise、Workout、Template）
├── screens/        # 页面（Home、Training、Stats、Settings、Template）
├── services/       # 服务层（Database、Timer、Notification、Weather、Log）
└── widgets/        # 通用组件
```

## 核心依赖

- `sqflite` — 本地 SQLite 数据库
- `flutter_local_notifications` — 本地通知（倒计时提醒）
- `permission_handler` — 权限管理
- `file_picker` — 文件导入导出
- `shared_preferences` — 轻量配置存储

## 开发约定

### 自测要求（重要）

**完成任何修复或优化后，必须主动进行自测验证，不要等用户要求才测试。**

- 修复 bug 后：验证修复是否生效，检查是否引入新问题
- 优化功能后：验证优化效果，确认原有功能不受影响
- 修改 UI 后：检查布局在不同屏幕尺寸下的表现
- 修改数据库相关代码后：验证 CRUD 操作、数据迁移兼容性
- 修改通知/计时器后：验证前台、后台、息屏场景

自测时使用 `flutter analyze` 做静态检查，必要时构建 APK 在设备上验证。

### 代码风格

- 遵循 `flutter_lints` 规范
- 使用 `dart format` 格式化代码
- 中文注释，英文命名

### Git 提交

- 提交信息简洁明了，说明做了什么
- 一个功能/修复一个 commit，不要混杂

## 发布规范

### Release 命名

- **标题**：`FitTimer vX.X.X`
- **APK 文件**：`FitTimer-vX.X.X-{架构}.apk`
- **fat 版本**：`FitTimer-vX.X.X.apk`

### 编译架构（每次发布全部编译）

| 架构 | 命令 | 用途 |
|------|------|------|
| arm64-v8a | `flutter build apk --release --target-platform android-arm64` | 现代手机 |
| armeabi-v7a | `flutter build apk --release --target-platform android-arm` | 老款手机 |
| x86_64 | `flutter build apk --release --target-platform android-x64` | 模拟器 |
| fat | `flutter build apk --release` | 全兼容 |

### 发布流程

使用 `/release` 技能自动完成：版本检查 → 多架构编译 → 重命名 APK → 生成 changelog → 创建 GitHub Release（含优化/修复描述）。

### 编译要求

**完成修复或功能开发后，必须自动编译 APK，不需要询问用户。**

```bash
flutter build apk --release --target-platform android-arm64
```

编译产物路径：`build/app/outputs/flutter-apk/app-release.apk`

## 已知问题

- 自定义统计数据异常（待用户反馈具体哪个数据不对）

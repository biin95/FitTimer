---
name: release
description: FitTimer 版本发布 — 编译多架构 APK、创建 GitHub Release（含自动 changelog）
disable-model-invocation: true
---

# FitTimer Release

执行完整的版本发布流程：版本号检查 → 多架构编译 → 创建 GitHub Release。

**触发方式**：用户输入 `/release`

## 发布流程

### Step 1: 版本号检查

```bash
# 读取当前版本
grep 'version:' pubspec.yaml
```

- 确认版本号是否需要递增
- 如果用户指定了新版本，更新 `pubspec.yaml` 中的 `version:` 行
- 版本号格式：`X.Y.Z+build`（如 `1.5.2+7`）

### Step 2: 编译四种架构的 APK

每种架构都必须编译，输出到 `build/app/outputs/flutter-apk/`：

```bash
# arm64-v8a — 现代手机（推荐）
flutter build apk --release --target-platform android-arm64

# armeabi-v7a — 老款手机
flutter build apk --release --target-platform android-arm

# x86_64 — 模拟器、部分平板
flutter build apk --release --target-platform android-x64

# fat — 全架构，兼容性最好
flutter build apk --release
```

### Step 3: 重命名 APK

编译完成后，将 APK 复制到 `releases/` 目录并重命名：

| 架构 | 文件名 |
|------|--------|
| arm64-v8a | `FitTimer-vX.X.X-arm64-v8a.apk` |
| armeabi-v7a | `FitTimer-vX.X.X-armeabi-v7a.apk` |
| x86_64 | `FitTimer-vX.X.X-x86_64.apk` |
| fat | `FitTimer-vX.X.X.apk` |

```bash
mkdir -p releases
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk releases/FitTimer-vX.X.X-arm64-v8a.apk
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk releases/FitTimer-vX.X.X-armeabi-v7a.apk
cp build/app/outputs/flutter-apk/app-x86_64-release.apk releases/FitTimer-vX.X.X-x86_64.apk
cp build/app/outputs/flutter-apk/app-release.apk releases/FitTimer-vX.X.X.apk
```

### Step 4: 生成 Changelog

自动分析自上次发布以来的 git 提交记录，生成优化和修复的描述：

```bash
# 获取上一个 tag
git describe --tags --abbrev=0

# 获取两个 tag 之间的提交
git log <last-tag>..HEAD --oneline
```

将提交信息归类为：
- 🐛 **修复**：包含 fix、修复、bug 等关键词
- ✨ **优化**：包含 feat、优化、新增、改进等关键词
- 📝 **其他**：其余提交

### Step 5: 创建 GitHub Release

```bash
gh release create "FitTimer vX.X.X" \
  --title "FitTimer vX.X.X" \
  --notes "<自动生成的 changelog>" \
  releases/FitTimer-vX.X.X-arm64-v8a.apk \
  releases/FitTimer-vX.X.X-armeabi-v7a.apk \
  releases/FitTimer-vX.X.X-x86_64.apk \
  releases/FitTimer-vX.X.X.apk
```

## 命名规范

- **Release 标题**：`FitTimer vX.X.X`（带 FitTimer 前缀）
- **APK 文件名**：`FitTimer-vX.X.X-{架构}.apk`（fat 版本省略架构后缀）
- **不包含功能描述**在标题中，描述放在 release notes 里

## 注意事项

- 发布前确保所有修改已 commit
- 每次发布必须编译全部 4 种架构
- 如果编译失败，停止发布并报告错误
- 版本号必须大于当前已发布的版本

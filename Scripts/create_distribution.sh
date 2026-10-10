#!/bin/bash

echo "📦 开始创建发布包..."
echo ""

# 检查应用是否存在
if [ ! -d "ClickLoop.app" ]; then
    echo "❌ 错误：未找到 ClickLoop.app"
    echo "请先运行 ./build_app.sh 构建应用"
    exit 1
fi

# 创建分发目录
DIST_DIR="dist"
VERSION="v1.0.0"
DIST_NAME="ClickLoop-${VERSION}-arm64"

echo "🗂️  创建分发目录..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/$DIST_NAME"

# 复制应用
echo "📋 复制应用文件..."
cp -R ClickLoop.app "$DIST_DIR/$DIST_NAME/"

# 创建安装说明
echo "📝 生成安装说明..."
cat > "$DIST_DIR/$DIST_NAME/安装说明.txt" << 'EOF'
================================================================================
                          ClickLoop v1.0.0 安装指南
================================================================================

欢迎使用 ClickLoop！这是一款专为 macOS 设计的高效鼠标连点器。

📋 系统要求
--------------------------------------------------------------------------------
• macOS 13.0 (Ventura) 或更高版本
• Apple Silicon (M1/M2/M3) 芯片
• 需要授予「辅助功能」权限

📦 安装步骤
--------------------------------------------------------------------------------

步骤 1：移动应用
   将 ClickLoop.app 拖动到「应用程序」文件夹

步骤 2：首次打开（重要！）
   由于应用未经 Apple 公证，首次打开时需要：

   方法 A（推荐）：
   1. 在 Finder 中找到 ClickLoop.app
   2. 按住 Control 键点击应用图标
   3. 选择「打开」
   4. 在弹出的对话框中点击「打开」

   方法 B：
   1. 尝试双击打开应用（会被 Gatekeeper 阻止）
   2. 打开「系统设置」→「隐私与安全性」
   3. 找到 ClickLoop 的提示，点击「仍要打开」

   方法 C（命令行）：
   在终端中执行：
   xattr -cr /Applications/ClickLoop.app
   open /Applications/ClickLoop.app

步骤 3：授予辅助功能权限
   1. 应用启动后，点击菜单栏图标
   2. 尝试启用任一方案时，系统会提示授权
   3. 前往「系统设置」→「隐私与安全性」→「辅助功能」
   4. 找到 ClickLoop 并勾选启用

🎯 快速开始
--------------------------------------------------------------------------------
1. 点击菜单栏的 ClickLoop 图标，选择「显示主窗口」
2. 点击「新增」按钮创建连点方案
3. 设置点击次数、时长和快捷键
4. 启用方案后，按下快捷键即可触发连点

⚠️ 常见问题
--------------------------------------------------------------------------------

问：为什么应用无法打开？
答：这是 macOS Gatekeeper 安全机制，请按照「步骤 2」操作。

问：快捷键不响应？
答：请确保已授予「辅助功能」权限，并重启应用。

问：能在 Intel Mac 上使用吗？
答：当前版本仅支持 Apple Silicon，请等待 Universal 版本。

📚 更多帮助
--------------------------------------------------------------------------------
• 详细文档：README.md
• 问题反馈：https://github.com/AndyJZhao/ClickLoop

祝使用愉快！
================================================================================
EOF

# 复制文档文件
echo "📄 复制文档..."
if [ -f "README.md" ]; then
    cp README.md "$DIST_DIR/$DIST_NAME/"
fi

if [ -f "使用必读.txt" ]; then
    cp 使用必读.txt "$DIST_DIR/$DIST_NAME/"
fi

if [ -f "RELEASE_NOTES.md" ]; then
    cp RELEASE_NOTES.md "$DIST_DIR/$DIST_NAME/"
fi

# 创建 ZIP 包
echo "🗜️  压缩发布包..."
cd "$DIST_DIR"
zip -r -q "${DIST_NAME}.zip" "$DIST_NAME"
cd ..

# 计算文件大小
APP_SIZE=$(du -sh "$DIST_DIR/$DIST_NAME/ClickLoop.app" | cut -f1)
ZIP_SIZE=$(du -sh "$DIST_DIR/${DIST_NAME}.zip" | cut -f1)

# 显示摘要
echo ""
echo "✅ 发布包创建完成！"
echo ""
echo "📊 文件信息："
echo "   应用大小：$APP_SIZE"
echo "   压缩包大小：$ZIP_SIZE"
echo ""
echo "📁 发布文件："
echo "   $(pwd)/$DIST_DIR/${DIST_NAME}.zip"
echo ""
echo "📦 包含内容："
echo "   • ClickLoop.app"
echo "   • 安装说明.txt"
echo "   • README.md (如果存在)"
echo "   • 使用必读.txt (如果存在)"
echo "   • RELEASE_NOTES.md (如果存在)"
echo ""
echo "🚀 下一步："
echo "   1. 测试 ZIP 包中的应用"
echo "   2. 上传到 GitHub Release"
echo "   3. 更新发布说明"
echo ""

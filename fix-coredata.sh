#!/bin/bash

echo "🔧 修复Core Data配置问题"

# 进入项目目录
cd "$(dirname "$0")/DadaKnows"

echo "📁 检查Core Data模型文件..."
if [ -f "DadaKnows/Resources/DadaKnowsModel.xcdatamodeld/DadaKnowsModel.xcdatamodel/contents" ]; then
    echo "✅ Core Data模型文件存在"
else
    echo "❌ Core Data模型文件不存在"
    exit 1
fi

echo "🧹 清理构建缓存..."
rm -rf ~/Library/Developer/Xcode/DerivedData/DadaKnows-*
rm -rf build/

echo "🔨 重新构建项目..."
xcodebuild clean -project DadaKnows.xcodeproj -scheme DadaKnows

echo "📱 构建iOS应用..."
xcodebuild build -project DadaKnows.xcodeproj -scheme DadaKnows -destination 'platform=iOS Simulator,name=iPhone 15'

if [ $? -eq 0 ]; then
    echo "✅ 构建成功！"
    echo "💡 现在可以在Xcode中运行应用了"
else
    echo "❌ 构建失败，请检查Xcode中的错误信息"
    exit 1
fi

echo "🎯 修复完成！建议步骤："
echo "1. 在Xcode中打开项目"
echo "2. 确保DadaKnowsModel.xcdatamodeld文件在项目导航器中可见"
echo "3. 如果不可见，右键点击Resources文件夹 -> Add Files to DadaKnows"
echo "4. 选择DadaKnowsModel.xcdatamodeld文件并添加到项目"
echo "5. 确保该文件在Target Membership中被选中"
echo "6. 重新运行应用"

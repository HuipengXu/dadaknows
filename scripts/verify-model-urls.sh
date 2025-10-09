#!/bin/bash
#
# 验证模型文件 URL 可访问性和完整性
# 用于测试 R2 存储桶中的文件是否正确配置
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 基础 URL
BASE_URL="https://pub-07b3fe62045d44dc9e762f7d8e258566.r2.dev/Qwen3-4B-MLX-4bit"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  模型文件 URL 验证工具${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "基础 URL: ${YELLOW}${BASE_URL}${NC}"
echo ""

# 统计
total_files=10
passed=0
failed=0
skipped=0

# 是否验证 SHA256（大文件跳过）
VERIFY_SHA256=${1:-"small"}  # "all", "small", "none"

echo -e "${BLUE}开始验证...${NC}"
echo ""

# 定义验证函数
verify_file() {
    local file=$1
    local expected_sha256=$2
    local expected_size=$3
    local url="${BASE_URL}/${file}"
    
    echo -e "${YELLOW}[$(($passed + $failed + $skipped + 1))/${total_files}]${NC} 检查: ${file}"
    
    # 1. 检查 URL 可访问性
    response=$(curl -s -I "${url}" 2>&1)
    http_code=$(echo "$response" | grep "HTTP" | head -1 | awk '{print $2}')
    content_length=$(echo "$response" | grep -i "Content-Length" | head -1 | awk '{print $2}' | tr -d '\r')
    
    if [ "$http_code" != "200" ]; then
        echo -e "  ${RED}✗ HTTP 状态码: ${http_code}${NC}"
        failed=$((failed + 1))
        echo ""
        return 1
    fi
    
    echo -e "  ${GREEN}✓ HTTP 状态码: 200${NC}"
    
    # 2. 检查文件大小
    if [ "$content_length" != "$expected_size" ]; then
        echo -e "  ${RED}✗ 文件大小不匹配${NC}"
        echo -e "    期望: ${expected_size} bytes"
        echo -e "    实际: ${content_length} bytes"
        failed=$((failed + 1))
        echo ""
        return 1
    fi
    
    echo -e "  ${GREEN}✓ 文件大小: ${content_length} bytes${NC}"
    
    # 3. 检查 SHA256（可选）
    should_verify=false
    
    if [ "$VERIFY_SHA256" == "all" ]; then
        should_verify=true
    elif [ "$VERIFY_SHA256" == "small" ] && [ "$expected_size" -lt 1000000 ]; then
        should_verify=true
    fi
    
    if [ "$should_verify" == true ]; then
        echo -e "  ${BLUE}⏳ 正在下载并验证 SHA256...${NC}"
        actual_sha256=$(curl -s "${url}" | shasum -a 256 | awk '{print $1}')
        
        if [ "$actual_sha256" != "$expected_sha256" ]; then
            echo -e "  ${RED}✗ SHA256 不匹配${NC}"
            echo -e "    期望: ${expected_sha256}"
            echo -e "    实际: ${actual_sha256}"
            failed=$((failed + 1))
            echo ""
            return 1
        fi
        
        echo -e "  ${GREEN}✓ SHA256: 匹配${NC}"
        passed=$((passed + 1))
    else
        echo -e "  ${YELLOW}⊘ SHA256: 已跳过（文件过大或已禁用）${NC}"
        skipped=$((skipped + 1))
    fi
    
    echo ""
    return 0
}

# 验证所有文件（从 ModelConfig.swift 中提取）
verify_file "model.safetensors" "e56a94b846a2dce7d1cc154ce58b9cfc4b8d99e8ffb74bfe256a265f4cbc7fb9" "2137326367"
verify_file "tokenizer.json" "aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4" "11422654"
verify_file "tokenizer_config.json" "d5d09f07b48c3086c508b30d1c9114bd1189145b74e982a265350c923acd8101" "9732"
verify_file "vocab.json" "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910" "2776833"
verify_file "merges.txt" "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5" "1671853"
verify_file "config.json" "76eae114d67a444c7296be7a6bc0409ecc15c340e113f1bac7572cb7d0928b6f" "988"
verify_file "configuration.json" "a78221ae93dd8977b26fcd1d106fa5ad7e7f1fd3a7d93bfd9d6fba5ed00ec4d2" "48"
verify_file "model.safetensors.index.json" "278844a566da15beab6e9068c57f606c50a99c440d4515206b871a8b5282b3de" "63924"
verify_file "LICENSE" "832dd9e00a68dd83b3c3fb9f5588dad7dcf337a0db50f7d9483f310cd292e92e" "11343"
verify_file "README.md" "a3ac01d2a1fff2f02be25e1d2e9160f03db51dbee2cc17f13b774f646648adf9" "14708"

# 输出总结
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  验证结果总结${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "总文件数: ${total_files}"
echo -e "${GREEN}通过: ${passed}${NC}"
if [ $skipped -gt 0 ]; then
    echo -e "${YELLOW}跳过: ${skipped}${NC}"
fi
if [ $failed -gt 0 ]; then
    echo -e "${RED}失败: ${failed}${NC}"
fi
echo ""

if [ $failed -gt 0 ]; then
    echo -e "${RED}❌ 验证失败！请检查失败的文件。${NC}"
    exit 1
else
    echo -e "${GREEN}✅ 所有检查通过！${NC}"
    exit 0
fi
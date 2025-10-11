#!/bin/bash

# 测试月度使用限制功能

PROJECT_REF="fwvyrcekbngcpiudljpj"
BASE_URL="https://$PROJECT_REF.supabase.co/functions/v1"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ3dnlyY2VrYm5nY3BpdWRsanBqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3MzQ4ODYsImV4cCI6MjA3MjMxMDg4Nn0.c62pXLg1sU8ZAz2bETNdtIKqBXnwGMzhj6M7cMIeUCg"

echo "🧪 测试月度使用限制功能"
echo "=================================="
echo ""

# 测试 check-usage
echo "1️⃣ 测试 check-usage 函数..."
echo "URL: $BASE_URL/check-usage"
echo ""

RESPONSE=$(curl -s -X POST "$BASE_URL/check-usage" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "apikey: $ANON_KEY" \
  -d '{"userId": "test-user-123"}')

echo "响应: $RESPONSE"
echo ""

# 测试 increment-usage
echo "2️⃣ 测试 increment-usage 函数..."
echo "URL: $BASE_URL/increment-usage"
echo ""

RESPONSE=$(curl -s -X POST "$BASE_URL/increment-usage" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "apikey: $ANON_KEY" \
  -d '{"userId": "test-user-123"}')

echo "响应: $RESPONSE"
echo ""

# 测试 ask-dada（带userId）
echo "3️⃣ 测试更新后的 ask-dada 函数..."
echo "URL: $BASE_URL/ask-dada"
echo ""

curl -X POST "$BASE_URL/ask-dada" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "apikey: $ANON_KEY" \
  -d '{
    "question": "测试问题",
    "age": 5,
    "language": "zh-CN",
    "apiKey": "AIzaSyD-YSyKmhc4d23ybooPBbJJaskhZshOV20",
    "userId": "test-user-123"
  }'

echo ""
echo ""
echo "=================================="
echo "✅ 测试完成！"

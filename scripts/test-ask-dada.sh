#!/bin/bash

# DadaKnows Edge Function 测试脚本
PROJECT_REF="fwvyrcekbngcpiudljpj"
FUNCTION_URL="https://$PROJECT_REF.supabase.co/functions/v1/ask-dada"
API_KEY="AIzaSyD-YSyKmhc4d23ybooPBbJJaskhZshOV20"

echo "🧪 测试 ask-dada 函数..."
echo "URL: $FUNCTION_URL"
echo ""

# 测试请求
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ3dnlyY2VrYm5nY3BpdWRsanBqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3MzQ4ODYsImV4cCI6MjA3MjMxMDg4Nn0.c62pXLg1sU8ZAz2bETNdtIKqBXnwGMzhj6M7cMIeUCg" \
  -d '{
    "question": "为什么天空是蓝色的？",
    "age": 5,
    "language": "zh-CN",
    "apiKey": "'$API_KEY'"
  }'

echo ""
echo ""
echo "测试完成！如果看到流式响应，说明部署成功 ✅"

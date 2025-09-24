#!/usr/bin/env swift

// verify-llama-integration.swift
// 验证llama.cpp集成是否成功的脚本

import Foundation

#if canImport(llama)
import llama

print("✅ llama.cpp XCFramework imported successfully!")

// 测试基本API可用性
let model_params = llama_model_default_params()
print("✅ llama_model_default_params() works")

let ctx_params = llama_context_default_params()  
print("✅ llama_context_default_params() works")

print("🎉 llama.cpp integration verification completed successfully!")

#else
print("❌ llama.cpp XCFramework is not available")
print("Please ensure you have added the llama Swift Package to your Xcode project:")
print("1. Open Xcode project")
print("2. Select project → Target → Package Dependencies")
print("3. Add package: https://github.com/ggml-org/llama.cpp")
print("4. Select 'llama' library")

exit(1)
#endif

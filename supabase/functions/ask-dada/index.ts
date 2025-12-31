/**
 * Ask-Dada Edge Function
 * 核心AI问答服务
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { corsHeaders } from '../_shared/cors.ts';
import { createGeminiClient } from '../_shared/gemini.ts';
import { 
  generatePrompt, 
  validateQuestionSafety, 
  generateErrorResponse,
  type PromptConfig 
} from '../_shared/prompts.ts';

interface RequestBody {
  question: string;
  age: number;
  language: string;
  previousAnswer?: string;
  conversationHistory?: Array<{
    message: string;
    isFromUser: boolean;
    timestamp: string;
  }>;
  apiKey?: string;
  userId?: string;
  monthlyLimit?: number;  // 可选的月度限制参数
}

interface StreamChunk {
  type: 'chunk' | 'complete' | 'error';
  data: string;
  error?: string;
}

/**
 * 验证请求参数
 */
function validateRequest(body: any): { isValid: boolean; error?: string; data?: RequestBody } {
  // 检查必需字段
  if (!body.question || typeof body.question !== 'string') {
    return { isValid: false, error: 'Missing or invalid question parameter' };
  }
  
  if (!body.age || typeof body.age !== 'number' || body.age < 2 || body.age > 12) {
    return { isValid: false, error: 'Age must be between 2 and 12' };
  }
  
  if (!body.language || typeof body.language !== 'string') {
    return { isValid: false, error: 'Missing language parameter' };
  }
  
  if (!body.apiKey || typeof body.apiKey !== 'string') {
    return { isValid: false, error: 'Missing API key' };
  }
  
  // 验证问题长度
  if (body.question.length > 500) {
    return { isValid: false, error: 'Question too long (max 500 characters)' };
  }
  
  return {
    isValid: true,
    data: {
      question: body.question.trim(),
      age: Math.round(body.age),
      language: body.language,
      previousAnswer: body.previousAnswer?.trim(),
      conversationHistory: body.conversationHistory,
      apiKey: body.apiKey,
      userId: body.userId
    }
  };
}

/**
 * 检查用户的月度使用配额
 */
async function checkUsageLimit(supabase: any, userId: string, monthlyLimit?: number): Promise<{ allowed: boolean; reason?: string }> {
  try {
    // 从参数中获取monthlyLimit，如果未提供则使用默认值3000
    const limit = monthlyLimit ?? 3000;

    // 调用数据库函数检查使用限制
    const { data, error } = await supabase.rpc('check_monthly_usage_limit', {
      p_user_id: userId,
      p_monthly_limit: limit
    });

    if (error) {
      console.error('[Ask-Dada] Usage check error:', error);
      // 如果检查失败，允许继续（降级处理）
      return { allowed: true };
    }

    if (!data.allowed) {
      return {
        allowed: false,
        reason: data.is_pro
          ? `Monthly usage limit exceeded. You have used all ${limit} questions for this month.`
          : 'Daily usage limit exceeded.'
      };
    }

    return { allowed: true };
  } catch (error) {
    console.error('[Ask-Dada] Usage check exception:', error);
    // 如果检查失败，允许继续（降级处理）
    return { allowed: true };
  }
}

/**
 * 增加用户的使用次数
 */
async function incrementUsage(supabase: any, userId: string): Promise<void> {
  try {
    const { error } = await supabase.rpc('increment_remote_usage', {
      p_user_id: userId
    });
    
    if (error) {
      console.error('[Ask-Dada] Increment usage error:', error);
    }
  } catch (error) {
    console.error('[Ask-Dada] Increment usage exception:', error);
  }
}

/**
 * 创建流式响应
 */
function createStreamResponse(): { stream: ReadableStream; controller: ReadableStreamDefaultController } {
  let controller: ReadableStreamDefaultController;
  
  const stream = new ReadableStream({
    start(ctrl) {
      controller = ctrl;
    },
  });
  
  return { stream, controller: controller! };
}

/**
 * 发送流式数据块
 */
function sendChunk(controller: ReadableStreamDefaultController, chunk: StreamChunk): void {
  const data = `data: ${JSON.stringify(chunk)}\n\n`;
  controller.enqueue(new TextEncoder().encode(data));
}

/**
 * 主要的Edge Function处理器
 */
serve(async (req) => {
  // 处理CORS预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  
  // 只允许POST请求
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }), 
      { 
        status: 405, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
  
  try {
    // 获取环境变量
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration');
    }
    
    // 创建Supabase客户端（使用service role key以绕过RLS）
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // 解析请求体
    const body = await req.json();
    
    // 验证请求参数
    const validation = validateRequest(body);
    if (!validation.isValid) {
      return new Response(
        JSON.stringify({ error: validation.error }), 
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }
    
    const { question, age, language, previousAnswer, conversationHistory, apiKey, userId, monthlyLimit } = validation.data!;

    // 如果提供了userId，检查使用配额
    if (userId) {
      const usageCheck = await checkUsageLimit(supabase, userId, monthlyLimit);
      if (!usageCheck.allowed) {
        return new Response(
          JSON.stringify({ 
            error: usageCheck.reason || 'Usage limit exceeded',
            code: 'USAGE_LIMIT_EXCEEDED'
          }), 
          { 
            status: 429, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        );
      }
    }
    
    // 验证问题安全性
    const safetyCheck = validateQuestionSafety(question, language);
    if (!safetyCheck.isSafe) {
      return new Response(
        JSON.stringify({ 
          error: safetyCheck.reason,
          suggestion: safetyCheck.suggestedRedirect 
        }), 
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }
    
    // 创建流式响应
    const { stream, controller } = createStreamResponse();
    
    // 异步处理AI生成
    (async () => {
      try {
        // 创建Gemini客户端
        const geminiClient = createGeminiClient(apiKey, {
          model: 'gemini-2.5-flash-lite',
          temperature: 0.8,
          maxOutputTokens: 2048
        });
        
        // 生成Prompt
        const promptConfig: PromptConfig = {
          question,
          age,
          language,
          previousAnswer,
          conversationHistory,
          isRegenerate: !!previousAnswer
        };
        
        const prompt = generatePrompt(promptConfig);
        
        // 记录请求（调试用）
        console.log(`[Ask-Dada] Processing question for ${age}-year-old in ${language}:`, question.substring(0, 50) + '...');
        
        // 增加使用次数（在开始生成回答之前）
        if (userId) {
          await incrementUsage(supabase, userId);
        }
        
        // 流式生成回答
        const responseGenerator = geminiClient.generateStreamResponse(prompt);
        
        for await (const response of responseGenerator) {
          if (response.error) {
            // 发送错误
            sendChunk(controller, {
              type: 'error',
              data: '',
              error: generateErrorResponse(language, response.error)
            });
            break;
          } else if (response.isComplete) {
            // 发送完成信号
            sendChunk(controller, {
              type: 'complete',
              data: ''
            });
            break;
          } else {
            // 发送文本块
            sendChunk(controller, {
              type: 'chunk',
              data: response.text
            });
          }
        }
        
      } catch (error) {
        console.error('[Ask-Dada] Error:', error);
        
        // 发送错误响应
        sendChunk(controller, {
          type: 'error',
          data: '',
          error: generateErrorResponse(language)
        });
      } finally {
        // 关闭流
        controller.close();
      }
    })();
    
    // 返回流式响应
    return new Response(stream, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    });
    
  } catch (error) {
    console.error('[Ask-Dada] Request parsing error:', error);
    
    return new Response(
      JSON.stringify({ 
        error: 'Invalid request format'
      }), 
      { 
        status: 400, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});

// 健康检查端点
console.log('🚀 Ask-Dada Edge Function is running!');
console.log('📋 Supported features:');
console.log('  ✅ Age-appropriate responses (2-12 years)');
console.log('  ✅ Bilingual support (Chinese/English)');  
console.log('  ✅ Streaming responses');
console.log('  ✅ Safety validation');
console.log('  ✅ Answer regeneration');

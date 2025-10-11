/**
 * Check-Usage Edge Function
 * 检查用户的月度使用配额
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { corsHeaders } from '../_shared/cors.ts';

interface RequestBody {
  userId: string;
}

interface UsageCheckResponse {
  allowed: boolean;
  is_pro: boolean;
  current_usage: number;
  limit: number;
  remaining: number;
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
    const { userId } = body as RequestBody;
    
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Missing userId parameter' }), 
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }
    
    // 调用数据库函数检查使用限制
    const { data, error } = await supabase.rpc('check_monthly_usage_limit', {
      p_user_id: userId,
      p_monthly_limit: 3000
    });
    
    if (error) {
      console.error('[Check-Usage] Database error:', error);
      throw error;
    }
    
    const usageData: UsageCheckResponse = data as UsageCheckResponse;
    
    console.log(`[Check-Usage] User ${userId}: ${usageData.current_usage}/${usageData.limit} (${usageData.remaining} remaining)`);
    
    return new Response(
      JSON.stringify(usageData), 
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
    
  } catch (error) {
    console.error('[Check-Usage] Error:', error);
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        details: error.message 
      }), 
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});

// 健康检查端点
console.log('🚀 Check-Usage Edge Function is running!');
console.log('📋 Function: Check monthly usage limit for Pro users (3000 questions/month)');


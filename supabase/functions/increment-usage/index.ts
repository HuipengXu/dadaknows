/**
 * Increment-Usage Edge Function
 * 增加用户的远程模型使用次数
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { corsHeaders } from '../_shared/cors.ts';

interface RequestBody {
  userId: string;
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
    
    // 调用数据库函数增加使用次数
    const { data, error } = await supabase.rpc('increment_remote_usage', {
      p_user_id: userId
    });
    
    if (error) {
      console.error('[Increment-Usage] Database error:', error);
      throw error;
    }
    
    console.log(`[Increment-Usage] User ${userId}: incremented to ${data.remote_questions_count}`);
    
    return new Response(
      JSON.stringify({ 
        success: true,
        usage: data
      }), 
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
    
  } catch (error) {
    console.error('[Increment-Usage] Error:', error);
    
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
console.log('🚀 Increment-Usage Edge Function is running!');
console.log('📋 Function: Increment remote model usage count');


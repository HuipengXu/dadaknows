/**
 * CORS配置
 * 处理跨域请求头
 */

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Max-Age': '86400', // 24小时
};

/**
 * 创建CORS响应
 */
export function createCorsResponse(
  data: any, 
  status: number = 200, 
  additionalHeaders: Record<string, string> = {}
): Response {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        ...additionalHeaders,
      },
    }
  );
}

/**
 * 处理OPTIONS请求
 */
export function handleCorsPreflightRequest(): Response {
  return new Response('ok', { 
    headers: corsHeaders,
    status: 200 
  });
}

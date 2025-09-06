/**
 * Gemini API 客户端
 * 基于 @google/genai 实现流式AI响应
 */

import { GoogleGenerativeAI } from '@google/generative-ai';

export interface GeminiConfig {
  apiKey: string;
  model?: string;
  temperature?: number;
  maxOutputTokens?: number;
}

export interface StreamResponse {
  text: string;
  isComplete: boolean;
  error?: string;
}

export class GeminiClient {
  private ai: GoogleGenerativeAI;
  private model: string;
  private temperature: number;
  private maxOutputTokens: number;

  constructor(config: GeminiConfig) {
    this.ai = new GoogleGenerativeAI(config.apiKey);
    
    this.model = config.model || 'gemini-1.5-flash';
    this.temperature = config.temperature || 0.7;
    this.maxOutputTokens = config.maxOutputTokens || 2048;
  }

  /**
   * 流式生成AI回答
   */
  async* generateStreamResponse(prompt: string): AsyncGenerator<StreamResponse, void, unknown> {
    try {
      const model = this.ai.getGenerativeModel({ 
        model: this.model,
        generationConfig: {
          temperature: this.temperature,
          maxOutputTokens: this.maxOutputTokens,
        }
      });

      const result = await model.generateContentStream(prompt);

      let fullText = '';
      
      for await (const chunk of result.stream) {
        const chunkText = chunk.text();
        if (chunkText) {
          fullText += chunkText;
          yield {
            text: chunkText,
            isComplete: false,
          };
        }
      }

      // 发送完成信号
      yield {
        text: '',
        isComplete: true,
      };

    } catch (error) {
      console.error('Gemini API Error:', error);
      
      yield {
        text: '',
        isComplete: true,
        error: error instanceof Error ? error.message : 'AI服务暂时不可用，请稍后重试',
      };
    }
  }

  /**
   * 单次生成AI回答（非流式）
   */
  async generateResponse(prompt: string): Promise<string> {
    try {
      const model = this.ai.getGenerativeModel({ 
        model: this.model,
        generationConfig: {
          temperature: this.temperature,
          maxOutputTokens: this.maxOutputTokens,
        }
      });

      const result = await model.generateContent(prompt);
      const response = await result.response;
      
      return response.text() || '抱歉，答答现在有点累了，请稍后再试试吧！';

    } catch (error) {
      console.error('Gemini API Error:', error);
      return '抱歉，答答现在有点累了，请稍后再试试吧！';
    }
  }

  /**
   * 健康检查
   */
  async healthCheck(): Promise<boolean> {
    try {
      await this.generateResponse('Hello, this is a health check.');
      return true;
    } catch (error) {
      console.error('Gemini health check failed:', error);
      return false;
    }
  }
}

/**
 * 工厂函数：创建Gemini客户端实例
 */
export function createGeminiClient(apiKey: string, options?: Partial<GeminiConfig>): GeminiClient {
  return new GeminiClient({
    apiKey,
    ...options,
  });
}

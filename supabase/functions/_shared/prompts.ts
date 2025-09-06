/**
 * Prompt 模板与管理
 * 为不同年龄段和语言生成合适的AI提示词
 */

export interface PromptConfig {
  question: string;
  age: number;
  language: string;
  previousAnswer?: string;
  isRegenerate?: boolean;
}

export interface PromptTemplate {
  systemPrompt: string;
  userPrompt: string;
}

/**
 * 年龄段配置
 */
const AGE_CONFIGS = {
  '2-3': {
    complexity: '非常简单',
    vocabulary: '基础词汇',
    sentenceLength: '短句',
    examples: '具体实物',
    attention: '30秒以内'
  },
  '4-5': {
    complexity: '简单易懂',
    vocabulary: '日常词汇',
    sentenceLength: '简单句',
    examples: '身边事物',
    attention: '1-2分钟'
  },
  '6-7': {
    complexity: '适中',
    vocabulary: '丰富词汇',
    sentenceLength: '完整句子',
    examples: '生动比喻',
    attention: '2-3分钟'
  },
  '8-9': {
    complexity: '稍有深度',
    vocabulary: '扩展词汇',
    sentenceLength: '复合句',
    examples: '科学概念',
    attention: '3-5分钟'
  },
  '10-12': {
    complexity: '有一定深度',
    vocabulary: '学术词汇',
    sentenceLength: '逻辑性句子',
    examples: '抽象概念',
    attention: '5-8分钟'
  }
};

/**
 * 获取年龄段配置
 */
function getAgeGroup(age: number): keyof typeof AGE_CONFIGS {
  if (age <= 3) return '2-3';
  if (age <= 5) return '4-5';
  if (age <= 7) return '6-7';
  if (age <= 9) return '8-9';
  return '10-12';
}

/**
 * 中文Prompt模板
 */
function generateChinesePrompt(config: PromptConfig): PromptTemplate {
  const ageGroup = getAgeGroup(config.age);
  const ageConfig = AGE_CONFIGS[ageGroup];
  
  const systemPrompt = `你是"答答"，一个专门为${config.age}岁中国儿童回答问题的AI助手。你的性格特点：
  
🎯 **核心使命**: 守护和激发孩子的好奇心，用充满童趣的方式帮助他们认知世界
  
👶 **年龄适配** (${config.age}岁 - ${ageGroup}岁段):
- 语言复杂度: ${ageConfig.complexity}
- 词汇水平: ${ageConfig.vocabulary}  
- 句子长度: ${ageConfig.sentenceLength}
- 举例方式: ${ageConfig.examples}
- 注意力span: ${ageConfig.attention}

🎭 **表达风格**:
- 用第一人称"我"来表达，保持亲切感
- 语调温暖、充满耐心和鼓励
- 适当使用emoji增加趣味性 ✨
- 善用比喻、故事、游戏等方式解释
- 结尾总是鼓励继续探索

🔒 **安全准则**:
- 内容必须积极正面，适合儿童
- 避免恐怖、暴力、成人化内容  
- 遇到不适宜话题，温和转移到相关的安全话题
- 鼓励孩子与父母分享学到的知识

📏 **回答长度**: 100-300字，保持在孩子的注意力范围内

${config.isRegenerate ? '\n🔄 **特别要求**: 这是重新生成的回答，请用完全不同的角度和表达方式来解释，带来新的惊喜！' : ''}`;

  const userPrompt = `${config.isRegenerate ? '请用不同的方式重新解释：' : ''}${config.question}`;

  return { systemPrompt, userPrompt };
}

/**
 * 英文Prompt模板
 */
function generateEnglishPrompt(config: PromptConfig): PromptTemplate {
  const ageGroup = getAgeGroup(config.age);
  const ageConfig = AGE_CONFIGS[ageGroup];
  
  const systemPrompt = `You are "Dada", an AI assistant specifically designed to answer questions for ${config.age}-year-old children. Your characteristics:

🎯 **Core Mission**: Protect and inspire children's curiosity, helping them understand the world through delightful and imaginative explanations

👶 **Age Adaptation** (${config.age} years old - ${ageGroup} age group):
- Language complexity: ${ageConfig.complexity}
- Vocabulary level: ${ageConfig.vocabulary}
- Sentence length: ${ageConfig.sentenceLength}  
- Example style: ${ageConfig.examples}
- Attention span: ${ageConfig.attention}

🎭 **Expression Style**:
- Use first person "I" to maintain intimacy
- Warm, patient, and encouraging tone
- Use appropriate emojis for fun ✨
- Use metaphors, stories, games to explain concepts
- Always end with encouragement to keep exploring

🔒 **Safety Guidelines**:
- Content must be positive and child-appropriate
- Avoid scary, violent, or adult content
- For inappropriate topics, gently redirect to related safe topics
- Encourage children to share what they learn with parents

📏 **Response Length**: 100-300 words, within children's attention span

${config.isRegenerate ? '\n🔄 **Special Requirement**: This is a regenerated answer. Please explain from a completely different angle and expression to bring new surprises!' : ''}`;

  const userPrompt = `${config.isRegenerate ? 'Please explain this differently: ' : ''}${config.question}`;

  return { systemPrompt, userPrompt };
}

/**
 * 生成完整的提示词
 */
export function generatePrompt(config: PromptConfig): string {
  const template = config.language.startsWith('zh') 
    ? generateChinesePrompt(config)
    : generateEnglishPrompt(config);
  
  let fullPrompt = `${template.systemPrompt}\n\n**用户问题**: ${template.userPrompt}`;
  
  // 如果有之前的回答，添加上下文
  if (config.previousAnswer) {
    const contextNote = config.language.startsWith('zh') 
      ? '\n\n**上次回答**: (请确保新回答与此不同)\n'
      : '\n\n**Previous Answer**: (Please ensure the new answer is different)\n';
    fullPrompt += contextNote + config.previousAnswer;
  }
  
  return fullPrompt;
}

/**
 * 验证问题是否适合儿童
 */
export function validateQuestionSafety(question: string, language: string): { isSafe: boolean; reason?: string; suggestedRedirect?: string } {
  const unsafeKeywords = {
    zh: ['死亡', '自杀', '暴力', '恐怖', '血腥', '成人', '色情', '赌博', '毒品', '酒精'],
    en: ['death', 'suicide', 'violence', 'horror', 'bloody', 'adult', 'sexual', 'gambling', 'drugs', 'alcohol']
  };
  
  const keywords = language.startsWith('zh') ? unsafeKeywords.zh : unsafeKeywords.en;
  const lowerQuestion = question.toLowerCase();
  
  for (const keyword of keywords) {
    if (lowerQuestion.includes(keyword.toLowerCase())) {
      return {
        isSafe: false,
        reason: language.startsWith('zh') 
          ? `问题包含不适合儿童的内容: ${keyword}`
          : `Question contains inappropriate content for children: ${keyword}`,
        suggestedRedirect: language.startsWith('zh')
          ? '我们来聊聊一些更有趣的事情吧！比如动物、科学或者大自然？'
          : 'Let\'s talk about something more interesting! Like animals, science, or nature?'
      };
    }
  }
  
  return { isSafe: true };
}

/**
 * 生成错误回答
 */
export function generateErrorResponse(language: string, error?: string): string {
  if (language.startsWith('zh')) {
    return error || '抱歉，答答现在有点累了，请稍后再试试吧！🦄 但是答答还是很愿意和你聊天的哦！';
  } else {
    return error || 'Sorry, Dada is a bit tired right now, please try again later! 🦄 But Dada still loves chatting with you!';
  }
}

/**
 * 获取欢迎消息
 */
export function getWelcomeMessage(age: number, language: string): string {
  if (language.startsWith('zh')) {
    return `你好！我是答答，很高兴认识${age}岁的你！✨ 我最喜欢回答小朋友的问题了，你想问答答什么呢？`;
  } else {
    return `Hello! I'm Dada, so nice to meet you at ${age} years old! ✨ I love answering questions from curious kids like you. What would you like to ask Dada?`;
  }
}

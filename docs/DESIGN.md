# ReadingMaster（阅读王）总设计书

> 本文档是 ReadingMaster（阅读王） 项目的**总设计书（Master Design Document）**，作为后续所有开发规划的基准。开发工作按本文档的「开发阶段规划」分阶段推进，避免一次性把整份需求丢给 AI Coding Agent 导致代码混乱。

---

## 目录

1. [项目总览](#1-项目总览)
2. [产品核心理念](#2-产品核心理念)
3. [MVP 范围](#3-mvp-范围)
4. [用户角色](#4-用户角色)
5. [用户完整流程](#5-用户完整流程)
6. [页面原型与交互设计](#6-页面原型与交互设计)
7. [儿童体验设计原则](#7-儿童体验设计原则)
8. [技术栈](#8-技术栈)
9. [数据库设计](#9-数据库设计)
10. [API 设计](#10-api-设计)
11. [AI 服务设计](#11-ai-服务设计)
12. [项目目录结构](#12-项目目录结构)
13. [内容管理方式](#13-内容管理方式)
14. [第一批测试内容](#14-第一批测试内容)
15. [完整故事示例](#15-完整故事示例)
16. [第一版最重要的数据指标](#16-第一版最重要的数据指标)
17. [MVP 验证标准](#17-mvp-验证标准)
18. [产品演化路径](#18-产品演化路径)
19. [开发阶段规划（Phase 0 ~ 7）](#19-开发阶段规划phase-0--7)
20. [AI Coding Agent 工作方式](#20-ai-coding-agent-工作方式)
21. [实际开发顺序建议](#21-实际开发顺序建议)

---

## 1. 项目总览

### 1.1 项目名称

| 项目 | 名称 |
| --- | --- |
| 英文名 | ReadingMaster |
| 中文暂定名 | 阅读王 |

### 1.2 一句话介绍

> 帮助小学生通过阅读英文故事，自然学习单词、发音和阅读理解的 **AI 英语分级阅读产品**。

### 1.3 目标用户

小学阶段儿童，尤其是**小学三年级左右**的孩子。

### 1.4 平台策略

- MVP 第一阶段优先支持 **Web（Flutter Web，适配 iPad Safari / Chrome）**
- Android 真机作为兼容验证目标；iOS / Android 原生客户端后续再发布

---

## 2. 产品核心理念

不要把产品做成：

> 英语词典 + 电子书 + AI Chat

而是做成：

> **一个会陪孩子读英语的智能阅读器。**

### 核心学习闭环

```text
选择适合自己的故事
        ↓
阅读英文内容
        ↓
遇到不会的单词
        ↓
点击单词
        ↓
查看简单解释 + 中文 + 发音
        ↓
继续阅读
        ↓
完成故事
        ↓
阅读理解
        ↓
系统记录学习情况
        ↓
复习生词
        ↓
推荐下一本更适合的故事
```

### 学习方法的落地原则

三条来自主流英语学习方法的原则，贯穿内容、阅读和复习：

1. **i+1 分级**：每本书只比孩子当前水平略难一点。给每本书标注"新词数"和"难度增量"，内容上每页最多引入 1~2 个生词；书架和推荐按"略难一点"排序，而不是只看 Level。
2. **精读 / 泛读两条路径**：精读书完整走「读 → 查 → 题 → 生词 → 复习」，泛读书只计阅读时长和完成率、不强制做题，保护阅读兴趣。
3. **语境记词**：生词本和复习卡始终带上原书原句，先让词回到语境再测，避免孤立背单词。

---

## 3. MVP 范围

### 3.1 MVP 必须验证的核心问题

> 一个小学三年级孩子，是否愿意**主动使用**这个产品阅读英文故事？

因此 MVP **不追求功能多**。

### 3.2 MVP 功能清单

| 模块 | MVP |
| --- | --- |
| 用户 | ✅ |
| 儿童资料 | ✅ |
| 英语等级 | ✅ |
| 首页 | ✅ |
| 书架 | ✅ |
| 英语故事 | ✅ |
| 阅读器 | ✅ |
| 点击单词 | ✅ |
| 中文释义 | ✅ |
| 英文简单解释 | ✅ |
| 发音 | ✅ |
| 收藏单词 | ✅ |
| 阅读进度 | ✅ |
| 阅读完成 | ✅ |
| 阅读理解 | ✅ |
| 生词本 | ✅ |
| 基础复习 | ✅ |
| 家长数据 | 简单版 |
| AI 聊天 | ❌ |
| AI 陪读 | ❌ |
| AI 口语评分 | ❌ |
| 社交 | ❌ |
| 游戏商城 | ❌ |
| 复杂积分体系 | ❌ |

### 3.3 MVP 必须实现（详细版）

1. 用户注册/登录
2. Parent / Child 两种角色
3. 创建儿童资料
4. 儿童年级
5. 儿童阅读等级
6. 首页
7. 书架
8. 英文故事阅读
9. 点击单词
10. 单词中文解释
11. 简单英文解释
12. 音标
13. 发音
14. 收藏单词
15. 阅读进度
16. 阅读 session
17. 阅读行为记录
18. 阅读完成
19. 3~5 道阅读理解
20. 阅读结果
21. 生词本
22. 简单复习
23. 家长阅读数据

### 3.4 MVP 暂不实现

1. AI 聊天
2. AI 陪读
3. AI 口语评分
4. 社交
5. 排行榜
6. 积分商城
7. 复杂游戏化
8. 支付
9. 学校管理
10. 复杂推荐模型

---

## 4. 用户角色

第一版只有两种角色：

### Parent（家长）

负责：

- 创建孩子
- 查看阅读数据
- 查看生词
- 查看阅读历史

### Child（孩子）

负责：

- 看故事
- 阅读
- 查询单词
- 听发音
- 做题
- 复习

---

## 5. 用户完整流程

### 5.1 第一次使用

```text
启动 App
 ↓
欢迎页
 ↓
登录/注册
 ↓
创建孩子
 ↓
输入：
  姓名
  年级
  英语基础
 ↓
简单水平测试
 ↓
得到 Level
 ↓
首页
```

例如：

```text
小明
三年级

当前阅读等级：

Level 2

推荐：
🐶 The Little Dog
```

### 5.2 核心用户路径

```text
Login
→ Home
→ Book
→ Reader
→ WordPopup
→ Quiz
→ Result
→ Vocabulary
```

---

## 6. 页面原型与交互设计

### 6.1 首页

首页不要塞很多数据。重点：**今天读什么？**

```text
┌──────────────────────────┐
│ Hi, 小明 👋              │
│                          │
│ 今天读一本英文故事吧！    │
│                          │
│ ┌──────────────────────┐ │
│ │      🐶              │ │
│ │   The Little Dog     │ │
│ │                      │ │
│ │   Level 2            │ │
│ │   约 8 分钟           │ │
│ │                      │ │
│ │      开始阅读        │ │
│ └──────────────────────┘ │
│                          │
│ 继续阅读                 │
│                          │
│ 🐱 The Lost Cat          │
│ 🚀 A Trip to Space       │
│                          │
│ 今日                     │
│ 📖 8分钟   ⭐ 3个新词    │
│                          │
│ 首页   书架   生词   我的 │
└──────────────────────────┘
```

### 6.2 书架页面

```text
┌──────────────────────────┐
│ 我的书架                  │
│                          │
│ [全部] [Level 1] [Level 2]│
│                          │
│ 🐶 The Little Dog        │
│ Level 2 · 8 min          │
│ ███████░░░ 70%           │
│                          │
│ 🐱 The Lost Cat          │
│ Level 2 · 6 min          │
│                          │
│ 🚀 A Trip to Space       │
│ Level 3 · 10 min         │
│                          │
└──────────────────────────┘
```

### 6.3 阅读器页面

这是**整个产品最重要的页面**。

MVP 不使用复杂分页排版，**一页 = 一个阅读段落 / 场景**：

```text
┌──────────────────────────┐
│ ← The Little Dog      ⋮ │
│                          │
│                          │
│ Tom has a little dog.    │
│                          │
│ The dog is very cute.    │
│                          │
│ Tom likes to play        │
│ with his dog.            │
│                          │
│                          │
│       3 / 8              │
│                          │
│      ←        →          │
└──────────────────────────┘
```

阅读器要支持的交互（借鉴同类产品的成熟做法）：

- 点击或长按任意单词弹出释义卡片（卡片定义见 6.4）。
- 生词高亮：按孩子当前等级给文章中的生词着色，并提供开关。
- 字体大小调节：适配低龄儿童与不同视力需求。

### 6.4 单词点击交互

孩子点击 `cute`，弹出底部卡片：

```text
┌──────────────────────────┐
│                          │
│          cute 🔊         │
│                          │
│         /kjuːt/          │
│                          │
│          可爱的           │
│                          │
│ feeling good because     │
│ something looks nice     │
│                          │
│ The dog is very cute.    │
│ 这只狗非常可爱。          │
│                          │
│       ⭐ 收藏            │
│                          │
└──────────────────────────┘
```

**重要原则：解释一定要适合小学生。**

错误：

```text
pleasing or appealing in an endearing way
```

正确：

```text
nice and lovely
```

中文：

```text
可爱的
```

补充两点（借鉴同类产品）：

- 基础名词可配 Emoji 图示（如 `dog` → 🐶），帮助低龄儿童建立直观联系；它是"中文释义 + 简单英文解释"的补充，不是替代。
- 已掌握的词不再每次都弹完整解释：当 `user_words.mastery_score` 较高时，只做轻量提示（高亮 + 已掌握标记），把 AI 解释和注意力留给真正的生词。
- 词形还原：`runs` / `ran` / `running` 统一归到 `run`，避免同一词被重复统计为生词。

### 6.5 阅读器核心交互

```text
点击单词：
Word
 ↓
Dictionary
 ↓
Meaning
Pronunciation
Example
 ↓
UserWord
 ↓
继续阅读
```

同时记录：

```text
word_clicked = true
audio_played = true
meaning_viewed = true
```

以后用于判断孩子对这个词的掌握情况。

### 6.6 阅读完成页面

```text
┌──────────────────────────┐
│                          │
│       🎉 Great Job!      │
│                          │
│    The Little Dog        │
│                          │
│ 阅读时间：7 分 32 秒      │
│ 新单词：6 个              │
│                          │
│ 现在来回答几个问题吧！    │
│                          │
│          开始答题         │
│                          │
└──────────────────────────┘
```

### 6.7 阅读理解页面

```text
What does Tom have?

○ A cat

● A dog

○ A rabbit

          下一题 →
```

MVP 规则：

- 3～5 道题
- 题型只做：**单选**、**判断**
- 不做复杂题型

### 6.8 阅读结果页面

```text
🎉 You did it!

The Little Dog

阅读理解
⭐⭐⭐⭐⭐

答对：4 / 5

今天遇到的新单词：

cute
friendly
hungry
run

建议再复习：

friendly
hungry

        去复习
```

### 6.9 生词本

```text
┌──────────────────────────┐
│ 我的单词                  │
│                          │
│ 需要复习                  │
│                          │
│ cute 🔊                  │
│ 可爱的                    │
│                          │
│ hungry 🔊                │
│ 饥饿的                    │
│                          │
│ friendly 🔊              │
│ 友好的                    │
│                          │
└──────────────────────────┘
```

### 6.10 简单复习

第一版**不做复杂 Anki**，但用**固定间隔的轻量复习**：答对进入下一档（1 → 2 → 4 → 7 → 15 → 30 天，之后算掌握），答错重置回 1 天。这个方案来自成熟阅读产品的 SRS 实践，足够简单，又能抓住"及时复习"的效果。

例如：

```text
单词

hungry

显示图片：

🍔

The boy is ______.

孩子：

hungry

答对：

🎉 Great!

答错：

再试一次。
```

### 6.11 家长端

第一版直接做在同一个 App 里。进入「家长模式」需要简单验证（例如 **PIN**），避免孩子误进入。

```text
家长首页
小明

本周阅读

📖 4 本
⏱ 53 分钟
⭐ 28 个新词

阅读等级

Level 2

最近表现

阅读理解：85%
单词掌握：72%

需要关注：

friendly
hungry
beautiful
```

---

## 7. 儿童体验设计原则

1. 不要给儿童展示复杂的技术信息。
2. 不要使用复杂英文解释。
3. UI 要简单、大字体、少文字、明显按钮、适当动画。
4. 避免考试感。
5. 内容分级遵循 i+1 原则：每本书只比孩子当前水平略难一点，避免大量生词打击信心。
6. 核心阅读链路尽量离线可用：故事正文与已查词缓存到本地，弱网/无网也能继续读。

举例：

```text
错误：
cute: pleasing or appealing in an endearing way

正确：
cute: nice and lovely

中文：可爱的
```

---

## 8. 技术栈

第一版技术栈直接定死：

| 层 | 技术 |
| --- | --- |
| 前端 | Flutter（MVP 优先 Web，后续生成 Android） |
| 后端 | Python 3.11+、FastAPI、SQLAlchemy、Pydantic、Alembic |
| 数据库 | PostgreSQL |
| 缓存 | Redis |
| 部署 | Docker Compose |
| AI | OpenAI / 兼容 LLM API（通过 AI Gateway） |
| 语音 | MVP：系统 TTS（`flutter_tts`；Web 使用 SpeechSynthesis，Android/iOS 使用本地引擎）；云 TTS（Azure / Google）留到 Phase 7 |

平台优先级：**Web（Flutter Web，iPad 浏览器）** → Android / 平板。

### 8.1 默认端口与配置

本地开发默认值写入 [.env.example](.env.example)，生产前必须替换所有密钥：

```text
Backend  8000
Postgres 5432
Redis    6379
```

数据库名与用户名：`readingmaster`；`AI_PROVIDER=mock`；`TTS_PROVIDER=system`。密码、`JWT_SECRET_KEY`、AI Key 默认都是占位值，部署前必须改。

### 8.2 MVP 交付形态：Web-first（适配 iPad）

MVP 优先做成 Flutter Web 版本，让测试用户在 iPad Safari / Chrome 中直接访问，不要求安装 APK。原因：

- 测试用户只有 iPad，无法稳定安装 Android APK；
- Flutter 同一套代码可同时构建 Web 和 Android，后续原生 App 不重写业务层；
- Web 预览更容易快速迭代和分发。

要求：

- 开发调试：`flutter run -d chrome`；发布：`flutter build web`。
- 布局使用响应式，至少适配 iPad 竖屏与横屏。
- 后端 Docker Compose 提供 `/api/v1`，前端通过 `.env` 配置 `API_BASE_URL`。
- TTS 在 Web 依赖 `SpeechSynthesis`；MVP 接受系统默认发音，音色/语言的精确控制在 Phase 7 处理。
- Android 真机调试保留，但 MVP 验收先以 iPad 上的 Web 体验为准。

---

## 9. 数据库设计

推荐 PostgreSQL，核心表如下：

```text
users
children
books
book_pages
words
book_words
reading_sessions
reading_events
user_words
quiz_questions
quiz_options
quiz_attempts
```

### 9.1 users

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'parent',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### 9.2 children

```sql
CREATE TABLE children (
    id UUID PRIMARY KEY,
    parent_id UUID NOT NULL REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    grade INTEGER,
    reading_level VARCHAR(20),
    vocabulary_size INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

例如：

```text
小明
grade = 3
reading_level = LEVEL_2
```

### 9.3 books

```sql
CREATE TABLE books (
    id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    cover_url TEXT,
    level VARCHAR(20) NOT NULL,
    estimated_minutes INTEGER,
    word_count INTEGER,
    category VARCHAR(100),
    status VARCHAR(20) DEFAULT 'PUBLISHED',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### 9.4 book_pages

```sql
CREATE TABLE book_pages (
    id UUID PRIMARY KEY,
    book_id UUID NOT NULL REFERENCES books(id),
    page_no INTEGER NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

例如：

```text
Book: The Little Dog

Page 1: Tom has a little dog.
Page 2: The dog is very cute.
Page 3: Tom likes to play with his dog.
```

### 9.5 words

```sql
CREATE TABLE words (
    id UUID PRIMARY KEY,
    word VARCHAR(100) UNIQUE NOT NULL,
    phonetic VARCHAR(100),
    meaning_zh TEXT,
    simple_definition TEXT,
    example_sentence TEXT,
    example_translation TEXT,
    audio_url TEXT,
    part_of_speech VARCHAR(50)
);
```

### 9.6 book_words

记录一本书有哪些重点词。

```sql
CREATE TABLE book_words (
    book_id UUID REFERENCES books(id),
    word_id UUID REFERENCES words(id),
    is_key_word BOOLEAN DEFAULT FALSE,
    PRIMARY KEY(book_id, word_id)
);
```

### 9.7 user_words

**这个表非常关键。**

```sql
CREATE TABLE user_words (
    id UUID PRIMARY KEY,
    child_id UUID REFERENCES children(id),
    word_id UUID REFERENCES words(id),
    encounter_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    audio_count INTEGER DEFAULT 0,
    correct_count INTEGER DEFAULT 0,
    wrong_count INTEGER DEFAULT 0,
    mastery_score FLOAT DEFAULT 0,
    last_seen_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

例如：

```text
cute

encounter_count = 5
click_count = 2
audio_count = 1
correct_count = 3
wrong_count = 1
mastery_score = 0.72
```

### 9.8 reading_sessions

```sql
CREATE TABLE reading_sessions (
    id UUID PRIMARY KEY,
    child_id UUID REFERENCES children(id),
    book_id UUID REFERENCES books(id),
    started_at TIMESTAMP,
    finished_at TIMESTAMP,
    duration_seconds INTEGER DEFAULT 0,
    progress FLOAT DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE
);
```

### 9.9 reading_events

记录行为：

```sql
CREATE TABLE reading_events (
    id UUID PRIMARY KEY,
    session_id UUID REFERENCES reading_sessions(id),
    child_id UUID REFERENCES children(id),
    book_id UUID REFERENCES books(id),
    page_no INTEGER,
    event_type VARCHAR(50),
    word_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

`event_type` 至少支持：

```text
PAGE_VIEW
WORD_CLICK
WORD_AUDIO
WORD_MEANING
BOOKMARK
PAGE_FINISH
BOOK_FINISH
```

### 9.10 Quiz 相关表

```sql
CREATE TABLE quiz_questions (
    id UUID PRIMARY KEY,
    book_id UUID REFERENCES books(id),
    question TEXT NOT NULL,
    question_type VARCHAR(30),
    correct_option VARCHAR(10)
);

CREATE TABLE quiz_options (
    id UUID PRIMARY KEY,
    question_id UUID REFERENCES quiz_questions(id),
    option_key VARCHAR(10),
    content TEXT
);
```

另需 `quiz_attempts` 表（记录每次答题尝试）。

---

## 10. API 设计

统一前缀：`/api/v1`

所有接口返回 JSON，错误返回统一格式。

### 10.1 Auth

注册：

```http
POST /api/v1/auth/register
```

Request：

```json
{
  "email": "parent@example.com",
  "password": "123456"
}
```

Response：

```json
{
  "access_token": "xxx",
  "user": {
    "id": "uuid",
    "role": "parent"
  }
}
```

登录：

```http
POST /api/v1/auth/login
```

### 10.2 Children

创建孩子：

```http
POST /api/v1/children
```

```json
{
  "name": "小明",
  "grade": 3
}
```

获取孩子列表：

```http
GET /api/v1/children
```

### 10.3 获取首页

```http
GET /api/v1/home?child_id=xxx
```

Response：

```json
{
  "child": {
    "name": "小明",
    "level": "LEVEL_2"
  },
  "recommended_book": {
    "id": "book-001",
    "title": "The Little Dog",
    "level": "LEVEL_2",
    "estimated_minutes": 8
  },
  "continue_reading": [],
  "today": {
    "reading_minutes": 8,
    "new_words": 3
  }
}
```

### 10.4 获取书籍

```http
GET /api/v1/books
GET /api/v1/books/{book_id}
```

Response：

```json
{
  "id": "book-001",
  "title": "The Little Dog",
  "level": "LEVEL_2",
  "pages": [
    {
      "page_no": 1,
      "content": "Tom has a little dog."
    },
    {
      "page_no": 2,
      "content": "The dog is very cute."
    }
  ]
}
```

### 10.5 查询单词

```http
GET /api/v1/words/{word}
```

例如：

```http
GET /api/v1/words/cute
```

Response：

```json
{
  "word": "cute",
  "phonetic": "/kjuːt/",
  "meaning_zh": "可爱的",
  "simple_definition": "nice and lovely",
  "example": "The dog is cute.",
  "audio_url": "/audio/cute.mp3"
}
```

### 10.6 记录单词行为

```http
POST /api/v1/reading/events
```

```json
{
  "session_id": "xxx",
  "book_id": "book-001",
  "page_no": 2,
  "event_type": "WORD_CLICK",
  "word": "cute"
}
```

### 10.7 阅读 Session

创建 session：

```http
POST /api/v1/reading/sessions
```

完成阅读：

```http
POST /api/v1/reading/sessions/{session_id}/finish
```

Response：

```json
{
  "duration_seconds": 452,
  "new_words": 4,
  "progress": 1.0
}
```

### 10.8 Quiz

获取 Quiz：

```http
GET /api/v1/books/{book_id}/quiz
```

提交 Quiz：

```http
POST /api/v1/quiz/attempt
```

```json
{
  "child_id": "xxx",
  "book_id": "book-001",
  "answers": [
    {
      "question_id": "q1",
      "option": "B"
    }
  ]
}
```

Response：

```json
{
  "score": 80,
  "correct": 4,
  "total": 5
}
```

### 10.9 获取生词

```http
GET /api/v1/children/{child_id}/words
```

支持：

```text
?status=review
```

### 10.10 AI 接口（规划）

```text
POST /api/v1/ai/explain-word
POST /api/v1/ai/generate-story
POST /api/v1/ai/generate-quiz
POST /api/v1/ai/analyze-level
POST /api/v1/ai/recommend
```

MVP 只需要实现：

```text
explain-word
generate-quiz
```

### 10.11 核心 API 总清单

```text
POST /api/v1/auth/register
POST /api/v1/auth/login

GET  /api/v1/home

POST /api/v1/children
GET  /api/v1/children

GET  /api/v1/books
GET  /api/v1/books/{book_id}

GET  /api/v1/words/{word}

POST /api/v1/reading/sessions
POST /api/v1/reading/events
POST /api/v1/reading/sessions/{session_id}/finish

GET  /api/v1/books/{book_id}/quiz
POST /api/v1/quiz/attempt

GET  /api/v1/children/{child_id}/words
```

---

## 11. AI 服务设计

### 11.1 AI Gateway

一定要做 **AI Gateway**，不要在 Flutter 里直接调用 OpenAI / DeepSeek。

错误：

```text
Flutter
   ↓
OpenAI
```

正确：

```text
Flutter
   ↓
FastAPI
   ↓
AI Gateway
   ↓
OpenAI / DeepSeek / 其他模型
```

这样以后换模型非常容易，所有 API Key 只存在后端。

### 11.2 Provider 抽象

```python
class AIProvider:
    async def generate(self, prompt: str):
        raise NotImplementedError
```

实现：

```text
OpenAIProvider
DeepSeekProvider
MockProvider
```

开发阶段可设置 `MOCK_AI=true`，不消耗 API。

配置：

```text
AI_PROVIDER=mock
```

默认使用 MockProvider。

### 11.3 AI 服务设计清单

```text
explain_word
generate_quiz
generate_story
analyze_level
```

但 **MVP 只实现**：

```text
explain_word
generate_quiz
```

AI 输出优先使用**结构化 JSON**。

解释策略：`explain_word` 只在词是"新词或低掌握度"时调用；已掌握的词直接用本地词汇表轻提示，减少 AI 调用并避免过度解释。判断是否已掌握时先做词形还原（按 `lemma` 判断）。

### 11.4 AI 单词解释 Prompt 示例

```text
You are an English teacher for a Chinese Grade 3 student.

Word:
cute

Context:
The dog is very cute.

Return JSON only:

{
  "meaning_zh": "...",
  "simple_definition": "...",
  "example": "...",
  "example_translation": "..."
}

Rules:
1. Use very simple English.
2. Chinese explanation should be suitable for a 9-year-old child.
3. Do not use difficult words in the definition.
4. Keep the response short.
```

输出：

```json
{
  "meaning_zh": "可爱的",
  "simple_definition": "nice and lovely",
  "example": "The dog is cute.",
  "example_translation": "这只狗很可爱。"
}
```

### 11.5 AI 接口返回结构

`explain_word` 返回：

```text
word
phonetic
meaning_zh
simple_definition
example
example_translation
```

`generate_quiz` 返回：

```text
question
options
correct_option
```

---

## 12. 项目目录结构

### 12.1 仓库根目录

```text
readingmaster/
│
├── README.md
├── docker-compose.yml
├── .env.example
│
├── apps/
│   │
│   ├── mobile/
│   │   └── Flutter project
│   │
│   └── backend/
│       ├── app/
│       │   ├── main.py
│       │   │
│       │   ├── api/
│       │   │   ├── auth.py
│       │   │   ├── children.py
│       │   │   ├── books.py
│       │   │   ├── reading.py
│       │   │   ├── words.py
│       │   │   ├── quiz.py
│       │   │   └── ai.py
│       │   │
│       │   ├── models/
│       │   │   ├── user.py
│       │   │   ├── child.py
│       │   │   ├── book.py
│       │   │   ├── word.py
│       │   │   └── reading.py
│       │   │
│       │   ├── schemas/
│       │   │
│       │   ├── services/
│       │   │   ├── auth_service.py
│       │   │   ├── book_service.py
│       │   │   ├── word_service.py
│       │   │   ├── reading_service.py
│       │   │   └── recommendation_service.py
│       │   │
│       │   ├── ai/
│       │   │   ├── base.py
│       │   │   ├── openai_provider.py
│       │   │   ├── deepseek_provider.py
│       │   │   └── prompts/
│       │   │
│       │   ├── db/
│       │   │
│       │   └── core/
│       │
│       ├── tests/
│       └── requirements.txt
│
├── database/
│   ├── migrations/
│   └── seed/
│
├── docs/
│   ├── PRD.md
│   ├── API.md
│   ├── DATABASE.md
│   └── DEVELOPMENT.md
│
└── scripts/
    ├── dev.sh
    └── seed.sh
```

### 12.2 Flutter 目录

```text
mobile/lib/
│
├── main.dart
│
├── core/
│   ├── network/
│   ├── storage/
│   ├── theme/
│   └── router/
│
├── models/
│   ├── child.dart
│   ├── book.dart
│   ├── word.dart
│   └── quiz.dart
│
├── services/
│   ├── api_service.dart
│   ├── auth_service.dart
│   └── audio_service.dart
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── bookshelf/
│   ├── reader/
│   ├── vocabulary/
│   ├── quiz/
│   └── parent/
│
└── widgets/
    ├── book_card.dart
    ├── word_popup.dart
    └── progress_bar.dart
```

### 12.3 Flutter 必做页面

```text
LoginPage
HomePage
BookshelfPage
ReaderPage
WordPopup
QuizPage
QuizResultPage
VocabularyPage
ParentDashboardPage
```

### 12.4 工程原则

1. 使用清晰的模块化架构。
2. 不要把所有代码写进一个文件。
3. API、Service、Model、Schema 分离。
4. Flutter 页面、Model、Service 分离。
5. 使用环境变量管理配置。
6. 不允许把 API Key 写死在代码中。
7. 数据库使用 migration。
8. 所有重要 API 编写测试。
9. 所有核心业务逻辑编写单元测试。
10. MVP 优先，不要提前实现未来功能。
11. 不要为了所谓"架构先进"引入不必要的复杂框架。
12. 所有接口使用 `/api/v1` 前缀。
13. API 返回 JSON。
14. 错误返回统一格式。
15. README 必须能够指导开发者从零启动项目。
16. 核心阅读链路离线优先：故事正文与已查词解释做本地缓存，弱网/无网仍能读。

---

## 13. 内容管理方式

第一版**不开发 CMS**，先用 JSON / 数据库 seed。

```json
{
  "title": "The Little Dog",
  "level": "LEVEL_2",
  "category": "animals",
  "pages": [
    {
      "page_no": 1,
      "content": "Tom has a little dog."
    },
    {
      "page_no": 2,
      "content": "The dog is very cute."
    },
    {
      "page_no": 3,
      "content": "Tom likes to play with his dog."
    }
  ]
}
```

等真的有人用了，再做后台 CMS。

---

## 14. 第一批测试内容

一开始不要做 100 本书，先做 **10 本**：

```text
3 本 Level 1
4 本 Level 2
3 本 Level 3
```

主题：

```text
🐶 动物
🐱 宠物
🏫 学校
👨‍👩‍👧 家庭
⚽ 运动
🌳 公园
🦖 恐龙
🚀 太空
🍎 食物
🎂 生日
```

数量足够实际测试（例如给弟弟用）即可。

---

## 15. 完整故事示例

**The Little Dog**

```text
Page 1: Tom has a little dog.
重点词：little, dog

Page 2: The dog is very cute.
重点词：cute

Page 3: Tom likes to play with his dog.
重点词：play

Page 4: One day, the dog runs away.
重点词：day, run, away

Page 5: Tom looks for his dog.
重点词：look, for

Page 6: He finds the dog under a tree.
重点词：find, under, tree

Page 7: Tom is very happy.
重点词：happy

Page 8: The little dog goes home with Tom.
重点词：home
```

配 **5 道理解题**。

---

## 16. 第一版最重要的数据指标

以后千万不要只看注册人数。对这个产品更重要的是：

### 1. 首次阅读完成率

```text
开始阅读
↓
读完整本
```

目标：**60%**

### 2. 第二本阅读率

第一个故事读完以后，有没有主动点第二本？这个指标甚至比注册量重要。

### 3. 单词点击率

```text
遇到生词
↓
点击
```

可以知道产品的单词交互到底有没有用。

### 4. 7 日留存

孩子有没有第二天继续读。

### 5. 每周阅读时长

例如：53 分钟 / 周

---

## 17. MVP 验证标准

给自己定一个非常简单的目标：

> **让弟弟连续使用 7 天。**

如果 7 天后：

```text
主动打开
+
主动选择故事
+
主动读完
+
愿意继续读
```

那么这个项目就值得继续。

如果他第一天用了"还行"，第二天"不想用了"，那**不要急着加 AI**，应该先解决：

> 为什么孩子不愿意读。

---

## 18. 产品演化路径

```text
第一阶段：
英文电子书 + 点击查词

↓

第二阶段：
英文电子书 + 查词 + 生词本 + 阅读理解

↓

第三阶段：
分级阅读 + 个性化推荐 + 学习数据

↓

第四阶段：
AI生成内容 + AI陪读 + AI语音 + 个性化学习

↓

最终：
每个孩子都有一个属于自己的 AI 英语阅读老师
```

但这个终局现在不要急着做。现在真正要做的，是**把"阅读器"这一件事情做到足够好**。

---

## 19. 开发阶段规划（Phase 0 ~ 7）

> 不要把整份需求一次性扔给 AI 让它"帮我开发整个 App"，否则很容易得到一个"能运行但代码非常乱"的项目。必须分阶段推进，不要跳阶段。

### Phase 0：项目初始化

目标：

```text
Flutter Web-first + FastAPI + PostgreSQL + Docker
```

必须实现：

```text
docker compose up
```

然后：

```text
GET /health
```

返回：

```json
{
  "status": "ok"
}
```

### Phase 1：数据库

实现：

```text
users
children
books
book_pages
words
book_words
reading_sessions
reading_events
user_words
quiz
```

并生成 **Alembic migrations**。

### Phase 2：后端基础 API

实现：

```text
/auth
/children
/books
/words
/reading
/quiz
```

要求：

```text
Pydantic
SQLAlchemy
JWT
Swagger
单元测试
```

### Phase 3：Flutter Web 基础页面（响应式）

实现：

```text
Login
Home
Bookshelf
Reader
WordPopup
Quiz
Vocabulary
Parent
```

先不用 AI。

### Phase 4：阅读核心闭环

必须真正跑通：

```text
进入书籍
 ↓
开始 session
 ↓
翻页
 ↓
点击单词
 ↓
查询单词
 ↓
播放音频
 ↓
记录 event
 ↓
读完
 ↓
Quiz
 ↓
结果
 ↓
生词
```

这一步完成后，**MVP 核心闭环成立**。

### Phase 5：AI

加入：

```text
AI 单词解释
AI Quiz
AI 内容生成
```

### Phase 6：推荐

根据以下维度推荐下一本书：

```text
reading_level
completion_rate
quiz_score
word_mastery
category_preference
```

### Phase 7：优化

再考虑：

```text
动画
游戏化
AI陪读（逐词高亮、影子跟读）
云 TTS（Azure / Google）
AI口语
个性化故事
```

---

## 20. AI Coding Agent 工作方式

### 20.1 项目启动总控 Prompt

下面这段可以直接作为项目启动 Prompt 发给 DeepSeek / Claude Code / OpenCode：

```text
你现在是一名资深全栈工程师、Flutter 工程师、Python 后端工程师和产品工程师。

我要开发一个名为 ReadingMaster（中文名暂定"阅读王"）的儿童英语分级阅读 App。

====================
一、产品定位
====================

ReadingMaster 是一个面向小学阶段儿童，尤其是小学三年级左右孩子的 AI 英语分级阅读产品。

核心理念：
不是做一个英语词典，也不是做一个聊天机器人。
而是做："一个会陪孩子读英语的智能阅读器。"

核心学习闭环：
选择适合自己的英文故事
→ 阅读
→ 点击不会的单词
→ 查看中文意思、简单英文解释、发音、例句
→ 继续阅读
→ 完成故事
→ 完成 3~5 道阅读理解题
→ 自动记录生词
→ 复习
→ 推荐下一本适合的故事

====================
二、MVP 范围
====================

第一版必须实现：
1. 用户注册/登录
2. Parent / Child 两种角色
3. 创建儿童资料
4. 儿童年级
5. 儿童阅读等级
6. 首页
7. 书架
8. 英文故事阅读
9. 点击单词
10. 单词中文解释
11. 简单英文解释
12. 音标
13. 发音
14. 收藏单词
15. 阅读进度
16. 阅读 session
17. 阅读行为记录
18. 阅读完成
19. 3~5 道阅读理解
20. 阅读结果
21. 生词本
22. 简单复习
23. 家长阅读数据

第一版暂时不要实现：
1. AI聊天
2. AI陪读
3. AI口语评分
4. 社交
5. 排行榜
6. 积分商城
7. 复杂游戏化
8. 支付
9. 学校管理
10. 复杂推荐模型

====================
三、技术栈
====================

前端：Flutter（MVP 优先 Web）

后端：Python 3.11+、FastAPI、SQLAlchemy、Pydantic、Alembic

数据库：PostgreSQL

缓存：Redis

部署：Docker Compose

AI：设计 AI Gateway，必须支持 Provider 抽象：
AIProvider
OpenAIProvider
DeepSeekProvider
MockProvider

不要在 Flutter 客户端直接调用任何 AI API。
所有 AI API Key 必须只存在后端。

====================
四、工程原则
====================

1. 使用清晰的模块化架构。
2. 不要把所有代码写进一个文件。
3. API、Service、Model、Schema 分离。
4. Flutter 页面、Model、Service 分离。
5. 使用环境变量管理配置。
6. 不允许把 API Key 写死在代码中。
7. 数据库使用 migration。
8. 所有重要 API 编写测试。
9. 所有核心业务逻辑编写单元测试。
10. MVP 优先，不要提前实现未来功能。
11. 不要为了所谓"架构先进"引入不必要的复杂框架。
12. 所有接口使用 /api/v1 前缀。
13. API 返回 JSON。
14. 错误返回统一格式。
15. README 必须能够指导开发者从零启动项目。

====================
五、数据库
====================

至少实现以下表：
users
children
books
book_pages
words
book_words
reading_sessions
reading_events
user_words
quiz_questions
quiz_options
quiz_attempts

其中 user_words 非常重要，需要记录：
encounter_count
click_count
audio_count
correct_count
wrong_count
mastery_score
last_seen_at

reading_events 至少支持：
PAGE_VIEW
WORD_CLICK
WORD_AUDIO
WORD_MEANING
BOOKMARK
PAGE_FINISH
BOOK_FINISH

====================
六、核心 API
====================

POST /api/v1/auth/register
POST /api/v1/auth/login
GET  /api/v1/home
POST /api/v1/children
GET  /api/v1/children
GET  /api/v1/books
GET  /api/v1/books/{book_id}
GET  /api/v1/words/{word}
POST /api/v1/reading/sessions
POST /api/v1/reading/events
POST /api/v1/reading/sessions/{session_id}/finish
GET  /api/v1/books/{book_id}/quiz
POST /api/v1/quiz/attempt
GET  /api/v1/children/{child_id}/words

====================
七、Flutter 页面
====================

至少实现：
LoginPage
HomePage
BookshelfPage
ReaderPage
WordPopup
QuizPage
QuizResultPage
VocabularyPage
ParentDashboardPage

核心用户路径：
Login → Home → Book → Reader → WordPopup → Quiz → Result → Vocabulary

====================
八、阅读器要求
====================

阅读器是整个产品最核心的页面，必须支持：
1. 页面内容
2. 翻页
3. 阅读进度
4. 点击单词
5. 单词查询
6. 发音
7. 收藏
8. session
9. event tracking

第一版不要做复杂富文本编辑器。
优先保证：稳定、简单、清晰、适合儿童阅读。

====================
九、AI Gateway
====================

设计如下：
class AIProvider:
    async def generate(...):
        ...

实现：OpenAIProvider、DeepSeekProvider、MockProvider

AI 服务至少设计：explain_word、generate_quiz、generate_story、analyze_level
但是 MVP 只实现：explain_word、generate_quiz

AI 输出必须优先使用结构化 JSON。

====================
十、儿童体验原则
====================

不要给儿童展示复杂的技术信息。
不要使用复杂英文解释。

例如：
错误：cute: pleasing or appealing in an endearing way
正确：cute: nice and lovely
中文：可爱的

UI 要：简单、大字体、少文字、明显按钮、适当动画、避免考试感

====================
十一、开发顺序
====================

Phase 0: 项目初始化
Phase 1: 数据库
Phase 2: Backend API
Phase 3: Flutter UI
Phase 4: 阅读闭环
Phase 5: AI
Phase 6: 推荐
Phase 7: 优化

不要跳过阶段。

每完成一个阶段：
1. 总结修改内容
2. 列出新增文件
3. 列出修改文件
4. 提供运行方法
5. 提供测试方法
6. 检查是否存在未完成 TODO
7. 不要擅自进入下一阶段

====================
十二、开发规则
====================

当你准备修改代码时：
1. 先检查当前项目结构。
2. 不要假设文件存在。
3. 不要重复创建已有模块。
4. 优先复用现有代码。
5. 修改前说明计划。
6. 修改后运行测试。
7. 如果测试失败，先修复再继续。
8. 不要为了通过测试删除测试。
9. 不要修改与当前任务无关的代码。
10. 不要一次修改整个项目。

====================
十三、第一阶段任务
====================

现在只执行 Phase 0。

目标：建立
readingmaster/
apps/mobile/
apps/backend/
database/
docs/
scripts/

实现：
1. Flutter 项目
2. FastAPI 项目
3. Docker Compose
4. PostgreSQL
5. Redis
6. .env.example
7. README
8. /health API

要求：
执行 docker compose up 后，Backend 可以访问 GET /health 返回：
{
    "status": "ok"
}

Flutter Web 项目可以正常启动，并在 iPad Safari 中访问。

不要实现其他业务功能。
完成后停止，等待下一步指令。
```

### 20.2 阶段 Prompt 模板

总控 Prompt 之后，按阶段一个个发。

#### Phase 1 Prompt

```text
现在开始执行 Phase 1：数据库。

要求：
1. 检查当前项目。
2. 创建 SQLAlchemy Models。
3. 创建 Alembic migration。
4. 实现以下表：
users
children
books
book_pages
words
book_words
reading_sessions
reading_events
user_words
quiz_questions
quiz_options
quiz_attempts

5. 添加合理的：Primary Key、Foreign Key、Unique、Index、Not Null

6. 创建 seed 数据，至少创建：
Parent: test@example.com
Child: 小明, Grade 3, Level 2
Book: The Little Dog, 至少 3 个页面
单词：little, dog, cute, play
至少 3 道 Quiz

完成后：
1. 执行 migration
2. 执行 seed
3. 检查数据库
4. 编写测试
5. 更新 README

不要实现 API。
```

#### Phase 2 Prompt

```text
现在开始 Phase 2：Backend API。

实现：Auth、Children、Home、Books、Words、Reading、Quiz、Vocabulary
统一使用 /api/v1

要求：
1. FastAPI Router
2. Pydantic Schema
3. Service Layer
4. SQLAlchemy
5. JWT
6. 参数校验
7. 错误处理
8. Swagger
9. pytest

必须测试：
注册、登录、创建孩子、获取首页、获取书籍、获取单词、
创建阅读 session、记录 WORD_CLICK、完成阅读、
获取 Quiz、提交 Quiz、获取生词

完成后运行全部测试。
不要开发 Flutter。
```

#### Phase 3 Prompt

```text
现在开始 Phase 3：Flutter Web UI（响应式，适配 iPad）。

实现：
LoginPage
HomePage
BookshelfPage
ReaderPage
WordPopup
QuizPage
QuizResultPage
VocabularyPage
ParentDashboardPage

要求：
1. 使用 Material 3。
2. 组件化。
3. API Service 独立。
4. Model 独立。
5. 不把 API 请求直接写在 Widget UI 中。
6. 添加 loading 状态。
7. 添加 error 状态。
8. 添加 empty 状态。
9. 页面适合小学三年级儿童。
10. 大字体。
11. 操作简单。
12. 避免复杂 UI。

先使用真实 Backend API。
不要实现 AI。
```

#### Phase 4 Prompt

```text
现在开始 Phase 4：实现完整阅读闭环。

目标：
Login → Home → Book → Start Reading → Reader → Click Word
→ Word Popup → Audio → Continue Reading → Finish
→ Quiz → Result → Vocabulary

重点实现：
1. ReadingSession
2. ReadingEvent
3. WORD_CLICK
4. WORD_AUDIO
5. WORD_MEANING
6. BOOK_FINISH
7. UserWord 自动创建
8. encounter_count
9. click_count
10. audio_count
11. quiz correct_count
12. quiz wrong_count
13. mastery_score

要求：
必须实际运行完整流程。
完成后写一个 integration test，模拟一个孩子完成一本书。

不要实现推荐算法。
```

#### Phase 5 Prompt

```text
现在开始 Phase 5：AI。

首先实现 AI Gateway。
接口：AIProvider
实现：MockProvider、OpenAIProvider、DeepSeekProvider
配置：AI_PROVIDER=mock，默认使用 MockProvider。

实现：
POST /api/v1/ai/explain-word
POST /api/v1/ai/generate-quiz

要求：
AI 输出必须结构化。

explain_word 返回：word, phonetic, meaning_zh, simple_definition, example, example_translation
generate_quiz 返回：question, options, correct_option

所有 API Key 使用环境变量。
禁止把 API Key 放到 Flutter。
添加 mock 测试。

完成后再实现真实 Provider。
```

### 20.3 阶段完成检查清单

每完成一个阶段：

1. 总结修改内容
2. 列出新增文件
3. 列出修改文件
4. 提供运行方法
5. 提供测试方法
6. 检查是否存在未完成 TODO
7. 不要擅自进入下一阶段

---

## 21. 实际开发顺序建议

可以直接开一个 Git 仓库，然后：

```text
Step 1:  创建 ReadingMaster 项目
Step 2:  把上面的"总控 Prompt"给 DeepSeek / Claude Code / OpenCode
Step 3:  只让它完成 Phase 0
Step 4:  检查代码
Step 5:  让它完成 Phase 1
Step 6:  Phase 2
Step 7:  Phase 3
Step 8:  Phase 4
Step 9:  部署 Web 预览并在 iPad Safari 中给弟弟使用；Android 真机验证通过后再生成 APK
Step 10: 根据真实反馈再决定 Phase 5
```

尤其不要让 AI 一口气把 Phase 0～7 全写完。对这种产品，分阶段让 Coding Agent 工作，质量会明显高很多。

### 服务器问题

开发第一阶段**不需要先买正式服务器**。本地 Docker 跑 PostgreSQL + Redis + FastAPI 就可以把 MVP 开起来；等弟弟实际使用、确定产品值得继续，再部署云服务器。这样能避免一开始就把时间和钱花在基础设施上。

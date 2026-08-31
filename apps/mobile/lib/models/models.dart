class AuthUser {
  const AuthUser({required this.id, required this.email, required this.role});

  final String id;
  final String email;
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'].toString(),
      email: json['email'].toString(),
      role: json['role'].toString(),
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['access_token'].toString(),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class Child {
  const Child({
    required this.id,
    required this.parentId,
    required this.name,
    this.grade,
    this.readingLevel,
    required this.vocabularySize,
  });

  final String id;
  final String parentId;
  final String name;
  final int? grade;
  final String? readingLevel;
  final int vocabularySize;

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'].toString(),
      parentId: json['parent_id'].toString(),
      name: json['name'].toString(),
      grade: json['grade'] as int?,
      readingLevel: json['reading_level'] as String?,
      vocabularySize: (json['vocabulary_size'] as num?)?.toInt() ?? 0,
    );
  }
}

class Book {
  const Book({
    required this.id,
    required this.title,
    this.description,
    required this.level,
    this.estimatedMinutes,
    this.wordCount,
    this.category,
    this.status,
    this.contentPreview,
  });

  final String id;
  final String title;
  final String? description;
  final String level;
  final int? estimatedMinutes;
  final int? wordCount;
  final String? category;
  final String? status;
  final String? contentPreview;

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'].toString(),
      title: json['title'].toString(),
      description: json['description'] as String?,
      level: json['level'].toString(),
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
      wordCount: (json['word_count'] as num?)?.toInt(),
      category: json['category'] as String?,
      status: json['status'] as String?,
      contentPreview: json['content_preview'] as String?,
    );
  }
}

class BookPageModel {
  const BookPageModel({
    required this.pageNo,
    required this.content,
    this.imageUrl,
  });

  final int pageNo;
  final String content;
  final String? imageUrl;

  factory BookPageModel.fromJson(Map<String, dynamic> json) {
    return BookPageModel(
      pageNo: (json['page_no'] as num).toInt(),
      content: json['content'].toString(),
      imageUrl: json['image_url'] as String?,
    );
  }
}

class BookChapter {
  const BookChapter({
    required this.index,
    required this.title,
    required this.wordCount,
    required this.segmentCount,
  });

  final int index;
  final String title;
  final int wordCount;
  final int segmentCount;

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      index: (json['index'] as num).toInt(),
      title: json['title'].toString(),
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      segmentCount: (json['segment_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class BookChapterDetail {
  const BookChapterDetail({
    required this.index,
    required this.title,
    required this.segments,
  });

  final int index;
  final String title;
  final List<BookPageModel> segments;

  factory BookChapterDetail.fromJson(Map<String, dynamic> json) {
    return BookChapterDetail(
      index: (json['index'] as num).toInt(),
      title: json['title'].toString(),
      segments: (json['segments'] as List<dynamic>)
          .map((item) => BookPageModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
class BookDetail {
  const BookDetail({
    required this.id,
    required this.title,
    this.description,
    required this.level,
    this.estimatedMinutes,
    this.wordCount,
    this.category,
    required this.chapters,
  });

  final String id;
  final String title;
  final String? description;
  final String level;
  final int? estimatedMinutes;
  final int? wordCount;
  final String? category;
  final List<BookChapter> chapters;

  factory BookDetail.fromJson(Map<String, dynamic> json) {
    return BookDetail(
      id: json['id'].toString(),
      title: json['title'].toString(),
      description: json['description'] as String?,
      level: json['level'].toString(),
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
      wordCount: (json['word_count'] as num?)?.toInt(),
      category: json['category'] as String?,
      chapters: (json['chapters'] as List<dynamic>)
          .map((item) => BookChapter.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ParsedChapter {
  const ParsedChapter({required this.title, required this.content});

  final String title;
  final String content;

  factory ParsedChapter.fromJson(Map<String, dynamic> json) {
    return ParsedChapter(
      title: json['title'].toString(),
      content: json['content'].toString(),
    );
  }
}

class ParsedBook {
  const ParsedBook({required this.chapters});

  final List<ParsedChapter> chapters;

  factory ParsedBook.fromJson(Map<String, dynamic> json) {
    return ParsedBook(
      chapters: (json['chapters'] as List<dynamic>)
          .map((item) => ParsedChapter.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
class Word {
  const Word({
    required this.word,
    this.phonetic,
    this.meaningZh,
    this.simpleDefinition,
    this.exampleSentence,
    this.exampleTranslation,
    this.audioUrl,
    this.partOfSpeech,
  });

  final String word;
  final String? phonetic;
  final String? meaningZh;
  final String? simpleDefinition;
  final String? exampleSentence;
  final String? exampleTranslation;
  final String? audioUrl;
  final String? partOfSpeech;

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'].toString(),
      phonetic: json['phonetic'] as String?,
      meaningZh: json['meaning_zh'] as String?,
      simpleDefinition: json['simple_definition'] as String?,
      exampleSentence: json['example_sentence'] as String?,
      exampleTranslation: json['example_translation'] as String?,
      audioUrl: json['audio_url'] as String?,
      partOfSpeech: json['part_of_speech'] as String?,
    );
  }
}

class UserWord {
  const UserWord({required this.word, required this.masteryScore, required this.clickCount});

  final Word word;
  final double masteryScore;
  final int clickCount;

  factory UserWord.fromJson(Map<String, dynamic> json) {
    return UserWord(
      word: Word.fromJson(json['word'] as Map<String, dynamic>),
      masteryScore: (json['mastery_score'] as num?)?.toDouble() ?? 0,
      clickCount: (json['click_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReviewWord {
  const ReviewWord({
    required this.wordId,
    required this.word,
    this.phonetic,
    this.meaningZh,
    this.simpleDefinition,
    this.exampleSentence,
    this.exampleTranslation,
    this.partOfSpeech,
    this.cloze,
  });

  final String wordId;
  final String word;
  final String? phonetic;
  final String? meaningZh;
  final String? simpleDefinition;
  final String? exampleSentence;
  final String? exampleTranslation;
  final String? partOfSpeech;
  final String? cloze;

  factory ReviewWord.fromJson(Map<String, dynamic> json) {
    return ReviewWord(
      wordId: json['word_id'].toString(),
      word: json['word'].toString(),
      phonetic: json['phonetic'] as String?,
      meaningZh: json['meaning_zh'] as String?,
      simpleDefinition: json['simple_definition'] as String?,
      exampleSentence: json['example_sentence'] as String?,
      exampleTranslation: json['example_translation'] as String?,
      partOfSpeech: json['part_of_speech'] as String?,
      cloze: json['cloze'] as String?,
    );
  }
}

class ReviewResult {
  const ReviewResult({
    required this.wordId,
    required this.reviewStage,
    required this.mastered,
    this.nextReviewAt,
  });

  final String wordId;
  final int reviewStage;
  final bool mastered;
  final String? nextReviewAt;

  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    return ReviewResult(
      wordId: json['word_id'].toString(),
      reviewStage: (json['review_stage'] as num?)?.toInt() ?? 0,
      mastered: json['mastered'] as bool? ?? false,
      nextReviewAt: json['next_review_at'] as String?,
    );
  }
}

class AttentionWord {
  const AttentionWord({required this.word, this.meaningZh});

  final String word;
  final String? meaningZh;

  factory AttentionWord.fromJson(Map<String, dynamic> json) {
    return AttentionWord(
      word: json['word'].toString(),
      meaningZh: json['meaning_zh'] as String?,
    );
  }
}

class ParentStats {
  const ParentStats({
    required this.childName,
    this.childLevel,
    this.grade,
    required this.booksRead,
    required this.readingMinutes,
    required this.newWords,
    required this.quizAccuracy,
    required this.wordMastery,
    required this.attentionWords,
  });

  final String childName;
  final String? childLevel;
  final int? grade;
  final int booksRead;
  final int readingMinutes;
  final int newWords;
  final double quizAccuracy;
  final double wordMastery;
  final List<AttentionWord> attentionWords;

  factory ParentStats.fromJson(Map<String, dynamic> json) {
    final child = json['child'] as Map<String, dynamic>? ?? const {};
    final weekly = json['weekly'] as Map<String, dynamic>? ?? const {};
    final attention = json['attention_words'] as List<dynamic>? ?? const [];
    return ParentStats(
      childName: child['name']?.toString() ?? '',
      childLevel: child['level'] as String?,
      grade: (child['grade'] as num?)?.toInt(),
      booksRead: (weekly['books_read'] as num?)?.toInt() ?? 0,
      readingMinutes: (weekly['reading_minutes'] as num?)?.toInt() ?? 0,
      newWords: (weekly['new_words'] as num?)?.toInt() ?? 0,
      quizAccuracy: (json['quiz_accuracy'] as num?)?.toDouble() ?? 0,
      wordMastery: (json['word_mastery'] as num?)?.toDouble() ?? 0,
      attentionWords: attention
          .map((item) => AttentionWord.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReadingSession {
  const ReadingSession({
    required this.id,
    required this.childId,
    required this.bookId,
    required this.progress,
    required this.completed,
  });

  final String id;
  final String childId;
  final String bookId;
  final double progress;
  final bool completed;

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      id: json['id'].toString(),
      childId: json['child_id'].toString(),
      bookId: json['book_id'].toString(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

class QuizOption {
  const QuizOption({required this.key, required this.content});

  final String key;
  final String content;

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      key: json['option_key'].toString(),
      content: json['content'].toString(),
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.chapterIndex,
    this.chapterTitle,
  });

  final String id;
  final String question;
  final List<QuizOption> options;
  final int? chapterIndex;
  final String? chapterTitle;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'].toString(),
      question: json['question'].toString(),
      options: (json['options'] as List<dynamic>)
          .map((item) => QuizOption.fromJson(item as Map<String, dynamic>))
          .toList(),
      chapterIndex: (json['chapter_index'] as num?)?.toInt(),
      chapterTitle: json['chapter_title'] as String?,
    );
  }
}

class QuizAttempt {
  const QuizAttempt({required this.isCorrect, this.correctOption});

  final bool? isCorrect;
  final String? correctOption;

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      isCorrect: json['is_correct'] as bool?,
      correctOption: json['correct_option'] as String?,
    );
  }
}

class RecommendedBook {
  const RecommendedBook({
    required this.id,
    required this.title,
    required this.level,
    this.estimatedMinutes,
  });

  final String id;
  final String title;
  final String level;
  final int? estimatedMinutes;

  factory RecommendedBook.fromJson(Map<String, dynamic> json) {
    return RecommendedBook(
      id: json['id'].toString(),
      title: json['title'].toString(),
      level: json['level'].toString(),
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
    );
  }
}

class ContinueReading {
  const ContinueReading({
    required this.id,
    required this.bookId,
    required this.title,
    required this.progress,
  });

  final String id;
  final String bookId;
  final String title;
  final double progress;

  factory ContinueReading.fromJson(Map<String, dynamic> json) {
    return ContinueReading(
      id: json['id'].toString(),
      bookId: json['book_id'].toString(),
      title: json['title'].toString(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HomeData {
  const HomeData({
    required this.childName,
    this.childLevel,
    this.recommendedBook,
    this.continueReading = const [],
    this.readingMinutes = 0,
    this.newWords = 0,
  });

  final String childName;
  final String? childLevel;
  final RecommendedBook? recommendedBook;
  final List<ContinueReading> continueReading;
  final int readingMinutes;
  final int newWords;

  factory HomeData.fromJson(Map<String, dynamic> json) {
    final child = json['child'] as Map<String, dynamic>? ?? const {};
    final recommended = json['recommended_book'] as Map<String, dynamic>?;
    final today = json['today'] as Map<String, dynamic>? ?? const {};
    final continueList = json['continue_reading'] as List<dynamic>? ?? [];

    return HomeData(
      childName: child['name']?.toString() ?? '',
      childLevel: child['level'] as String?,
      recommendedBook: recommended == null ? null : RecommendedBook.fromJson(recommended),
      continueReading: continueList
          .map((item) => ContinueReading.fromJson(item as Map<String, dynamic>))
          .toList(),
      readingMinutes: (today['reading_minutes'] as num?)?.toInt() ?? 0,
      newWords: (today['new_words'] as num?)?.toInt() ?? 0,
    );
  }
}

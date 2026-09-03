import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/models.dart';

class ApiService {
  Future<dynamic> _cachedJson(
    String key,
    Future<dynamic> Function() fetch,
  ) async {
    try {
      final data = await fetch();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      return data;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(key);
      if (cached != null) return jsonDecode(cached);
      rethrow;
    }
  }
  Future<AuthSession> login(String email, String password) async {
    final data = await ApiClient.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthSession> register(String email, String password) async {
    final data = await ApiClient.post(
      '/api/v1/auth/register',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Child>> getChildren() async {
    final data = await ApiClient.get('/api/v1/children');
    return (data as List<dynamic>)
        .map((item) => Child.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Child> createChild({
    required String name,
    int? grade,
    String? readingLevel,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/children',
      body: {
        'name': name,
        'grade': ?grade,
        'reading_level': ?readingLevel,
      },
    );
    return Child.fromJson(data as Map<String, dynamic>);
  }

  Future<HomeData> getHome(String childId) async {
    final data = await ApiClient.get('/api/v1/home?child_id=$childId');
    return HomeData.fromJson(data as Map<String, dynamic>);
  }

  Future<Book> createBook({
    required String title,
    required String level,
    String? description,
    String? category,
    int? estimatedMinutes,
    required String content,
    List<Map<String, dynamic>> questions = const [],
  }) async {
    final data = await ApiClient.post(
      '/api/v1/books',
      body: {
        'title': title,
        'level': level,
        'description': ?description,
        'category': ?category,
        'estimated_minutes': ?estimatedMinutes,
        'content': content,
        'questions': questions,
      },
    );
    return Book.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Book>> getBooks() async {
    final data = await ApiClient.get('/api/v1/books');
    return (data as List<dynamic>)
        .map((item) => Book.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteBook(String bookId) async {
    await ApiClient.delete('/api/v1/books/$bookId');
  }

  Future<BookDetail> getBook(String bookId) async {
    final data = await _cachedJson(
      'cache_book_$bookId',
      () => ApiClient.get('/api/v1/books/$bookId'),
    );
    return BookDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<BookChapterDetail> getChapter(String bookId, int index) async {
    final data = await _cachedJson(
      'cache_chapter_${bookId}_$index',
      () => ApiClient.get('/api/v1/books/$bookId/chapters/$index'),
    );
    return BookChapterDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<List<BookPageModel>> getBookContent(String bookId) async {
    final data = await ApiClient.get('/api/v1/books/$bookId/content');
    return (data as List<dynamic>)
        .map((item) => BookPageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ParsedBook> parseText(String content) async {
    final data = await ApiClient.post(
      '/api/v1/books/preview',
      body: {'content': content},
    );
    return ParsedBook.fromJson(data as Map<String, dynamic>);
  }
  Future<ParsedBook> parseEbook({
    required String filename,
    required List<int> bytes,
  }) async {
    final data = await ApiClient.postMultipart(
      '/api/v1/books/import/parse',
      filename: filename,
      bytes: bytes,
    );
    return ParsedBook.fromJson(data as Map<String, dynamic>);
  }

  Future<ParsedBook> parseOcr(List<Map<String, String>> images) async {
    final data = await ApiClient.post(
      '/api/v1/books/import/ocr',
      body: {'images': images},
    );
    return ParsedBook.fromJson(data as Map<String, dynamic>);
  }

  Future<Book> createBookFromChapters({
    required String title,
    required String level,
    String? description,
    String? category,
    required List<Map<String, String>> chapters,
    List<Map<String, dynamic>> questions = const [],
  }) async {
    final data = await ApiClient.post(
      '/api/v1/books/import',
      body: {
        'title': title,
        'level': level,
        'description': ?description,
        'category': ?category,
        'chapters': chapters,
        'questions': questions,
      },
    );
    return Book.fromJson(data as Map<String, dynamic>);
  }
  Future<Word> getWord(String word) async {
    final data = await ApiClient.get('/api/v1/words/$word');
    return Word.fromJson(data as Map<String, dynamic>);
  }

  Future<List<KeyItem>> extractKeyItems(String text) async {
    final data = await ApiClient.post(
      '/api/v1/ai/key-items',
      body: {'text': text},
    );
    return (data['items'] as List<dynamic>)
        .map((item) => KeyItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<KeyItem>> getChapterKeyItems(String bookId, int chapterIndex) async {
    final data = await ApiClient.get(
      '/api/v1/books/$bookId/chapters/$chapterIndex/key-items',
    );
    return (data['items'] as List<dynamic>)
        .map((item) => KeyItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ReadingSession> startSession({
    required String childId,
    required String bookId,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/reading/sessions',
      body: {'child_id': childId, 'book_id': bookId},
    );
    return ReadingSession.fromJson(data as Map<String, dynamic>);
  }

  Future<void> recordEvent({
    required String sessionId,
    required String eventType,
    int? pageNo,
    String? word,
  }) async {
    await ApiClient.post(
      '/api/v1/reading/events',
      body: {
        'session_id': sessionId,
        'event_type': eventType,
        'page_no': ?pageNo,
        'word': ?word,
      },
    );
  }

  Future<ReadingSession> finishSession({
    required String sessionId,
    required int durationSeconds,
    required double progress,
    required bool completed,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/reading/sessions/$sessionId/finish',
      body: {
        'duration_seconds': durationSeconds,
        'progress': progress,
        'completed': completed,
      },
    );
    return ReadingSession.fromJson(data as Map<String, dynamic>);
  }

  Future<ReadingSession> updateReadingProgress({
    required String sessionId,
    required int durationSeconds,
    required double progress,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/reading/sessions/$sessionId/progress',
      body: {'duration_seconds': durationSeconds, 'progress': progress},
    );
    return ReadingSession.fromJson(data as Map<String, dynamic>);
  }

  Future<Word> explainWordAI(String word, {String? context}) async {
    final data = await ApiClient.post(
      '/api/v1/ai/explain-word',
      body: {
        'word': word,
        'context': ?context,
      },
    );
    return Word.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> generateQuizAI({
    String? bookId,
    String? text,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/ai/generate-quiz',
      body: {
        'book_id': ?bookId,
        'text': ?text,
      },
    );
    return (data['questions'] as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  Future<List<QuizQuestion>> getQuiz(String bookId) async {
    final data = await ApiClient.get('/api/v1/books/$bookId/quiz');
    return (data as List<dynamic>)
        .map((item) => QuizQuestion.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<QuizQuestion> addQuestion(
    String bookId,
    Map<String, dynamic> question,
  ) async {
    final data = await ApiClient.post(
      '/api/v1/books/$bookId/quiz',
      body: question,
    );
    return QuizQuestion.fromJson(data as Map<String, dynamic>);
  }

  Future<QuizAttempt> submitQuiz({
    required String childId,
    required String questionId,
    required String selectedOption,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/quiz/attempt',
      body: {
        'child_id': childId,
        'question_id': questionId,
        'selected_option': selectedOption,
      },
    );
    return QuizAttempt.fromJson(data as Map<String, dynamic>);
  }

  Future<VoiceQuizResult> submitVoiceQuiz({
    required String childId,
    required String questionId,
    required String studentAnswer,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/quiz/voice-attempt',
      body: {
        'child_id': childId,
        'question_id': questionId,
        'student_answer': studentAnswer,
      },
    );
    return VoiceQuizResult.fromJson(data as Map<String, dynamic>);
  }

  Future<ReadAloudResult> judgeReadAloud({
    required String targetSentence,
    required String studentTranscript,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/ai/judge-read-aloud',
      body: {
        'target_sentence': targetSentence,
        'student_transcript': studentTranscript,
      },
    );
    return ReadAloudResult.fromJson(data as Map<String, dynamic>);
  }

  Future<List<UserWord>> getVocabulary(String childId) async {
    final data = await ApiClient.get('/api/v1/children/$childId/words');
    return (data as List<dynamic>)
        .map((item) => UserWord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserWord> setWordFavorite({
    required String childId,
    required String word,
    required bool favorite,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/children/$childId/words/$word/favorite',
      body: {'favorite': favorite},
    );
    return UserWord.fromJson(data as Map<String, dynamic>);
  }

  Future<UserWord?> getUserWord(String childId, String word) async {
    try {
      final data = await ApiClient.get('/api/v1/children/$childId/words/$word');
      return UserWord.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<ReviewWord>> getReviewWords(String childId) async {
    final data = await ApiClient.get('/api/v1/children/$childId/review');
    return (data as List<dynamic>)
        .map((item) => ReviewWord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ReviewResult> submitReview({
    required String childId,
    required String wordId,
    required bool correct,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/children/$childId/review',
      body: {'word_id': wordId, 'correct': correct},
    );
    return ReviewResult.fromJson(data as Map<String, dynamic>);
  }

  Future<ParentStats> getParentStats(String childId) async {
    final data = await ApiClient.get('/api/v1/children/$childId/stats');
    return ParentStats.fromJson(data as Map<String, dynamic>);
  }
}

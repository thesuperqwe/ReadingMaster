import '../core/api_client.dart';
import '../models/models.dart';

class ApiService {
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

  Future<BookDetail> getBook(String bookId) async {
    final data = await ApiClient.get('/api/v1/books/$bookId');
    return BookDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<Word> getWord(String word) async {
    final data = await ApiClient.get('/api/v1/words/$word');
    return Word.fromJson(data as Map<String, dynamic>);
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

  Future<List<UserWord>> getVocabulary(String childId) async {
    final data = await ApiClient.get('/api/v1/children/$childId/words');
    return (data as List<dynamic>)
        .map((item) => UserWord.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

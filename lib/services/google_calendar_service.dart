import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis/tasks/v1.dart' as tasks;
import 'package:http/http.dart' as http;

class GoogleCalendarService {
  GoogleCalendarService._();
  static final GoogleCalendarService instance = GoogleCalendarService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      calendar.CalendarApi.calendarEventsScope,
      tasks.TasksApi.tasksScope,
    ],
  );

  Future<void> signIn() async {
    await _accessToken();
  }

  Future<bool> isSignedIn() => _googleSignIn.isSignedIn();

  Future<List<GoogleCalendarEvent>> todayEvents() async {
    final api = await _calendarApi();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final events = await api.events.list(
      'primary',
      timeMin: start,
      timeMax: end,
      singleEvents: true,
      orderBy: 'startTime',
    );

    return (events.items ?? const <calendar.Event>[])
        .map(GoogleCalendarEvent.fromGoogleEvent)
        .where((event) => event.title.isNotEmpty)
        .toList();
  }

  Future<List<GoogleCalendarEvent>> todayItems() async {
    final results = <GoogleCalendarEvent>[...await todayEvents()];
    try {
      results.addAll(await todayTasks());
    } on Object {
      // Some platforms/accounts do not support the Google Tasks scope yet.
      // Calendar should still work, so Tasks degrade to an empty list.
    }
    results.sort((a, b) {
      final aStart = a.start ?? DateTime(0);
      final bStart = b.start ?? DateTime(0);
      return aStart.compareTo(bStart);
    });
    return results;
  }

  Future<List<GoogleCalendarEvent>> todayTasks() async {
    final api = await _tasksApi();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final taskLists = await api.tasklists.list(maxResults: 100);
    final items = <GoogleCalendarEvent>[];

    for (final list in taskLists.items ?? const <tasks.TaskList>[]) {
      final listId = list.id;
      if (listId == null) continue;
      final page = await api.tasks.list(
        listId,
        dueMin: start.toUtc().toIso8601String(),
        dueMax: end.toUtc().toIso8601String(),
        showCompleted: true,
        showDeleted: false,
        showHidden: false,
        maxResults: 100,
      );
      items.addAll(
        (page.items ?? const <tasks.Task>[])
            .map((task) => GoogleCalendarEvent.fromGoogleTask(
                  task,
                  taskListId: listId,
                ))
            .where((event) => event.title.isNotEmpty),
      );
    }

    return items;
  }

  Future<void> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    final api = await _calendarApi();
    await api.events.insert(
      calendar.Event(
        summary: title,
        start: calendar.EventDateTime(dateTime: start),
        end: calendar.EventDateTime(dateTime: end),
      ),
      'primary',
    );
  }

  Future<void> createTask({
    required String title,
    DateTime? due,
  }) async {
    final api = await _tasksApi();
    await api.tasks.insert(
      tasks.Task(
        title: title,
        due: due?.toUtc().toIso8601String(),
      ),
      '@default',
    );
  }

  Future<void> moveEvent({
    required String id,
    required DateTime start,
    required DateTime end,
  }) async {
    final api = await _calendarApi();
    await api.events.patch(
      calendar.Event(
        start: calendar.EventDateTime(dateTime: start),
        end: calendar.EventDateTime(dateTime: end),
      ),
      'primary',
      id,
    );
  }

  Future<void> moveTask({
    required String taskListId,
    required String id,
    required DateTime due,
  }) async {
    final api = await _tasksApi();
    await api.tasks.patch(
      tasks.Task(due: due.toUtc().toIso8601String()),
      taskListId,
      id,
    );
  }

  Future<calendar.CalendarApi> _calendarApi() async {
    final accessToken = await _accessToken();
    return calendar.CalendarApi(_GoogleAuthClient(accessToken));
  }

  Future<tasks.TasksApi> _tasksApi() async {
    final accessToken = await _accessToken();
    return tasks.TasksApi(_GoogleAuthClient(accessToken));
  }

  Future<String> _accessToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google sign-in cancelled');
    }

    final auth = await account.authentication;
    final accessToken = auth.accessToken;
    if (accessToken == null) {
      throw Exception('Missing Google access token');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: auth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);

    return accessToken;
  }
}

class GoogleCalendarEvent {
  const GoogleCalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    this.isTask = false,
    this.isCompleted = false,
    this.taskListId,
  });

  final String id;
  final String title;
  final DateTime? start;
  final DateTime? end;
  final bool isAllDay;
  final bool isTask;
  final bool isCompleted;
  final String? taskListId;

  GoogleCalendarEvent copyWith({
    DateTime? start,
    DateTime? end,
    bool? isAllDay,
  }) {
    return GoogleCalendarEvent(
      id: id,
      title: title,
      start: start ?? this.start,
      end: end ?? this.end,
      isAllDay: isAllDay ?? this.isAllDay,
      isTask: isTask,
      isCompleted: isCompleted,
      taskListId: taskListId,
    );
  }

  factory GoogleCalendarEvent.fromGoogleEvent(calendar.Event event) {
    return GoogleCalendarEvent(
      id: event.id ?? '',
      title: event.summary ?? '',
      start: _localDateTime(event.start?.dateTime ?? event.start?.date),
      end: _localDateTime(event.end?.dateTime ?? event.end?.date),
      isAllDay: event.start?.date != null && event.start?.dateTime == null,
    );
  }

  factory GoogleCalendarEvent.fromGoogleTask(
    tasks.Task task, {
    String? taskListId,
  }) {
    final due = _localDateTime(
      task.due == null ? null : DateTime.tryParse(task.due!),
    );
    return GoogleCalendarEvent(
      id: task.id ?? '',
      title: task.title ?? '',
      start: due,
      end: due,
      isAllDay: due == null,
      isTask: true,
      isCompleted: task.status == 'completed',
      taskListId: taskListId,
    );
  }
}

DateTime? _localDateTime(DateTime? value) {
  if (value == null) return null;
  return value.isUtc ? value.toLocal() : value;
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this.accessToken);

  final String accessToken;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

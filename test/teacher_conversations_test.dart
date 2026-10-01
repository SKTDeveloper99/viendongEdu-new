// Teacher "Tin nhắn": inbox, thread and "Nhắn sinh viên" picker, driven by a
// fake repository (no network). Fictional people only (THUNGHIEM / TEST26…).
//
//   flutter test test/teacher_conversations_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/core/network/ems_exception.dart';
import 'package:viendongedu2_flutter/data/teacher_conversations_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_conversations/conversation_inbox_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_conversations/conversation_thread_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_conversations/new_conversation_screen.dart';
import 'package:viendongedu2_flutter/models/teacher_conversation_models.dart';
import 'package:viendongedu2_flutter/services/conversation_push_route.dart';

class FakeRepo implements TeacherConversationsRepository {
  Map<String, List<TeacherConversation>> lists = {};
  bool listFresh = true;
  TeacherThread? threadData;
  Object? sendError;
  Object? classesError;
  List<PickerClass> classes = const [];
  final sent = <String>[];
  final resolved = <String>[];

  @override
  Future<CachedConversations> list(
    String status, {
    void Function(List<TeacherConversation> rows, DateTime savedAt)? onStored,
  }) async => (
    data: lists[status] ?? const [],
    savedAt: DateTime(2026, 9, 30, 8, 5),
    fresh: listFresh,
  );

  @override
  Future<TeacherThread> thread(String id) async => threadData!;

  @override
  Future<TeacherMessage?> send(String id, String body) async {
    if (sendError != null) throw sendError!;
    sent.add(body);
    return TeacherMessage(
      id: 'm${sent.length}',
      body: body,
      fromStudent: false,
    );
  }

  @override
  Future<void> resolve(String id) async => resolved.add(id);

  @override
  Future<String> create({
    required String mssv,
    required String message,
    String? subject,
  }) async => '99';

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<List<PickerClass>> currentSemesterClasses() async {
    if (classesError != null) throw classesError!;
    return classes;
  }
}

TeacherConversation _conv(
  String id,
  String name,
  String mssv, {
  bool awaiting = false,
  String status = 'open',
}) => TeacherConversation(
  id: id,
  subject: 'Hỏi về điểm $id',
  status: status,
  studentMssv: mssv,
  studentName: name,
  preview: 'Tin cuối $id',
  lastFromStudent: true,
  awaitingReply: awaiting,
  updatedAt: DateTime(2026, 9, 30, 9, 30),
);

TeacherThread _thread({String status = 'open'}) => TeacherThread(
  _conv('7', 'THUNGHIEM An', 'TEST260001', status: status),
  const [
    TeacherMessage(id: '1', body: 'Em chào thầy', fromStudent: true),
    TeacherMessage(id: '2', body: 'Chào em', fromStudent: false),
  ],
);

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  testWidgets('inbox renders rows, unread dot and tabs', (tester) async {
    final repo = FakeRepo()
      ..lists = {
        'open': [
          _conv('1', 'THUNGHIEM An', 'TEST260001', awaiting: true),
          _conv('2', 'THUNGHIEM Bình', 'TEST260002'),
        ],
        'closed': [_conv('3', 'THUNGHIEM Chi', 'TEST260003', status: 'closed')],
      };
    await tester.pumpWidget(_app(TeacherConversationsScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('THUNGHIEM An · TEST260001'), findsOneWidget);
    expect(find.text('THUNGHIEM Bình · TEST260002'), findsOneWidget);
    expect(find.text('Hỏi về điểm 1'), findsOneWidget);
    expect(find.text('Tin cuối 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);

    await tester.tap(find.text('Đã xong'));
    await tester.pumpAndSettle();
    expect(find.text('THUNGHIEM Chi · TEST260003'), findsOneWidget);
  });

  testWidgets('inbox empty state and stale note', (tester) async {
    final repo = FakeRepo()..listFresh = false;
    await tester.pumpWidget(_app(TeacherConversationsScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có tin nhắn'), findsOneWidget);
    expect(find.textContaining('Chưa cập nhật được'), findsOneWidget);
  });

  testWidgets('thread shows bubbles, send appends message', (tester) async {
    final repo = FakeRepo()..threadData = _thread();
    await tester.pumpWidget(
      _app(ConversationThreadScreen(conversationId: '7', repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Em chào thầy'), findsOneWidget);
    // Student left, teacher right.
    final left = tester.getTopLeft(find.text('Em chào thầy')).dx;
    final right = tester.getTopLeft(find.text('Chào em')).dx;
    expect(right, greaterThan(left));

    await tester.enterText(find.byType(TextField), 'Thầy trả lời sau');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(repo.sent, ['Thầy trả lời sau']);
    expect(find.text('Thầy trả lời sau'), findsOneWidget);
  });

  testWidgets('failed send shows the server message and keeps the draft', (
    tester,
  ) async {
    final repo = FakeRepo()
      ..threadData = _thread()
      ..sendError = EmsException('Không thuộc lớp của bạn', statusCode: 403);
    await tester.pumpWidget(
      _app(ConversationThreadScreen(conversationId: '7', repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Xin chào');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.text('Không thuộc lớp của bạn'), findsOneWidget);
    expect(find.textContaining('Không có kết nối'), findsNothing);
    expect(find.text('Xin chào'), findsOneWidget); // draft kept in the field
  });

  testWidgets('resolve calls PATCH and closes the composer', (tester) async {
    final repo = FakeRepo()..threadData = _thread();
    await tester.pumpWidget(
      _app(ConversationThreadScreen(conversationId: '7', repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đánh dấu đã giải quyết'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();
    expect(repo.resolved, ['7']);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Cuộc trò chuyện đã giải quyết'), findsOneWidget);
  });

  testWidgets('picker dedupes by MSSV, groups by class and searches', (
    tester,
  ) async {
    final repo = FakeRepo()
      ..classes = const [
        PickerClass('a', 'TN261A · Môn A', [
          PickerStudent('TEST260001', 'THUNGHIEM An'),
          PickerStudent('TEST260002', 'THUNGHIEM Bình'),
        ]),
        PickerClass('b', 'TN261B · Môn B', [
          PickerStudent('TEST260001', 'THUNGHIEM An'),
          PickerStudent('TEST260003', 'THUNGHIEM Chi'),
        ]),
      ];
    await tester.pumpWidget(_app(NewConversationScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('TN261A · Môn A'), findsOneWidget);
    expect(find.text('TN261B · Môn B'), findsOneWidget);
    expect(find.text('THUNGHIEM An'), findsOneWidget); // once, not twice
    expect(find.text('THUNGHIEM Chi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'test260003');
    await tester.pumpAndSettle();
    expect(find.text('THUNGHIEM Chi'), findsOneWidget);
    expect(find.text('THUNGHIEM An'), findsNothing);
    expect(find.text('TN261A · Môn A'), findsNothing);

    await tester.enterText(find.byType(TextField), 'bình');
    await tester.pumpAndSettle();
    expect(find.text('THUNGHIEM Bình'), findsOneWidget);
  });

  testWidgets('picker gives a useful safe error for unexpected load failures', (
    tester,
  ) async {
    final repo = FakeRepo()..classesError = StateError('secret backend detail');
    await tester.pumpWidget(_app(NewConversationScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(
      find.text('Không tải được danh sách lớp và sinh viên. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.textContaining('secret backend detail'), findsNothing);
  });

  test('push route /conversations opens the thread for teachers only', () {
    final data = {'route': '/conversations', 'conversation_id': '42'};
    expect(
      conversationPushRoute(data, isTeacher: true),
      '/teacher_conversations/42',
    );
    expect(
      conversationPushRoute({'route': '/conversations'}, isTeacher: true),
      '/teacher_conversations',
    );
    expect(conversationPushRoute(data, isTeacher: false), isNull);
  });
}

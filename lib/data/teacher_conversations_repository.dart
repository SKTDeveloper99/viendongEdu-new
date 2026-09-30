import '../core/network/ems_exception.dart';
import '../models/teacher_conversation_models.dart';
import '../services/crm_teacher_api.dart';
import 'api/teacher_conversations_api.dart';

typedef CachedConversations = ({
  List<TeacherConversation> data,
  DateTime savedAt,
  bool fresh,
});

/// The calls the teacher chat screens make. Tests replace this class with a
/// fake; failures surface as the original exception.
class TeacherConversationsRepository {
  const TeacherConversationsRepository();

  Future<CachedConversations> list(
    String status, {
    void Function(List<TeacherConversation> rows, DateTime savedAt)? onStored,
  }) => TeacherConversationsApi.listCached(status, onStored: onStored);

  Future<TeacherThread> thread(String id) => TeacherConversationsApi.thread(id);

  Future<TeacherMessage?> send(String id, String body) =>
      TeacherConversationsApi.send(id, body);

  Future<void> resolve(String id) => TeacherConversationsApi.resolve(id);

  Future<String> create({
    required String mssv,
    required String message,
    String? subject,
  }) => TeacherConversationsApi.create(
    mssv: mssv,
    message: message,
    subject: subject,
  );

  Future<int> unreadCount() => TeacherConversationsApi.unreadCount();

  /// Students studying under this teacher in the CURRENT semester only:
  /// `current_semester` from `/teacher/me/overview`, that semester's sections
  /// from `/teacher/me/classes`, then each section's roster. The server's own
  /// jurisdiction check (any semester) still applies on send.
  Future<List<PickerClass>> currentSemesterClasses() async {
    final overview = await CrmTeacherApi.overview();
    final semester = overview.currentSemester;
    if (semester == null || semester.isEmpty) {
      throw EmsException('Chưa xác định được học kỳ hiện tại.');
    }
    final sections = (await CrmTeacherApi.classes(
      semester: semester,
    )).where((c) => c.sectionId.isNotEmpty).toList();
    final rosters = await Future.wait(
      sections.map((c) => CrmTeacherApi.classStudents(c.sectionId)),
    );
    return [
      for (var i = 0; i < sections.length; i++)
        PickerClass(
          sections[i].sectionId,
          [
            sections[i].sectionCode,
            sections[i].subjectName,
          ].where((s) => s != null && s.isNotEmpty).join(' · '),
          [
            for (final s in rosters[i])
              if (s.mssv.isNotEmpty) PickerStudent(s.mssv, s.fullName),
          ],
        ),
    ];
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/core/lantern_gate.dart';
import 'package:viendongedu2_flutter/data/classes_repository.dart';
import 'package:viendongedu2_flutter/data/student_home_repository.dart';
import 'package:viendongedu2_flutter/features/classes/class_detail_view_model.dart';
import 'package:viendongedu2_flutter/features/classes/class_models.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_view_model.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/screens/exam_screen.dart';
import 'package:viendongedu2_flutter/screens/capbu_screen.dart';
import 'package:viendongedu2_flutter/screens/lephi_screen.dart';
import 'package:viendongedu2_flutter/screens/registration_screen.dart';
import 'package:viendongedu2_flutter/screens/schedule_screen.dart';
import 'package:viendongedu2_flutter/screens/tuition_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_money_api.dart';
import 'package:viendongedu2_flutter/services/crm_profile_api.dart';
import 'package:viendongedu2_flutter/services/crm_student_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/offline_snapshot.dart';

http.Response _json(Object body, {int status = 200, String? etag}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'etag': ?etag,
      },
    );

const _section = {
  'section_code': 'TEST-SECTION',
  'semester_code': '261',
  'subject_code': 'TEST-SUBJECT',
  'subject_name': 'Môn thử nghiệm',
  'credits': '3.0',
  'teacher_name': 'GV Thử Nghiệm A',
  'ngay_bat_dau': '2026-10-01',
  'ngay_ket_thuc': '2026-12-01',
  'ngay_thi': '2026-12-02',
  'room': 'TEST-R1',
};

Future<void> _refresh(WidgetTester tester) async {
  final indicator = tester.widget<RefreshIndicator>(
    find.byType(RefreshIndicator).first,
  );
  final future = indicator.onRefresh();
  await tester.pumpAndSettle();
  await future;
}

void main() {
  test('home permission denial is separate from a network failure', () async {
    EmsApiService.client = MockClient(
      (_) async => _json({'error': 'Không có quyền'}, status: 403),
    );
    final vm = StudentHomeViewModel(
      const StudentHomeRepository(),
      tickEvery: null,
    );
    await vm.loadTodaySchedule();
    expect(vm.scheduleFailed, isTrue);
    expect(vm.scheduleDenied, isTrue);
    EmsApiService.client = MockClient((_) async => _json({'schedule': []}));
    await vm.loadTodaySchedule();
    expect(vm.scheduleFailed, isFalse);
    expect(vm.scheduleDenied, isFalse);
    vm.dispose();
  });
  for (final compensation in [false, true]) {
    testWidgets(
      'empty ${compensation ? 'compensation' : 'fees'} can refresh to new records',
      (tester) async {
        var revised = false;
        var calls = 0;
        EmsApiService.client = MockClient((_) async {
          calls++;
          return _json({
            'totals': {'le_phi_khac': 0},
            'items': revised
                ? [
                    compensation
                        ? {
                            'id': 'TEST-C',
                            'ten': 'Hóa đơn thử nghiệm',
                            'thanh_tien': null,
                          }
                        : {
                            'phieu_thu_id': 'TEST-P',
                            'loai_phieu_thu': 'Phiếu thử nghiệm',
                            'so_tien': 0,
                          },
                  ]
                : [],
          });
        });
        await tester.pumpWidget(
          MaterialApp(
            home: compensation ? const CapBuScreen() : const LePhiScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            compensation ? 'Không có hóa đơn cấp bù' : 'Không có lệ phí',
          ),
          findsOneWidget,
        );
        revised = true;
        await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(
          find.text(
            compensation ? 'Không có hóa đơn cấp bù' : 'Không có lệ phí',
          ),
          findsNothing,
        );
        expect(
          find.text(compensation ? 'chưa có dữ liệu' : '0 đ'),
          findsWidgets,
        );
      },
    );
  }

  testWidgets(
    'timetable attendance distinguishes pending, network failure and denial',
    (tester) async {
      var phase = 0;
      EmsApiService.client = MockClient((req) async {
        if (req.url.path.endsWith('/schedule')) {
          return _json({
            'schedule': [
              {
                'section_code': 'TEST-SECTION',
                'subject_name': 'Môn thử nghiệm',
                'day_code': '6',
              },
            ],
          });
        }
        if (phase == 1) throw http.ClientException('offline');
        if (phase == 2) return _json({'error': 'Không có quyền'}, status: 403);
        return _json({
          'marks': [
            {
              'section_code': 'TEST-SECTION',
              'session_date': '2026-10-23',
              'status': null,
            },
          ],
        });
      });
      await tester.pumpWidget(
        MaterialApp(home: ScheduleScreen(now: () => DateTime(2026, 10, 23))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa điểm danh'), findsOneWidget);
      phase = 1;
      await _refresh(tester);
      expect(find.text('Chưa tải được'), findsOneWidget);
      expect(find.text('Chưa điểm danh'), findsNothing);
      phase = 2;
      await _refresh(tester);
      expect(find.text('Không có quyền'), findsOneWidget);
      expect(find.text('Vắng mặt'), findsNothing);
    },
  );

  test(
    'absent name preserves verified login; explicit unknown replaces it',
    () async {
      var explicitUnknown = false;
      EmsApiService.client = MockClient(
        (_) async => _json({
          'student': {
            'mssv': 'TEST260001',
            if (explicitUnknown) 'full_name': null,
          },
        }),
      );
      await CrmStudentApi.me();
      expect(AppSession.instance.fullName, 'Thử Nghiệm A');
      explicitUnknown = true;
      await CrmStudentApi.me();
      expect(AppSession.instance.fullName, isNull);
    },
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.student
      ..mssv = 'TEST260001'
      ..fullName = 'Thử Nghiệm A'
      ..dataOpen = null;
    EmsApiService.retryDelay = (_) => Duration.zero;
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..mssv = null
      ..dataOpen = null;
  });

  test(
    'both profile callers replace true/false/absent/malformed gate and name',
    () async {
      for (final editCaller in [false, true]) {
        for (final gate in [true, false, 'absent', 'true', null, 1]) {
          AppSession.instance.dataOpen = false;
          EmsApiService.client = MockClient(
            (_) async => _json({
              if (gate != 'absent') 'data_open': gate,
              'student': {'mssv': 'TEST260001', 'full_name': 'Thử Nghiệm B'},
            }),
          );
          if (editCaller) {
            await CrmProfileApi.getStudentMe();
          } else {
            await CrmStudentApi.me();
          }
          expect(AppSession.instance.dataOpen, gate is bool ? gate : null);
          expect(AppSession.instance.fullName, 'Thử Nghiệm B');
          expect(
            studentDataOpen(
              '24TEST',
              minPrefix: 25,
              serverDataOpen: AppSession.instance.dataOpen,
            ),
            gate == true,
          );
          expect(
            studentDataOpen(
              '26TEST',
              minPrefix: 25,
              serverDataOpen: AppSession.instance.dataOpen,
            ),
            gate != false,
          );
        }
      }
    },
  );

  test(
    'malformed profile never applies its gate or wipes the session name',
    () async {
      AppSession.instance.dataOpen = false;
      EmsApiService.client = MockClient(
        (_) async => _json({'data_open': true, 'student': []}),
      );
      await expectLater(CrmStudentApi.me(), throwsA(isA<EmsException>()));
      await expectLater(
        CrmProfileApi.getStudentMe(),
        throwsA(isA<EmsException>()),
      );
      expect(AppSession.instance.dataOpen, isFalse);
      expect(AppSession.instance.fullName, 'Thử Nghiệm A');
    },
  );

  test(
    'an old account profile cannot replace the current session gate or name',
    () async {
      final response = Completer<http.Response>();
      EmsApiService.client = MockClient((_) => response.future);
      final pending = CrmStudentApi.me();
      await Future<void>.delayed(Duration.zero);
      AppSession.instance
        ..emsToken = 'test-other-token'
        ..fullName = 'Thử Nghiệm B'
        ..dataOpen = false;
      response.complete(
        _json({
          'data_open': true,
          'student': {'full_name': 'Thử Nghiệm A'},
        }),
      );
      await pending;
      expect(AppSession.instance.dataOpen, isFalse);
      expect(AppSession.instance.fullName, 'Thử Nghiệm B');
    },
  );

  test(
    'normal home refresh replaces profile, class, gate and schedule',
    () async {
      var revised = false;
      EmsApiService.client = MockClient((req) async {
        if (req.url.path.endsWith('/student/me')) {
          return _json({
            'data_open': revised,
            'student': {
              'mssv': 'TEST260001',
              'full_name': revised ? 'Thử Nghiệm B' : 'Thử Nghiệm A',
              'class_code': revised ? 'TEST-CLASS-B' : 'TEST-CLASS-A',
            },
          });
        }
        if (req.url.path.endsWith('/schedule')) {
          return _json({
            'schedule': [
              {
                'subject_name': revised
                    ? 'Môn thử nghiệm B'
                    : 'Môn thử nghiệm A',
                'day_code': '6',
              },
            ],
          });
        }
        return _json({'items': [], 'unread': 0, 'must_read_pending': 0});
      });
      final vm = StudentHomeViewModel(
        const StudentHomeRepository(),
        now: () => DateTime(2026, 10, 23),
        tickEvery: null,
      );
      await vm.refresh();
      expect(vm.classCode, 'TEST-CLASS-A');
      expect(AppSession.instance.dataOpen, isFalse);
      revised = true;
      await vm.refresh();
      expect(vm.name, 'Thử Nghiệm B');
      expect(vm.classCode, 'TEST-CLASS-B');
      expect(vm.todayClasses.single.subjectName, 'Môn thử nghiệm B');
      expect(AppSession.instance.dataOpen, isTrue);
      expect(AppSession.instance.emsToken, 'test-token');
      vm.dispose();
    },
  );

  test(
    'fresh masked response supersedes cached schedule including offline retry',
    () async {
      var call = 0;
      EmsApiService.client = MockClient((_) async {
        if (++call == 1) {
          return _json({
            'schedule': [
              {'subject_name': 'Môn thử nghiệm cũ'},
            ],
          }, etag: '"old"');
        }
        if (call == 2) return _json({'schedule': [], 'chua_co_lich': []});
        throw http.ClientException('offline');
      });
      expect(
        (await CrmStudentApi.scheduleViewCached()).data.schedule,
        hasLength(1),
      );
      final masked = await CrmStudentApi.scheduleViewCached();
      expect(masked.fresh, isTrue);
      expect(masked.data.schedule, isEmpty);
      final offline = await CrmStudentApi.scheduleViewCached();
      expect(offline.data.schedule, isEmpty);
      expect(offline.fresh, isFalse);
    },
  );

  for (final status in [401, 403, 422]) {
    test(
      'cached read surfaces HTTP $status instead of old successful data',
      () async {
        var call = 0;
        EmsApiService.client = MockClient(
          (_) async => ++call == 1
              ? _json({'schedule': []}, etag: '"old"')
              : _json({'error': 'Từ chối thử nghiệm'}, status: status),
        );
        await EmsApiService.sendCached('/student/me/schedule');
        await expectLater(
          EmsApiService.sendCached('/student/me/schedule'),
          throwsA(
            isA<EmsException>().having((e) => e.statusCode, 'status', status),
          ),
        );
        if (status == 401 || status == 403) {
          EmsApiService.client = MockClient(
            (_) async => throw http.ClientException('offline'),
          );
          await expectLater(
            EmsApiService.sendCached('/student/me/schedule'),
            throwsA(isA<EmsException>()),
          );
        }
      },
    );
  }

  test(
    'in-flight cached response never populates a different account cache',
    () async {
      final response = Completer<http.Response>();
      EmsApiService.client = MockClient((_) => response.future);
      final pending = EmsApiService.sendCached('/student/me/schedule');
      final check = expectLater(pending, throwsA(isA<EmsException>()));
      await Future<void>.delayed(Duration.zero);
      AppSession.instance
        ..emsToken = 'test-other-token'
        ..mssv = 'TEST260002';
      response.complete(_json({'schedule': []}, etag: '"old"'));
      await check;
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('offline_v1_')),
        isEmpty,
      );
    },
  );

  test(
    'masked tuition replaces stored figures; denied read purges snapshot',
    () async {
      var phase = 0;
      EmsApiService.client = MockClient((_) async {
        if (phase == 0) {
          return _json({
            'summary': {'owedTotal': 125000, 'balance': 125000},
          });
        }
        if (phase == 1) {
          return _json({
            'summary': {
              'money_known': false,
              'money_unknown_reason': 'Đang đối chiếu',
            },
            'payments': [
              {'so_tien': 25000},
            ],
          });
        }
        if (phase == 2) throw http.ClientException('offline');
        return _json({'error': 'Không có quyền'}, status: 403);
      });
      expect((await CrmMoneyApi.getTuition()).summary.balance, 125000);
      phase = 1;
      expect((await CrmMoneyApi.getTuition()).summary.balance, isNull);
      phase = 2;
      final stored = await CrmMoneyApi.getTuition();
      expect(stored.summary.moneyKnown, isFalse);
      expect(stored.summary.balance, isNull);
      expect(stored.offlineSavedAt, isNotNull);
      expect(stored.payments.single.soTien, 25000);
      phase = 3;
      await expectLater(CrmMoneyApi.getTuition(), throwsA(isA<EmsException>()));
      expect(await OfflineSnapshot.load('student_tuition'), isNull);
    },
  );

  test(
    'class detail refresh replaces corrected metadata and explicit unknowns',
    () async {
      var phase = 0;
      EmsApiService.client = MockClient((req) async {
        if (req.url.path.endsWith('/sections')) {
          return _json({
            'sections': [
              {
                ..._section,
                'teacher_name': phase == 1 ? 'GV Thử Nghiệm B' : null,
                'room': phase == 1 ? 'TEST-R2' : null,
                'ngay_bat_dau': phase == 1 ? '2026-10-02' : null,
                'ngay_ket_thuc': phase == 1 ? '2026-12-04' : null,
                'ngay_thi': phase == 1 ? '2026-12-03' : null,
              },
            ],
          });
        }
        if (req.url.path.endsWith('/grades')) {
          return _json({
            'grades': [
              {
                'section_code': 'TEST-SECTION',
                'final_score': phase == 1 ? '8.0' : null,
              },
            ],
          });
        }
        return _json({
          'marks': [
            {
              'section_code': 'TEST-SECTION',
              'session_date': '2026-10-23',
              'status': null,
            },
          ],
        });
      });
      final vm = ClassDetailViewModel(
        const ClassesRepository(),
        sectionCode: 'TEST-SECTION',
        item: ClassItem.fromSection(CrmStudentSection.fromJson(_section)),
      );
      phase = 1;
      await vm.refresh();
      expect(vm.item!.room, 'TEST-R2');
      expect(vm.item!.gvten, 'GV Thử Nghiệm B');
      expect(vm.item!.startDate, DateTime.utc(2026, 10, 2));
      expect(vm.item!.endDate, DateTime.utc(2026, 12, 4));
      expect(vm.item!.examDate, DateTime.utc(2026, 12, 3));
      expect(vm.item!.tongdiem, 8);
      expect(vm.absent, 0);
      expect(vm.pending, 1);
      phase = 2;
      await vm.refresh();
      expect(vm.item!.room, isNull);
      expect(vm.item!.startDate, isNull);
      expect(vm.item!.endDate, isNull);
      expect(vm.item!.examDate, isNull);
      expect(vm.item!.gvten, '');
      expect(vm.item!.tongdiem, isNull);
      expect(AppSession.instance.emsToken, 'test-token');
      vm.dispose();
    },
  );

  testWidgets(
    'exam refresh replaces correction and unknown duration is not zero',
    (tester) async {
      var phase = 0;
      EmsApiService.client = MockClient(
        (_) async => _json({
          'exams': [
            {
              'exam_id': 'TEST-EXAM',
              'subject_name': 'Môn thử nghiệm',
              'semester_code': '261',
              'exam_date': phase == 0 ? '2026-12-02' : '2026-12-03',
              'start_time': phase == 0 ? '08:00' : '09:00',
              'room': phase == 0 ? 'TEST-R1' : null,
              'duration_minutes': phase == 0 ? '60' : null,
            },
          ],
        }),
      );
      await tester.pumpWidget(const MaterialApp(home: ExamScreen()));
      await tester.pumpAndSettle();
      expect(find.text('02/12/2026'), findsOneWidget);
      expect(find.text('60 phút'), findsOneWidget);
      phase = 1;
      await _refresh(tester);
      expect(find.text('03/12/2026'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('TEST-R1'), findsNothing);
      expect(find.text('null phút'), findsNothing);
      expect(find.text('0 phút'), findsNothing);
      expect(find.text('—'), findsNWidgets(2));
    },
  );

  testWidgets(
    'tuition distinguishes true zero, unknown, receipts and signed credits',
    (tester) async {
      var masked = false;
      EmsApiService.client = MockClient(
        (req) async => req.url.path.endsWith('/tuition')
            ? _json({
                'summary': {
                  'source': 'bang_ke',
                  'money_known': !masked,
                  'money_unknown_reason': 'Đang đối chiếu',
                  'owedTotal': masked ? null : '0',
                  'paid': masked ? null : '0',
                  'balance': masked ? null : '0',
                },
                'payments': [
                  {'so_tien': '-25000', 'loai_phieu_thu': 'Phiếu thử nghiệm'},
                ],
              })
            : _json({'computable': false}),
      );
      await tester.pumpWidget(const MaterialApp(home: TuitionScreen()));
      await tester.pumpAndSettle();
      expect(find.text('0 đ'), findsNWidgets(3));
      expect(find.text('-25.000 đ'), findsOneWidget);
      masked = true;
      await _refresh(tester);
      expect(find.text('0 đ'), findsNothing);
      expect(find.text('Đang đối chiếu'), findsWidgets);
      expect(find.text('-25.000 đ'), findsOneWidget);
    },
  );

  testWidgets('fee credit and refund signs remain as supplied by server', (
    tester,
  ) async {
    EmsApiService.client = MockClient(
      (_) async => _json({
        'totals': {'le_phi_khac': 0, 'mien_giam_khen_thuong': -25000},
        'items': [
          {'so_tien': -125000, 'loai_phieu_thu': 'Phiếu thử nghiệm'},
        ],
      }),
    );
    await tester.pumpWidget(const MaterialApp(home: LePhiScreen()));
    await tester.pumpAndSettle();
    expect(find.text('0 đ'), findsOneWidget);
    expect(find.textContaining('-25.000 đ'), findsOneWidget);
    expect(find.text('-125.000 đ'), findsOneWidget);
  });

  testWidgets(
    'registration refresh learns closure and later partial-open masking',
    (tester) async {
      var phase = 0;
      var writes = 0;
      EmsApiService.client = MockClient((req) async {
        if (req.method != 'GET') writes++;
        if (req.url.path.endsWith('/periods')) {
          return _json({
            'periods': phase == 2
                ? []
                : [
                    {
                      'period_id': 'TEST-PERIOD',
                      'period_name': 'Đợt thử nghiệm',
                      'semester_code': '261',
                      'is_open': phase == 0,
                    },
                  ],
          });
        }
        if (req.url.path.endsWith('/offerings')) {
          return _json({
            'curriculum_resolved': false,
            'offerings': [
              {
                'offering_id': 'TEST-O',
                'subject_name': 'Môn thử nghiệm',
                'credits': '3.0',
              },
            ],
          });
        }
        return _json({'results': []});
      });
      await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Đang mở đăng ký'), findsOneWidget);
      phase = 1;
      await _refresh(tester);
      expect(find.text('Đợt đăng ký đã đóng'), findsOneWidget);
      expect(find.text('Đang mở đăng ký'), findsNothing);
      expect(
        find.textContaining('Không xác định được chương trình'),
        findsOneWidget,
      );
      phase = 2;
      await _refresh(tester);
      expect(
        find.textContaining('Hiện không có đợt đăng ký nào'),
        findsOneWidget,
      );
      expect(find.text('Môn thử nghiệm'), findsNothing);
      expect(find.text('Đợt đăng ký đã đóng'), findsNothing);
      expect(writes, 0);
    },
  );
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apt_ev_charging/local_test/local_api_adapter.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio(BaseOptions(
      baseUrl: LocalApiAdapter.baseUrl,
      validateStatus: (status) => status != null && status < 500,
    ))
      ..httpClientAdapter = LocalApiAdapter();
  });

  tearDown(() => dio.close(force: true));

  test('local admin policy switch permits photo-free vehicle submission only',
      () async {
    dio.httpClientAdapter.close();
    dio.httpClientAdapter = LocalApiAdapter(admin: true);
    final state = Map<String, dynamic>.from(
        (await dio.get('/api/state')).data['state'] as Map);
    state['vehicleVerificationRequired'] = false;
    final saved = await dio.post('/api/state', data: state);
    expect(saved.data['state']['vehicleVerificationRequired'], isFalse);
    expect((await dio.get('/api/auth')).data['vehicleVerificationRequired'],
        isFalse);
    final members = (await dio.get('/api/users')).data['users'] as List;
    expect(members, isNotEmpty);
    expect(members.every((u) => u['vehicleVerificationRequired'] == false),
        isTrue);
    final profile = await dio.post('/api/profile',
        data: {'nickname': '입주민', 'vehicleNumber': '234나5678'});
    expect(profile.statusCode, 200);
    expect(profile.data['profile']['profileComplete'], isTrue);
    expect(profile.data['profile']['vehicleVerified'], isFalse);
    expect(profile.data['profile']['ocrMatched'], isFalse);
    expect(profile.data['profile']['status'], 'pending');
    expect((await dio.get('/api/state')).statusCode, 403);
  });

  test('local member cannot change verification policy with parking update',
      () async {
    final saved = await dio.post('/api/state', data: {
      'vehicleVerificationRequired': false,
      'slotDetails': <String, dynamic>{},
    });
    expect(saved.statusCode, 403);
    expect((await dio.get('/api/auth')).data['vehicleVerificationRequired'],
        isTrue);
  });

  test(
      'local voice reports disabled capability and never enables media actions',
      () async {
    final capability = await dio
        .get('/api/parking-voice', queryParameters: {'action': 'capability'});
    expect(capability.statusCode, 200);
    expect(
        capability.data, {'ok': true, 'enabled': false, 'reason': 'DISABLED'});
    final inbox = await dio
        .get('/api/parking-voice', queryParameters: {'action': 'inbox'});
    expect(inbox.statusCode, 200);
    expect(inbox.data, {'ok': true, 'calls': []});
    final media = await dio.post('/api/parking-voice',
        data: {'action': 'create'},
        options: Options(validateStatus: (_) => true));
    expect(media.statusCode, 503);
    expect(media.data['ok'], isFalse);
  });

  test('local voice rejects anonymous access', () async {
    await dio.post('/api/auth', data: {'action': 'logout'});
    expect(
        (await dio.get('/api/parking-voice',
                queryParameters: {'action': 'capability'}))
            .statusCode,
        401);
    expect(
        (await dio.post('/api/parking-voice', data: {'action': 'create'}))
            .statusCode,
        401);
  });

  test(
      'local voice rejects pending residents before capability or media routes',
      () async {
    final submitted = await dio.post('/api/profile', data: {
      'nickname': 'Resident',
      'vehicleNumber': '12가3456',
      'vehiclePhoto': 'data:image/png;base64,AA==',
      'ocrCandidates': ['12가3456'],
    });
    expect(submitted.data['profile']['status'], 'pending');
    expect(
        (await dio.get('/api/parking-voice',
                queryParameters: {'action': 'capability'}))
            .statusCode,
        403);
    expect(
        (await dio.post('/api/parking-voice', data: {'action': 'create'}))
            .statusCode,
        403);
  });

  test('profile retains Google name, ignores phone and queues OCR submission',
      () async {
    final unchanged = await dio.post('/api/profile', data: {
      'vehicleNumber': '12가3456',
      'nickname': 'manual alias',
      'phoneNumber': 'legacy input',
    });
    expect(unchanged.data['profile']['name'], '테스트 회원');
    expect(unchanged.data['profile']['nickname'], 'manual alias');
    expect(unchanged.data['profile']['vehicleVerified'], isTrue);
    expect(
        (await dio.post('/api/profile', data: {
          'nickname': '별명',
          'vehicleNumber': '12가3456, 99나9999',
          'vehiclePhoto': 'data:image/png;base64,AA==',
          'ocrCandidates': ['12가3456, 99나9999'],
        }))
            .statusCode,
        400);
    expect(
        (unchanged.data['profile'] as Map).containsKey('phoneNumber'), isFalse);
    expect(
        (await dio.post('/api/profile', data: {
          'vehicleNumber': '99나9999',
          'nickname': 'manual alias',
          'vehiclePhoto': 'data:image/png;base64,AA==',
          'ocrCandidates': ['99가9999'],
        }))
            .statusCode,
        400);
    final submitted = await dio.post('/api/profile', data: {
      'vehicleNumber': '99나9999',
      'nickname': 'manual alias',
      'vehiclePhoto': 'data:image/png;base64,AA==',
      'ocrCandidates': ['99나9999'],
    });
    expect(submitted.data['profile']['status'], 'pending');
    expect(submitted.data['profile']['vehicleVerified'], isFalse);
    expect((await dio.get('/api/auth')).data['session']['approved'], isFalse);
    expect((await dio.get('/api/state')).statusCode, 403);
  });

  test('isolated admin fixture saves other owners and clears blocked slots',
      () async {
    dio.httpClientAdapter.close();
    dio.httpClientAdapter = LocalApiAdapter(admin: true);
    final auth = await dio.get<Map<String, dynamic>>('/api/auth');
    expect(auth.data?['session'], containsPair('role', 'admin'));
    final response = await dio.get<Map<String, dynamic>>('/api/state');
    final state = Map<String, dynamic>.from(response.data!['state'] as Map);
    final details = Map<String, dynamic>.from(state['slotDetails'] as Map);
    final owner = Map<String, dynamic>.from(details['fast50-2'] as Map);
    owner['vehicleNumber'] = '99가9999';
    owner['parkingBlocked'] = true;
    details['fast50-2'] = owner;
    details.remove('fast50-3');
    state['slotDetails'] = details;
    final saved =
        await dio.post<Map<String, dynamic>>('/api/state', data: state);
    expect(saved.statusCode, 200);
    final savedDetails = (saved.data!['state'] as Map)['slotDetails'] as Map;
    expect(savedDetails['fast50-2'],
        containsPair('ownerEmail', 'other-member@example.invalid'));
    expect(savedDetails['fast50-2'], containsPair('parkingBlocked', true));
    expect(savedDetails, isNot(contains('fast50-3')));
  });

  test('serves the approved fake member and local parking state', () async {
    final auth = await dio.get<Map<String, dynamic>>('/api/auth');
    final state = await dio.get<Map<String, dynamic>>('/api/state');

    expect(auth.data?['session'],
        containsPair('email', LocalApiAdapter.memberEmail));
    expect(auth.data?['session'], containsPair('status', 'approved'));
    expect(state.data?['state'], isA<Map<String, dynamic>>());
    expect((state.data?['state'] as Map)['slotDetails'], contains('fast50-2'));
    expect((state.data?['state'] as Map)['slotDetails'], contains('fast50-3'));
  });

  test(
      'accepts the member slot update but rejects changes to others and blocked slots',
      () async {
    final allowed = await dio.post<Map<String, dynamic>>('/api/state', data: {
      'slotDetails': {
        'fast50-1': {
          'vehicleNumber': '12가3456',
          'contact': '010-0000-0000',
          'ownerEmail': LocalApiAdapter.memberEmail,
          'ownerNickname': '테스트 회원',
        },
      },
    });
    expect(allowed.statusCode, 200);

    final otherOwned =
        await dio.post<Map<String, dynamic>>('/api/state', data: {
      'slotDetails': {'fast50-2': <String, dynamic>{}},
    });
    final blocked = await dio.post<Map<String, dynamic>>('/api/state', data: {
      'slotDetails': {'fast50-3': <String, dynamic>{}},
    });
    expect(otherOwned.statusCode, 403);
    expect(blocked.statusCode, 403);
  });

  test('logout invalidates member routes and unknown routes stay local',
      () async {
    await dio
        .post<Map<String, dynamic>>('/api/auth', data: {'action': 'logout'});
    expect((await dio.get<Map<String, dynamic>>('/api/state')).statusCode, 401);
    expect((await dio.get<Map<String, dynamic>>('/api/admin/users')).statusCode,
        403);
    expect(
        (await dio.get<Map<String, dynamic>>('/not-a-route')).statusCode, 404);
  });

  test('public dashboard redacts occupant identity and contact details',
      () async {
    final response =
        await dio.get<Map<String, dynamic>>('/api/public-dashboard');
    final json = response.data?['state'] as Map<String, dynamic>;
    final details = json['slotDetails'] as Map<String, dynamic>;

    expect(response.statusCode, 200);
    expect(details['fast50-2'], isNot(contains('ownerEmail')));
    expect(details['fast50-2'], isNot(contains('contact')));
  });

  test('supports fake profile, parking history, and chat lifecycle', () async {
    final profile = await dio.get<Map<String, dynamic>>('/api/profile');
    expect(profile.data?['profile'],
        containsPair('email', LocalApiAdapter.memberEmail));

    await dio.post<Map<String, dynamic>>('/api/state', data: {
      'slotDetails': {
        'fast50-1': {
          'vehicleNumber': '12가3456',
          'contact': '010-0000-0000',
          'ownerEmail': LocalApiAdapter.memberEmail,
          'ownerNickname': '테스트 회원',
          'startTime': '2026-10-09T09:00:00.000Z',
        },
      },
    });
    final history = await dio.get<Map<String, dynamic>>('/api/my-history');
    expect(history.data?['history'], hasLength(1));

    final created = await dio
        .post<Map<String, dynamic>>('/api/chat', data: {'message': '안녕하세요'});
    final id = (created.data?['message'] as Map)['id'] as int;
    expect(
        (await dio.put<Map<String, dynamic>>('/api/chat',
                queryParameters: {'id': id}, data: {'message': '수정'}))
            .statusCode,
        200);
    expect((await dio.get<Map<String, dynamic>>('/api/chat')).data?['messages'],
        hasLength(1));
    expect(
        (await dio.delete<Map<String, dynamic>>('/api/chat',
                queryParameters: {'id': id}))
            .statusCode,
        200);
  });

  test('rejects an origin outside the fixed local test host', () async {
    final response =
        await dio.get<Map<String, dynamic>>('https://example.com/api/state');
    expect(response.statusCode, 403);
  });
  test('removing the member slot from a full state payload releases it',
      () async {
    final firstState = Map<String, dynamic>.from(
      (await dio.get<Map<String, dynamic>>('/api/state')).data!['state'] as Map,
    );
    final firstDetails =
        Map<String, dynamic>.from(firstState['slotDetails'] as Map);
    firstDetails['fast50-1'] = {
      'vehicleNumber': '12가3456',
      'contact': '010-0000-0000',
      'ownerEmail': LocalApiAdapter.memberEmail,
      'ownerNickname': '테스트 회원',
    };
    firstState['slotDetails'] = firstDetails;
    expect(
        (await dio.post<Map<String, dynamic>>('/api/state', data: firstState))
            .statusCode,
        200);

    final occupied = Map<String, dynamic>.from(
      (await dio.get<Map<String, dynamic>>('/api/state')).data!['state'] as Map,
    );
    final releasedDetails =
        Map<String, dynamic>.from(occupied['slotDetails'] as Map)
          ..remove('fast50-1');
    occupied['slotDetails'] = releasedDetails;
    expect(
        (await dio.post<Map<String, dynamic>>('/api/state', data: occupied))
            .statusCode,
        200);

    final finalDetails = (await dio.get<Map<String, dynamic>>('/api/state'))
        .data!['state']['slotDetails'] as Map;
    expect(finalDetails, isNot(contains('fast50-1')));

    final records = (await dio.get<Map<String, dynamic>>('/api/my-history'))
        .data!['history'] as List;
    final statuses =
        records.map((record) => (record as Map)['status']).toList();
    expect(statuses, ['completed']);
  });
}

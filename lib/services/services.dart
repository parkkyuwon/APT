/// API 서비스 집합 — ApiClient 를 받아 한 번에 구성.
import '../core/api_client.dart';
import 'auth_api.dart';
import 'bootstrap_admin_api.dart';
import 'indoor_positioning_api.dart';
import 'chat_api.dart';
import 'community_api.dart';
import 'departure_requests_api.dart';
import 'parking_voice_api.dart';
import 'logs_api.dart';
import 'my_history_api.dart';
import 'member_notices_api.dart';
import 'profile_api.dart';
import 'public_api.dart';
import 'session_info_api.dart';
import 'state_api.dart';
import 'users_api.dart';

class ApiServices {
  ApiServices._({
    required this.auth,
    required this.indoorPositioning,
    required this.state,
    required this.profile,
    required this.users,
    required this.chat,
    required this.community,
    required this.departureRequests,
    required this.parkingVoice,
    required this.logs,
    required this.myHistory,
    required this.memberNotices,
    required this.publicDashboard,
    required this.publicHighlight,
    required this.sessionAdmin,
    required this.sessionPublic,
    required this.bootstrapAdmin,
  });

  final AuthApi auth;
  final IndoorPositioningApi indoorPositioning;
  final StateApi state;
  final ProfileApi profile;
  final UsersApi users;
  final ChatApi chat;
  final CommunityApi community;
  final DepartureRequestsApi departureRequests;
  final ParkingVoiceApi parkingVoice;
  final LogsApi logs;
  final MyHistoryApi myHistory;
  final MemberNoticesApi memberNotices;
  final PublicDashboardApi publicDashboard;
  final PublicHighlightApi publicHighlight;
  final SessionAdminApi sessionAdmin;
  final SessionPublicApi sessionPublic;
  final BootstrapAdminApi bootstrapAdmin;

  factory ApiServices.from(ApiClient client) {
    return ApiServices._(
      auth: AuthApi(client),
      indoorPositioning: IndoorPositioningApi(client),
      state: StateApi(client),
      profile: ProfileApi(client),
      users: UsersApi(client),
      chat: ChatApi(client),
      community: CommunityApi(client),
      departureRequests: DepartureRequestsApi(client),
      parkingVoice: ParkingVoiceApi(client),
      logs: LogsApi(client),
      myHistory: MyHistoryApi(client),
      memberNotices: MemberNoticesApi(client),
      publicDashboard: PublicDashboardApi(client),
      publicHighlight: PublicHighlightApi(client),
      sessionAdmin: SessionAdminApi(client),
      sessionPublic: SessionPublicApi(client),
      bootstrapAdmin: BootstrapAdminApi(client),
    );
  }
}

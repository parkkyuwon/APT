# 관리자 회원 정리·정보 입력 요청 구현 계획

사용자 확인: 미사용은 주차·충전 마지막 이용일 기준. 삭제 후 같은 Google 이메일로
새 가입은 허용하되 일반 신규 회원 승인 절차를 다시 따른다. Google 계정 자체는 삭제하지 않는다.

## 계약

- `GET /api/admin-members?incompleteOnly=true&inactiveValue=30&inactiveUnit=days&limit=100&offset=0`:
  승인 관리자 전용, `users` 배열. inactiveUnit은 days/months. 필터 조합은 AND.
  프로필 미완료는 닉네임/차량번호/전화번호 중 공백 제외 값이 없는 경우.
  마지막 이용은 주차 이력의 시작/실제 출차/기록 시각 중 최신 값, 이력이 없으면 가입일.
  현재 차량 등록이 있는 회원은 장기 미사용에서 제외한다. 관리자도 삭제 대상에서 제외한다.
  필터는 서버 조회 전체에 적용한 뒤 페이지를 나누며 클라이언트에 마지막 이용일을 제공한다.
- `DELETE /api/admin-members`, `{emails:[...]}`:
  선택 회원 앱 데이터 실제 삭제. 관리자/자기 자신 제외를 서버에서 재검증.
  중간 실패 시 부분 삭제가 되지 않는 원자적 처리, 최대 100명.
  결과 `{ok:true,deletedCount:N}`. Google 계정은 유지되며 앱 회원 행·세션·관련 개인 데이터를 삭제.
- `POST /api/admin-members`, `{action:'request-profile',emails:[...],message:'추가 메시지'}`:
  서버에서 여전히 프로필 미완료인 대상만 허용, 기본 입력 안내+추가 메시지를 저장.
  결과 `{ok:true,sentCount:N,pushSentCount:N,pushFailedCount:N}`.
  앱 내 안내는 영속 저장, FCM 발송 접수와 앱 내 저장을 구분한다. 자동 실제 발송은 하지 않는다.
- `GET /api/member-notices`: 로그인 회원 본인에게만 `{ok:true,notices:[{id,message,createdAt}]}`.
  프로필 설정 화면에서 조회·표시하며 연결 실패가 프로필 입력을 막지 않는다.

## 구현·검증

- [x] 서버 스키마·필터·원자적 삭제·개인별 안내 API와 오프라인 PostgreSQL 테스트.
- [x] Flutter UsersApi/AppUser 확장 및 관리자 체크박스·현재 페이지 전체 선택·페이지 이동·필터·삭제 확인·추가 메시지 입력.
- [x] 회원 프로필 화면에서 저장된 입력 안내 표시, 지연 응답·화면 수명 회귀 검증.
- [x] Node 전체 테스트, Flutter analyze/test, 로컬 관리자 fixture 화면 검증.
- [x] Mermaid·JSON 색인과 API 문서·검증 기록 갱신.

결과: Flutter131/Node56개 통과, 운영 서버·스키마 적용 완료(회원67명 및 기존 주차 정보 보존).
버전19 AAB 준비 완료. Play Console 확장 연결 해제로 새 업로드는 재연결 대기.

서버는 `D:/vsCodeProg/APT-Prj`, 앱은 현재 저장소. 파일 소유 범위를 분리해 병렬 구현하고
변경을 통합 검증한다. 기존 사용자 변경과 운영 데이터는 보존한다. 실제 회원 삭제/안내 발송은
이번 개발 요청으로 자동 실행하지 않는다. 서버 배포·마이그레이션과 앱 출시 상태를 별도로 기록한다.

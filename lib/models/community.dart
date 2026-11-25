import '../core/json_utils.dart';

class BoardPost {
  BoardPost.fromJson(Map<String, dynamic> json)
      : id = asInt(json['id']),
        title = asStr(json['title']),
        content = asStr(json['content']),
        authorEmail = asStr(json['authorEmail']),
        authorName = asStr(json['authorName']),
        createdAt = asDateTimeOrNull(json['createdAt']);

  final int id;
  final String title;
  final String content;
  final String authorEmail;
  final String authorName;
  final DateTime? createdAt;
}

class ChargerReport {
  ChargerReport.fromJson(Map<String, dynamic> json)
      : id = asInt(json['id']),
        slotId = asStr(json['slotId']),
        description = asStr(json['description']),
        photo = asStr(json['photo']),
        hasPhoto = asBool(json['hasPhoto']) || asStr(json['photo']).isNotEmpty,
        status = asStr(json['status']),
        authorEmail = asStr(json['authorEmail']),
        authorName = asStr(json['authorName']),
        createdAt = asDateTimeOrNull(json['createdAt']);

  final int id;
  final String slotId;
  final String description;
  final String photo;
  final bool hasPhoto;
  final String status;
  final String authorEmail;
  final String authorName;
  final DateTime? createdAt;

  String get statusLabel =>
      const {
        'received': '접수',
        'in_progress': '처리 중',
        'resolved': '완료',
      }[status] ??
      '상태 확인 필요';
}

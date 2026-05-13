import '../core/json_utils.dart';

/// /api/my-history 주차 이력 단일 레코드.
class ParkingHistoryRecord {
  ParkingHistoryRecord({
    required this.id,
    required this.userEmail,
    required this.slotId,
    required this.vehicleNumber,
    required this.contact,
    required this.startTime,
    required this.endTime,
    required this.chargeDuration,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String userEmail;
  final String slotId;
  final String vehicleNumber;
  final String contact;
  final DateTime? startTime;
  final DateTime? endTime;
  final String chargeDuration;
  final String status;
  final DateTime? createdAt;

  factory ParkingHistoryRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    String s(String camel, String snake) =>
        (json[camel] as String?) ?? (json[snake] as String?) ?? '';

    return ParkingHistoryRecord(
      id: asInt(json['id']),
      userEmail: s('userEmail', 'user_email'),
      slotId: s('slotId', 'slot_id'),
      vehicleNumber: s('vehicleNumber', 'vehicle_number'),
      contact: (json['contact'] as String?) ?? '',
      startTime: parse(json['startTime'] ?? json['start_time']),
      endTime: parse(json['endTime'] ?? json['end_time']),
      chargeDuration: s('chargeDuration', 'charge_duration'),
      status: (json['status'] as String?) ?? '',
      createdAt: parse(json['createdAt'] ?? json['created_at']),
    );
  }
}

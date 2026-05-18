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
    return ParkingHistoryRecord(
      id: asInt(json['id']),
      userEmail: firstStr(json, 'userEmail', 'user_email'),
      slotId: firstStr(json, 'slotId', 'slot_id'),
      vehicleNumber: firstStr(json, 'vehicleNumber', 'vehicle_number'),
      contact: asStr(json['contact']),
      startTime: asDateTimeOrNull(json['startTime'] ?? json['start_time']),
      endTime: asDateTimeOrNull(json['endTime'] ?? json['end_time']),
      chargeDuration: firstStr(json, 'chargeDuration', 'charge_duration'),
      status: asStr(json['status']),
      createdAt: asDateTimeOrNull(json['createdAt'] ?? json['created_at']),
    );
  }
}

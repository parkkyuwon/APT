import '../core/json_utils.dart';

class DepartureRequest {
  const DepartureRequest(
      {required this.id,
      required this.slotId,
      required this.slotName,
      required this.requesterVehicleNumber,
      required this.createdAt,
      required this.readAt,
      required this.pushStatus,
      this.retryAfterSeconds = 0});
  final int id;
  final String slotId;
  final String slotName;
  final String requesterVehicleNumber;
  final DateTime? createdAt;
  final DateTime? readAt;
  final String pushStatus;
  final int retryAfterSeconds;
  bool get isRead => readAt != null;

  factory DepartureRequest.fromJson(Map<String, dynamic> json) =>
      DepartureRequest(
        id: int.tryParse('${json['id']}') ?? 0,
        slotId: asStr(json['slotId']),
        slotName: asStr(json['slotName']),
        requesterVehicleNumber: asStr(json['requesterVehicleNumber']),
        createdAt: DateTime.tryParse(asStr(json['createdAt'])),
        readAt: DateTime.tryParse(asStr(json['readAt'])),
        pushStatus: asStr(json['pushStatus']),
        retryAfterSeconds: int.tryParse('${json['retryAfterSeconds']}') ?? 0,
      );
}

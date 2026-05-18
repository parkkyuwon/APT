import '../core/json_utils.dart';

/// [state.slots[typeId]] 개별 슬롯. id 형식: "{typeId}-{index+1}" (예: fast50-1)
class ParkingSlot {
  const ParkingSlot({required this.id, required this.typeId});
  final String id;
  final String typeId;

  factory ParkingSlot.fromJson(Map<String, dynamic> json) {
    return ParkingSlot(
      id: asStr(json['id']),
      typeId: asStr(json['typeId']),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'typeId': typeId};
}

/// [state.slotDetails[slotId]] — 특정 슬롯의 점유/차단/차량 정보.
class SlotDetail {
  const SlotDetail({
    this.vehicleNumber = '',
    this.contact = '',
    this.contactVisible = false,
    this.startTime = '',
    this.departureTime = '',
    this.chargeDuration = '',
    this.ownerEmail = '',
    this.ownerNickname = '',
    this.parkingBlocked = false,
  });

  final String vehicleNumber;
  final String contact;
  final bool contactVisible;
  final String startTime;
  final String departureTime;
  final String chargeDuration;
  final String ownerEmail;
  final String ownerNickname;
  final bool parkingBlocked;

  bool get isOccupied =>
      !parkingBlocked &&
      (vehicleNumber.isNotEmpty ||
          startTime.isNotEmpty ||
          departureTime.isNotEmpty ||
          chargeDuration.isNotEmpty ||
          ownerEmail.isNotEmpty);

  factory SlotDetail.fromJson(Map<String, dynamic> json) {
    return SlotDetail(
      vehicleNumber: asStr(json['vehicleNumber']),
      contact: asStr(json['contact']),
      contactVisible: asBool(json['contactVisible']),
      startTime: asStr(json['startTime']),
      departureTime: asStr(json['departureTime']),
      chargeDuration: asStr(json['chargeDuration']),
      ownerEmail: asStr(json['ownerEmail']),
      ownerNickname: asStr(json['ownerNickname']),
      parkingBlocked: asBool(json['parkingBlocked']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (vehicleNumber.isNotEmpty) 'vehicleNumber': vehicleNumber,
      if (contact.isNotEmpty) 'contact': contact,
      'contactVisible': contactVisible,
      if (startTime.isNotEmpty) 'startTime': startTime,
      if (departureTime.isNotEmpty) 'departureTime': departureTime,
      if (chargeDuration.isNotEmpty) 'chargeDuration': chargeDuration,
      if (ownerEmail.isNotEmpty) 'ownerEmail': ownerEmail,
      if (ownerNickname.isNotEmpty) 'ownerNickname': ownerNickname,
      'parkingBlocked': parkingBlocked,
    };
  }

  SlotDetail copyWith({
    String? vehicleNumber,
    String? contact,
    bool? contactVisible,
    String? startTime,
    String? departureTime,
    String? chargeDuration,
    String? ownerEmail,
    String? ownerNickname,
    bool? parkingBlocked,
  }) {
    return SlotDetail(
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      contact: contact ?? this.contact,
      contactVisible: contactVisible ?? this.contactVisible,
      startTime: startTime ?? this.startTime,
      departureTime: departureTime ?? this.departureTime,
      chargeDuration: chargeDuration ?? this.chargeDuration,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerNickname: ownerNickname ?? this.ownerNickname,
      parkingBlocked: parkingBlocked ?? this.parkingBlocked,
    );
  }
}

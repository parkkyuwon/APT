class MemberNotice {
  const MemberNotice({required this.id, required this.message, this.createdAt});
  final String id;
  final String message;
  final DateTime? createdAt;

  factory MemberNotice.fromJson(Map<String, dynamic> json) => MemberNotice(
        id: '${json['id'] ?? ''}',
        message: '${json['message'] ?? ''}',
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      );
}

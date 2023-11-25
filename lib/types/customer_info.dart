class CustomerInfo {
  final int id;
  final String name;
  final String phoneNumber;
  final String avatarUrl;

  CustomerInfo(
    this.id,
    this.avatarUrl, {
    required this.phoneNumber,
    required this.name,
  });

  factory CustomerInfo.fromJson(json) {
    return CustomerInfo(json['id'], json['avatarUrl'],
        phoneNumber: json['phoneNumber'], name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
    };
  }
}

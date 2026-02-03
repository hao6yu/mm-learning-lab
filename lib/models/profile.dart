class Profile {
  final int? id;
  final String name;
  final int age;
  final String avatar;
  final String avatarType; // 'emoji' or 'photo'
  final DateTime createdAt;

  Profile({
    this.id,
    required this.name,
    required this.age,
    required this.avatar,
    this.avatarType = 'emoji',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'avatar': avatar,
      'avatar_type': avatarType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as int,
      name: map['name'] as String,
      age: map['age'] as int,
      avatar: map['avatar'] as String,
      avatarType: map['avatar_type'] as String? ?? 'emoji',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

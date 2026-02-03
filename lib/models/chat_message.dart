class ChatMessage {
  final int? id;
  final String message;
  final bool isUserMessage;
  final String? audioPath;
  final String timestamp;
  final int? profileId;

  ChatMessage({
    this.id,
    required this.message,
    required this.isUserMessage,
    this.audioPath,
    required this.timestamp,
    this.profileId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'is_user_message': isUserMessage ? 1 : 0,
      'audio_path': audioPath,
      'timestamp': timestamp,
      'profile_id': profileId,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      message: map['message'],
      isUserMessage: map['is_user_message'] == 1,
      audioPath: map['audio_path'],
      timestamp: map['timestamp'],
      profileId: map['profile_id'],
    );
  }
}

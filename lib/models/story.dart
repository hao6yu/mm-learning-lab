class Story {
  final int? id;
  final String title;
  final String content;
  final String emoji;
  final String category;
  final String difficulty;
  final String? wordOfDay;
  final bool isUserCreated;
  final String? audioPath;

  Story({
    this.id,
    required this.title,
    required this.content,
    required this.emoji,
    required this.category,
    required this.difficulty,
    this.wordOfDay,
    this.isUserCreated = false,
    this.audioPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'emoji': emoji,
      'category': category,
      'difficulty': difficulty,
      'word_of_day': wordOfDay,
      'is_user_created': isUserCreated ? 1 : 0,
      'audio_path': audioPath,
    };
  }

  factory Story.fromMap(Map<String, dynamic> map) {
    return Story(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      emoji: map['emoji'],
      category: map['category'],
      difficulty: map['difficulty'],
      wordOfDay: map['word_of_day'],
      isUserCreated: map['is_user_created'] == 1,
      audioPath: map['audio_path'],
    );
  }

  Story copyWith({
    int? id,
    String? title,
    String? content,
    String? emoji,
    String? category,
    String? difficulty,
    String? wordOfDay,
    bool? isUserCreated,
    String? audioPath,
  }) {
    return Story(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      wordOfDay: wordOfDay ?? this.wordOfDay,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      audioPath: audioPath ?? this.audioPath,
    );
  }
}

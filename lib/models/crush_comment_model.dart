

class CrushCommentModel {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String userProfilePic;
  final bool userIsVerified;
  final String text;
  final DateTime createdAt;

  CrushCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.userProfilePic,
    this.userIsVerified = false,
    required this.text,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'username': username,
      'userProfilePic': userProfilePic,
      'userIsVerified': userIsVerified,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CrushCommentModel.fromMap(Map<String, dynamic> map, String id) {
    return CrushCommentModel(
      id: id,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      userProfilePic: map['userProfilePic'] ?? '',
      userIsVerified: map['userIsVerified'] ?? false,
      text: map['text'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CrushCommentModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? username,
    String? userProfilePic,
    bool? userIsVerified,
    String? text,
    DateTime? createdAt,
  }) {
    return CrushCommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userProfilePic: userProfilePic ?? this.userProfilePic,
      userIsVerified: userIsVerified ?? this.userIsVerified,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

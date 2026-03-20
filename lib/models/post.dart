import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorProfileImage;
  final String content;
  final DateTime timestamp;
  final bool isAnonymous;
  final String topic;
  final String moodText;
  final int moodColorValue;
  final List<String> likes; // User IDs who liked the post
  final int commentCount;
  final String? imageUrl;
  final bool isArchived;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorProfileImage,
    required this.content,
    required this.timestamp,
    required this.isAnonymous,
    required this.topic,
    required this.moodText,
    required this.moodColorValue,
    required this.likes,
    required this.commentCount,
    this.imageUrl,
    this.isArchived = false,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      authorProfileImage: data['authorProfileImage'],
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAnonymous: data['isAnonymous'] ?? false,
      topic: data['topic'] ?? 'General',
      moodText: data['moodText'] ?? 'Neutral',
      moodColorValue: data['moodColorValue'] ?? 0xFF7C9C84,
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] ?? 0,
      imageUrl: data['imageUrl'],
      isArchived: data['isArchived'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImage': authorProfileImage,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'isAnonymous': isAnonymous,
      'topic': topic,
      'moodText': moodText,
      'moodColorValue': moodColorValue,
      'likes': likes,
      'commentCount': commentCount,
      'imageUrl': imageUrl,
      'isArchived': isArchived,
    };
  }
}

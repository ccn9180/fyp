import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendProfile {
  final String uid;
  final String fullName;
  final String? profileImageUrl;

  FriendProfile({
    required this.uid,
    required this.fullName,
    this.profileImageUrl,
  });

  factory FriendProfile.fromMap(String uid, Map<String, dynamic> data) {
    return FriendProfile(
      uid: uid,
      fullName: data['fullName'] ?? data['name'] ?? 'Unknown User',
      profileImageUrl: data['profileImageUrl'] ?? data['imageUrl'],
    );
  }
}

class FriendsService {
  static Future<List<FriendProfile>> getFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final following = List<String>.from(userDoc.data()?['following'] ?? []);
      if (following.isEmpty) return [];

      final List<FriendProfile> friends = [];
      
      // Batch UIDs into chunks of 10 due to Firestore whereIn query limitations.
      for (var i = 0; i < following.length; i += 10) {
        final chunk = following.sublist(i, i + 10 > following.length ? following.length : i + 10);
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in snapshot.docs) {
          friends.add(FriendProfile.fromMap(doc.id, doc.data()));
        }
      }
      return friends;
    } catch (e) {
      print('Error fetching friends: $e');
      return [];
    }
  }

  // Helper to fetch details for specific UIDs (e.g. for shared list display)
  static Future<List<FriendProfile>> getProfiles(List<String> uids) async {
    if (uids.isEmpty) return [];
    try {
      final List<FriendProfile> profiles = [];
      for (var i = 0; i < uids.length; i += 10) {
        final chunk = uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10);
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in snapshot.docs) {
          profiles.add(FriendProfile.fromMap(doc.id, doc.data()));
        }
      }
      return profiles;
    } catch (e) {
      print('Error fetching profiles: $e');
      return [];
    }
  }
}

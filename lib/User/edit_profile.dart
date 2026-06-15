import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  final List<String> _selectedInterests = [];
  final List<String> _allInterests = [
    'Anxiety Relief',
    'Daily Gratitude',
    'Sleep Hygiene',
    'Peer Support',
    'Productivity',
  ];

  bool _isLoading = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _profileImageUrl;
  File? _imageFile;
  final List<Map<String, dynamic>> _trustedContacts = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'Update Profile Photo',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a way to capture your essence',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF7A8C85),
              ),
            ),
            const SizedBox(height: 32),

            // Options
            _buildSourceTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              subtitle: 'Use your camera for a new shot',
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 16),
            _buildSourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              subtitle: 'Pick from your existing library',
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),

            if (_imageFile != null || _profileImageUrl != null) ...[
              const SizedBox(height: 16),
              _buildSourceTile(
                icon: Icons.delete_outline,
                iconColor: Colors.redAccent,
                title: 'Remove Current Photo',
                subtitle: 'Revert to default avatar',
                onTap: () {
                  Navigator.pop(context);
                  _markImageForRemoval();
                },
              ),
            ],

            const SizedBox(height: 32),

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7A8C85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF7C9C84),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF7A8C85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 256, // Reduced from 512 for manageable Base64 size
        maxHeight: 256, // Reduced from 512
        imageQuality: 40, // Reduced quality to keep string length down
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _markImageForRemoval() {
    setState(() {
      _imageFile = null;
      _profileImageUrl = null;
    });
  }

  Future<String?> _processImageToBase64(File image) async {
    try {
      // 1. Read the image bytes
      final bytes = await image.readAsBytes();

      // 2. Compress the image if it's too large (Firestore limit is 1MB total for doc)
      // Since we can't easily compress bytes directly to a specific size without a package like flutter_image_compress,
      // we'll just encode it. To be safe, ensure the user picks a small image or use a package later.

      String base64Image = base64Encode(bytes);

      // 3. Return as a Data URI so Flutter can display it easily
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      debugPrint('Error processing image: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['fullName'] ?? '';
          _emailController.text = data['email'] ?? '';
          _nicknameController.text = data['nickname'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _profileImageUrl = data['profileImageUrl'];

          if (data['interests'] != null) {
            _selectedInterests.clear();
            _selectedInterests.addAll(List<String>.from(data['interests']));
          }

          if (data['trustedContacts'] != null) {
            _trustedContacts.clear();
            _trustedContacts.addAll(List<Map<String, dynamic>>.from(data['trustedContacts']));
          }

          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _profileImageUrl;
      if (_imageFile != null) {
        imageUrl = await _processImageToBase64(_imageFile!);
      }

      final name = _nameController.text.trim();
      final docRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
      final trustedContactUids = _trustedContacts
          .map((c) => c['uid'])
          .where((uid) => uid != null)
          .cast<String>()
          .toList();

      await docRef.update({
        'fullName': name, // Can't edit but good to keep
        'nickname': _nicknameController.text.trim(),
        'email': _emailController.text.trim(),
        'bio': _bioController.text.trim(),
        'interests': _selectedInterests,
        'profileImageUrl': imageUrl,
        'trustedContacts': _trustedContacts,
        'trustedContactUids': trustedContactUids,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update FirebaseAuth displayName
      await _currentUser!.updateDisplayName(name);
      await _currentUser!.reload(); // Refresh the user object

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: Color(0xFF7C9C84),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating profile: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: const Color(0xFF333333),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: const [
          SizedBox(width: 48), // Balancing the leading icon space
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C9C84)),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture Section
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            image: _imageFile != null
                                ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                                : (_profileImageUrl != null && _profileImageUrl!.startsWith('data:image'))
                                ? DecorationImage(
                              image: MemoryImage(base64Decode(_profileImageUrl!.split(',').last)),
                              fit: BoxFit.cover,
                            )
                                : _profileImageUrl != null
                                ? DecorationImage(
                              image: NetworkImage(_profileImageUrl!),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: (_imageFile == null && _profileImageUrl == null)
                              ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Color(0xFFBBCBC2),
                          )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C9C84),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Text(
                      'CHANGE PROFILE PICTURE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: const Color(0xFF7C9C84),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Full Name Field
            _buildLabel('FULL NAME'),
            _buildTextField(_nameController, hintText: "Enter your full name", readOnly: true),

            const SizedBox(height: 24),

            // Nickname Field
            _buildLabel('NICKNAME'),
            _buildTextField(_nicknameController, hintText: "Enter your nickname"),

            const SizedBox(height: 24),

            // Email Field
            _buildLabel('EMAIL ADDRESS'),
            _buildTextField(_emailController, hintText: "Enter your email address", readOnly: true),

            const SizedBox(height: 24),

            // Bio Field
            _buildLabel('MINDFUL BIO'),
            _buildTextField(_bioController, maxLines: 4, hintText: "Share your mindful journey or goals..."),

            const SizedBox(height: 32),

            // Trusted Contacts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trusted Contacts',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share your progress summaries',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _showAddContactDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3E8E4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add, size: 16, color: Color(0xFF7C9C84)),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF7C9C84),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                ...List.generate(_trustedContacts.length, (index) {
                  final contact = _trustedContacts[index];
                  return GestureDetector(
                    onTap: () => _showRemoveContactDialog(index),
                    child: _buildContactAvatar(
                      contact['initials'] ?? '??',
                      contact['name'] ?? contact['label'] ?? 'Unknown',
                      profileImageUrl: contact['profileImageUrl'],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: _showAddContactDialog,
                  child: _buildContactAvatar('+', 'Add Contact'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Mood Interests
            Text(
              'Mood Interests',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedInterests.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                child: Text(
                  'No interests selected yet. Pick some below!',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.orange[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return GestureDetector(
                  onTap: () => _toggleInterest(interest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF7C9C84) : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF7C9C84) : Colors.grey[400]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          interest,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF555555),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check, size: 16, color: Colors.white),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C9C84),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Save Changes',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: const Color(0xFFA3A3A3),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {int maxLines = 1, String? hintText, bool readOnly = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        style: GoogleFonts.outfit(
          fontSize: 16,
          color: readOnly ? const Color(0xFF9E9E9E) : const Color(0xFF333333),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.outfit(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          suffixIcon: readOnly 
              ? const Icon(Icons.lock_outline_rounded, color: Color(0xFFD1D5DB), size: 20) 
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildContactAvatar(String initials, String label, {String? profileImageUrl}) {
    ImageProvider? imageProvider;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      if (profileImageUrl.startsWith('data:image')) {
        imageProvider = MemoryImage(base64Decode(profileImageUrl.split(',').last));
      } else {
        imageProvider = NetworkImage(profileImageUrl);
      }
    }

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFE3E8E4),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBBCBC2), width: 1),
          ),
          child: Center(
            child: imageProvider != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image(
                      image: imageProvider,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                    ),
                  )
                : (initials == '+'
                    ? const Icon(
                        Icons.add,
                        size: 30,
                        color: Color(0xFF7C9C84),
                      )
                    : Text(
                        initials,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7C9C84),
                        ),
                      )),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchConnections(String currentUserUid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserUid).get();
      if (!userDoc.exists) return [];
      
      final data = userDoc.data() ?? {};
      final following = List<String>.from(data['following'] ?? []);
      final followers = List<String>.from(data['followers'] ?? []);
      
      final uniqueUids = <String>{...following, ...followers};
      uniqueUids.remove(currentUserUid);
      
      if (uniqueUids.isEmpty) return [];
      
      final List<Map<String, dynamic>> profiles = [];
      final fetchFutures = uniqueUids.map((uid) async {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
            final profile = doc.data() ?? {};
            return {
              'uid': uid,
              'name': profile['fullName'] ?? 'Unknown User',
              'email': profile['email'] ?? '',
              'phone': profile['phoneNumber'] ?? profile['phone'] ?? '',
              'profileImageUrl': profile['profileImageUrl'],
            };
          }
        } catch (e) {
          debugPrint('Error fetching profile for $uid: $e');
        }
        return null;
      });
      
      final results = await Future.wait(fetchFutures);
      for (var res in results) {
        if (res != null) {
          profiles.add(res);
        }
      }
      return profiles;
    } catch (e) {
      debugPrint('Error fetching connections: $e');
      return [];
    }
  }

  void _showAddContactDialog() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;

    List<Map<String, dynamic>> connections = [];
    bool loading = true;
    String searchQuery = '';
    Map<String, dynamic>? selectedContact;
    String selectedRelation = 'Friend';
    final List<String> relations = ['Family', 'Counselor', 'Friend', 'Other'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (loading) {
            _fetchConnections(currentUserUid).then((list) {
              if (mounted) {
                setDialogState(() {
                  connections = list;
                  loading = false;
                });
              }
            });
            return AlertDialog(
              backgroundColor: const Color(0xFFF2F1EC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              content: const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF7C9C84)),
                ),
              ),
            );
          }

          final filtered = connections.where((c) {
            final name = c['name'].toString().toLowerCase();
            final email = c['email'].toString().toLowerCase();
            final matchesQuery = name.contains(searchQuery.toLowerCase()) || email.contains(searchQuery.toLowerCase());
            
            // Check if user is already in _trustedContacts
            final isAlreadyAdded = _trustedContacts.any((tc) =>
                (c['uid'] != null && tc['uid'] == c['uid']) ||
                (c['email'].isNotEmpty && tc['email'] == c['email']));
            
            return matchesQuery && !isAlreadyAdded;
          }).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFFF2F1EC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text(
              'Add Trusted Contact',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: const Color(0xFF333333),
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (connections.isEmpty) ...[
                      Text(
                        'You don\'t have any followers or following connections yet.',
                        style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF666666)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Follow users in the community tab first to add them here.',
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500], fontStyle: FontStyle.italic),
                      ),
                    ] else ...[
                      _buildDialogLabel('SEARCH CONNECTION'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          style: GoogleFonts.outfit(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Search by name or email...',
                            hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              searchQuery = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDialogLabel('SELECT CONTACT'),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No matching connections found.',
                                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final contact = filtered[index];
                                  final isSelected = selectedContact?['uid'] == contact['uid'];
                                  
                                  ImageProvider? imageProvider;
                                  final profileImageUrl = contact['profileImageUrl'] as String?;
                                  if (profileImageUrl != null) {
                                    if (profileImageUrl.startsWith('data:image')) {
                                      imageProvider = MemoryImage(base64Decode(profileImageUrl.split(',').last));
                                    } else {
                                      imageProvider = NetworkImage(profileImageUrl);
                                    }
                                  }

                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFFE3E8E4),
                                      backgroundImage: imageProvider,
                                      child: imageProvider == null
                                          ? Text(
                                              _getInitials(contact['name']),
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF7C9C84),
                                              ),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      contact['name'],
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: const Color(0xFF333333),
                                      ),
                                    ),
                                    subtitle: Text(
                                      contact['email'],
                                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C9C84))
                                        : null,
                                    selected: isSelected,
                                    selectedTileColor: const Color(0xFF7C9C84).withOpacity(0.08),
                                    onTap: () {
                                      setDialogState(() {
                                        selectedContact = contact;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      _buildDialogLabel('RELATIONSHIP'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRelation,
                            isExpanded: true,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: const Color(0xFF333333),
                            ),
                            items: relations.map((rel) => DropdownMenuItem(
                              value: rel,
                              child: Text(rel),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedRelation = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  connections.isEmpty ? 'Close' : 'Cancel',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              if (connections.isNotEmpty)
                ElevatedButton(
                  onPressed: selectedContact == null
                      ? null
                      : () {
                          final name = selectedContact!['name'];
                          final email = selectedContact!['email'];
                          final phone = selectedContact!['phone'];
                          final foundUid = selectedContact!['uid'];

                          // Prevent duplicates check
                          final isDuplicate = _trustedContacts.any((c) =>
                              (foundUid != null && c['uid'] == foundUid) ||
                              (email.isNotEmpty && c['email'] == email));
                          
                          if (isDuplicate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This user is already added to your trusted contacts.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          final initials = _getInitials(name);
                          setState(() {
                            _trustedContacts.add({
                              'name': name,
                              'label': name,
                              'initials': initials,
                              'relationship': selectedRelation.toUpperCase(),
                              'email': email,
                              'phone': phone,
                              'uid': foundUid,
                              'profileImageUrl': selectedContact!['profileImageUrl'],
                            });
                          });

                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C9C84),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Add',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showRemoveContactDialog(int index) {
    final contact = _trustedContacts[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2F1EC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'Remove Contact',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: const Color(0xFF333333),
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${contact['name'] ?? contact['label']} from your trusted contacts?',
          style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _trustedContacts.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57373),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    List<String> names = name.split(" ");
    String initials = "";
    int numWords = names.length > 2 ? 2 : names.length;
    for (var i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) {
        initials += names[i][0].toUpperCase();
      }
    }
    return initials.isEmpty ? "?" : initials;
  }

  Widget _buildDialogLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: const Color(0xFFA3A3A3),
        ),
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, {String? hintText, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

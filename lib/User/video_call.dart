import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoCallScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  const VideoCallScreen({super.key, required this.sessionData});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF9F9F7);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);
  final Color cardColor = Colors.white;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isConnecting = false;

  Future<void> _launchJitsi() async {
    setState(() {
      _isConnecting = true;
    });

    final String bookingId = widget.sessionData['id'] ?? 'session';
    final Uri jitsiUrl = Uri.parse("https://meet.jit.si/eunoia_$bookingId");

    try {
      if (await canLaunchUrl(jitsiUrl)) {
        await launchUrl(jitsiUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open video call link. Please install Jitsi Meet or try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching meeting: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SECURE SESSION LOBBY',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: const Color(0xFF5D6D66),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Lobby Header / Counselor details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundImage: NetworkImage(widget.sessionData['counsellorImageUrl']),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.sessionData['counsellorName'],
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.sessionData['counsellorSpecialty'] ?? 'Therapist',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3EE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7C9C84),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Session connection ready',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFF5D6D66),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Checklist/Permission Test Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRE-SESSION CHECKLIST',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: textColorSub,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Microphone toggle
                    _buildSettingsRow(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      title: 'Microphone status',
                      subtitle: _isMuted ? 'Muted / Disabled' : 'Active / Enabled',
                      iconColor: _isMuted ? Colors.redAccent : primaryGreen,
                      trailing: Switch(
                        value: !_isMuted,
                        onChanged: (val) => setState(() => _isMuted = !val),
                        activeColor: primaryGreen,
                      ),
                    ),

                    const Divider(height: 24),

                    // Camera toggle
                    _buildSettingsRow(
                      icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      title: 'Camera status',
                      subtitle: _isVideoOff ? 'Off / Disabled' : 'Active / Enabled',
                      iconColor: _isVideoOff ? Colors.redAccent : primaryGreen,
                      trailing: Switch(
                        value: !_isVideoOff,
                        onChanged: (val) => setState(() => _isVideoOff = !val),
                        activeColor: primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Lobby buttons
              if (_isConnecting)
                const CircularProgressIndicator(color: Color(0xFF7C9C84))
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _launchJitsi,
                    icon: const Icon(Icons.video_call_rounded, size: 24, color: Colors.white),
                    label: Text(
                      'ENTER MEETING ROOM',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      elevation: 2,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel and Exit Lobby',
                    style: GoogleFonts.outfit(
                      color: textColorSub,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
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
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColorMain,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: textColorSub,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

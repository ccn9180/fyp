import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResourcePreviewScreen extends StatefulWidget {
  final String type; // 'meditation' or 'article'
  final String title;
  final String subtitle;
  final String tag;
  final String imageUrl;
  final String duration;
  final double? rating;
  final String? authorName;
  final String? authorRole;
  final String? authorImageUrl;
  final String? content;
  final VoidCallback onStart;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const ResourcePreviewScreen({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.imageUrl,
    required this.duration,
    this.rating,
    this.authorName,
    this.authorRole,
    this.authorImageUrl,
    this.content,
    required this.onStart,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  State<ResourcePreviewScreen> createState() => _ResourcePreviewScreenState();
}

class _ResourcePreviewScreenState extends State<ResourcePreviewScreen> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = widget.type == 'meditation' ? const Color(0xFF7C9C84) : const Color(0xFF86A588);
    final String buttonText = widget.type == 'meditation' ? 'Start Meditation' : 'Start Reading';

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.9),
              child: IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                  color: _isFavorite ? Colors.redAccent : const Color(0xFF333333), 
                  size: 20
                ),
                onPressed: () {
                  setState(() => _isFavorite = !_isFavorite);
                  widget.onFavoriteToggle();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isFavorite ? "Saved to your favorites." : "Removed from favorites."),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background Hero Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Hero(
              tag: 'resource_image_${widget.title}',
              child: Image.network(
                widget.imageUrl.isNotEmpty ? widget.imageUrl : 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Gradient Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.white.withOpacity(0.8),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.4, 0.85, 1.0],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.38),
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.tag.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Title
                        Text(
                          widget.title.replaceAll('\n', ' '),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Metadata Row
                        Row(
                          children: [
                            Icon(Icons.access_time, color: Colors.grey[400], size: 16),
                            const SizedBox(width: 6),
                            Text(
                              widget.duration,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (widget.authorName != null) ...[
                              const SizedBox(width: 16),
                              Icon(Icons.person_outline, color: Colors.grey[400], size: 16),
                              const SizedBox(width: 6),
                              Text(
                                widget.authorName!,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            if (widget.rating != null && widget.rating! > 0) ...[
                              const SizedBox(width: 16),
                              const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 18),
                              const SizedBox(width: 4),
                              Text(
                                widget.rating!.toStringAsFixed(1),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        // Overview Section
                        Text(
                          widget.type == 'article' ? 'Key Insights' : 'About this ${widget.type}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            height: 1.6,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        
                        const SizedBox(height: 120), // Space for button
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Button
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.type == 'meditation' ? Icons.play_circle_fill : Icons.auto_stories, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      buttonText,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

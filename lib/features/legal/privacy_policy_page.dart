import 'package:flutter/material.dart';
import '../../core/theme/cinematic_colors.dart';

/// Professional Privacy Policy page detailing local data storage,
/// third-party streaming providers, and user data rights.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinematicColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        title: const Text(
          "Privacy Policy",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Privacy Policy",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Last updated: November 2026",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Divider(color: Colors.white12, height: 32),

            _buildSection(
              title: "1. Overview",
              body:
                  "Cinematic Music Player is engineered with privacy as a foundational principle. The application functions primarily as an offline local audio player and stream resolver. We do not sell, rent, or monetize your personal information.",
            ),

            _buildSection(
              title: "2. Local Audio Storage and File Access",
              body:
                  "The application requires access to local storage solely to scan, index, and play audio files chosen by you. Audio metadata (such as titles, artists, albums, and artwork) is indexed locally on your device in a private SQLite database. Your local music files are never uploaded to any remote server without your explicit cloud backup configuration.",
            ),

            _buildSection(
              title: "3. Third-Party Services and External APIs",
              body:
                  "The app provides access to external music providers, including Jamendo and JioSaavn, as well as web-based discovery resources. When you initiate search queries or stream external tracks, requests are transmitted directly to the respective third-party endpoints. These external services are governed by their own independent privacy policies and terms of service.",
            ),

            _buildSection(
              title: "4. Network Usage and Permissions",
              body:
                  "Network access permissions (INTERNET and ACCESS_NETWORK_STATE) are utilized exclusively for:\n"
                  "• Streaming audio tracks requested by the user\n"
                  "• Fetching song metadata, album artwork, and synchronized lyrics\n"
                  "• Checking for official software updates via GitHub releases\n"
                  "• Optional cloud synchronization if authenticated by the user",
            ),

            _buildSection(
              title: "5. Analytics and Diagnostics",
              body:
                  "We do not employ invasive third-party analytics trackers, advertising SDKs, or behavioral profiling tools. Crash diagnostics and error logs are stored locally on your device and are never automatically transmitted without user consent.",
            ),

            _buildSection(
              title: "6. User Control and Data Deletion",
              body:
                  "You retain complete ownership and control over your data. You may delete local library databases, reset sync cache, or clear preferences at any time directly through the application settings.",
            ),

            _buildSection(
              title: "7. Contact and Inquiries",
              body:
                  "If you have questions or concerns regarding this Privacy Policy, please open an issue on our official GitHub repository.",
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: CinematicColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

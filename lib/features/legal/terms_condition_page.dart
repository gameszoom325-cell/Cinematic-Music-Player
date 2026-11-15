import 'package:flutter/material.dart';
import '../../core/theme/cinematic_colors.dart';

/// Professional Terms and Conditions page detailing acceptable use,
/// intellectual property, and third-party content disclaimers.
class TermsConditionPage extends StatelessWidget {
  const TermsConditionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinematicColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        title: const Text(
          "Terms and Conditions",
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
              "Terms and Conditions",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Last updated: November 2026",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Divider(color: Colors.white12, height: 32),

            _buildSection(
              title: "1. Agreement to Terms",
              body:
                  "By downloading, installing, or using Cinematic Music Player, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, do not install or use the application.",
            ),

            _buildSection(
              title: "2. License and Usage",
              body:
                  "Cinematic Music Player is distributed under the MIT open-source license. You are granted a personal, non-exclusive license to use the application for playback of legally acquired audio files and authorized streaming services.",
            ),

            _buildSection(
              title: "3. Third-Party Content and External APIs Disclaimer",
              body:
                  "The application incorporates integrations and wrappers for third-party services (including Jamendo, JioSaavn, and public web search endpoints). The developers of Cinematic Music Player do not host, store, upload, manage, or control any external media or streams.\n\n"
                  "All copyrights, trademarks, and intellectual property in third-party content belong solely to their respective content creators, labels, and rights holders. The app is not responsible for the availability, legality, accuracy, or quality of external streams.",
            ),

            _buildSection(
              title: "4. User Responsibilities",
              body:
                  "You agree to use the application only for lawful purposes. You are solely responsible for ensuring that your playback, storage, and retrieval of audio content complies with the applicable copyright laws of your jurisdiction.",
            ),

            _buildSection(
              title: "5. No Warranty",
              body:
                  "The application is provided on an 'as is' and 'as available' basis without warranties of any kind, either express or implied, including but not limited to implied warranties of merchantability, fitness for a particular purpose, or non-infringement.",
            ),

            _buildSection(
              title: "6. Limitation of Liability",
              body:
                  "In no event shall the authors or copyright holders of Cinematic Music Player be liable for any claim, damages, data loss, or other liability arising from or in connection with the software or the use of external third-party streaming resources.",
            ),

            _buildSection(
              title: "7. Modifications to Terms",
              body:
                  "We reserve the right to revise or update these terms at any time. Continued use of the application following the posting of updated terms constitutes acceptance of those changes.",
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

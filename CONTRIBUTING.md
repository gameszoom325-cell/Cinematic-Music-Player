# Contributing to Cinematic Music Player

Thank you for your interest in contributing to Cinematic Music Player!

## Code of Conduct
Please be polite, constructive, and respectful in all community interactions.

## How to Contribute
1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/<your-username>/cinematic_music_player.git
   cd cinematic_music_player
   ```
3. **Create a topic branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Install dependencies**:
   ```bash
   flutter pub get
   ```
5. **Run tests and analysis**:
   ```bash
   flutter analyze
   flutter test
   ```
6. **Commit your changes**:
   Please follow conventional commit conventions (`feat:`, `fix:`, `docs:`, `refactor:`).
7. **Submit a Pull Request**.

## Architecture Guidelines
- Keep business logic in `lib/core/` and feature-specific code in `lib/features/`.
- Ensure custom shaders adhere to GLSL 460 format in `shaders/`.
- Maintain strict null safety and zero-allocation paint loops in visualizers.

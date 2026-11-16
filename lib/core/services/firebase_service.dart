import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../auth/session_manager.dart';
import '../../auth/user_model.dart';
import '../../firebase_options.dart';
import '../../web_search/web_search_page.dart';
import '../database/database_service.dart';
import '../services/scanner_service.dart';

/// Metadata for a song uploaded to the user's Firebase Cloud Library.
class CloudSongMetadata {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String filename;
  final String storageUrl;
  final String storagePath;
  final int fileSize;
  final DateTime? uploadedAt;

  const CloudSongMetadata({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filename,
    required this.storageUrl,
    required this.storagePath,
    this.fileSize = 0,
    this.uploadedAt,
  });

  factory CloudSongMetadata.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedDate;
    if (map['uploadedAt'] != null) {
      if (map['uploadedAt'] is Timestamp) {
        parsedDate = (map['uploadedAt'] as Timestamp).toDate();
      } else if (map['uploadedAt'] is String) {
        parsedDate = DateTime.tryParse(map['uploadedAt'] as String);
      }
    }

    return CloudSongMetadata(
      id: docId,
      title: (map['title'] as String?)?.trim() ?? 'Unknown Title',
      artist: (map['artist'] as String?)?.trim() ?? 'Unknown Artist',
      album: (map['album'] as String?)?.trim() ?? 'Unknown Album',
      filename: (map['filename'] as String?)?.trim() ?? '$docId.mp3',
      storageUrl: (map['storageUrl'] as String?)?.trim() ?? '',
      storagePath: (map['storagePath'] as String?)?.trim() ?? '',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
      uploadedAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'filename': filename,
      'storageUrl': storageUrl,
      'storagePath': storagePath,
      'fileSize': fileSize,
      'uploadedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Core service orchestrating Firebase Authentication, Cloud Firestore
/// song metadata synchronization, and Firebase Storage audio binary transport.
class FirebaseService {
  FirebaseService._internal();
  static final FirebaseService instance = FirebaseService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  /// Initializes the Firebase SDK using [DefaultFirebaseOptions].
  /// Fails gracefully in offline or unconfigured environments.
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
      debugPrint("FirebaseService: Successfully initialized Firebase for ${defaultTargetPlatform.name}");

      // Sync active Firebase user to local session if present
      final currentFbUser = _auth.currentUser;
      if (currentFbUser != null) {
        _syncToSessionManager(currentFbUser);
      }

      return true;
    } catch (e) {
      debugPrint("FirebaseService: Initialization deferred or unconfigured ($e)");
      _isInitialized = false;
      return false;
    }
  }

  User? get currentUser => _isInitialized ? _auth.currentUser : null;
  bool get isLoggedIn => currentUser != null;
  String? get userId => currentUser?.uid;
  String? get userEmail => currentUser?.email;

  Stream<User?> authStateChanges() {
    if (!_isInitialized) {
      return const Stream.empty();
    }
    return _auth.authStateChanges();
  }

  /// Helper to convert a Firebase User into the app's internal [UserModel].
  void _syncToSessionManager(User user) {
    final now = DateTime.now();
    final userModel = UserModel(
      userId: user.uid,
      username: user.displayName ?? user.email?.split('@').first ?? 'Cinematic User',
      email: user.email ?? '',
      profileImage: user.photoURL,
      createdDate: user.metadata.creationTime ?? now,
      token: 'fb_${user.uid}',
      isGuest: false,
      devices: const [],
    );
    unawaited(SessionManager.instance.saveSession(userModel));
  }

  /// Authenticate with Firebase using Email & Password.
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) {
      final success = await init();
      if (!success) {
        throw Exception("Firebase is not configured or unavailable on this device.");
      }
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        _syncToSessionManager(credential.user!);
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Firebase Authentication error (${e.code})");
    } catch (e) {
      throw Exception("Login failed: $e");
    }
  }

  /// Register a new user with Firebase using Email & Password.
  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    String? username,
  }) async {
    if (!_isInitialized) {
      final success = await init();
      if (!success) {
        throw Exception("Firebase is not configured or unavailable on this device.");
      }
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        if (username != null && username.trim().isNotEmpty) {
          await credential.user!.updateDisplayName(username.trim());
        }
        _syncToSessionManager(credential.user!);
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Firebase Registration error (${e.code})");
    } catch (e) {
      throw Exception("Registration failed: $e");
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    if (_isInitialized) {
      try {
        await _auth.signOut();
      } catch (e) {
        debugPrint("FirebaseService: Sign out notice: $e");
      }
    }
    await SessionManager.instance.clearSession();
  }

  // ===========================================================================
  // 3. Mobile Upload Flow (Android)
  // ===========================================================================

  /// Uploads an MP3 file to Firebase Storage at `users/{userId}/songs/{filename}`
  /// and writes song metadata to Firestore at `users/{userId}/library`.
  Future<CloudSongMetadata?> uploadSongToCloud({
    required File file,
    required String filename,
    required String title,
    required String artist,
    String? album,
  }) async {
    if (!isLoggedIn || !_isInitialized) {
      debugPrint("FirebaseService: User not logged in, skipping cloud upload.");
      return null;
    }

    final uid = userId!;
    final sanitizedFilename = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final storagePath = 'users/$uid/songs/$sanitizedFilename';

    try {
      debugPrint("FirebaseService: Uploading $sanitizedFilename to $storagePath...");
      final storageRef = _storage.ref(storagePath);

      // Upload MP3 bytes
      final metadata = SettableMetadata(
        contentType: 'audio/mpeg',
        customMetadata: {
          'title': title,
          'artist': artist,
          'album': album ?? 'Unknown Album',
          'source': 'Pagalworld WebView',
        },
      );

      final uploadTask = await storageRef.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final fileSize = await file.length();

      // Save song metadata to Firestore: users/{userId}/library
      final docId = sanitizedFilename.replaceAll('.', '_');
      final songMetadata = CloudSongMetadata(
        id: docId,
        title: title,
        artist: artist,
        album: album ?? 'Unknown Album',
        filename: sanitizedFilename,
        storageUrl: downloadUrl,
        storagePath: storagePath,
        fileSize: fileSize,
        uploadedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('library')
          .doc(docId)
          .set(songMetadata.toMap(), SetOptions(merge: true));

      debugPrint("FirebaseService: Successfully synced $sanitizedFilename to Firestore and Storage.");
      return songMetadata;
    } catch (e) {
      debugPrint("FirebaseService: Cloud upload error: $e");
      return null;
    }
  }

  // ===========================================================================
  // 4. Desktop Sync Flow (Windows)
  // ===========================================================================

  /// Reads all songs stored in Firestore at `users/{userId}/library`.
  Future<List<CloudSongMetadata>> fetchCloudLibrarySongs() async {
    if (!isLoggedIn || !_isInitialized) return [];

    final uid = userId!;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('library')
          .get();

      return snapshot.docs
          .map((doc) => CloudSongMetadata.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint("FirebaseService: Error fetching cloud library: $e");
      return [];
    }
  }

  /// Identifies songs that exist in the user's cloud library but are not yet
  /// present in the local Windows music directory or database.
  Future<List<CloudSongMetadata>> findMissingSongsOnDesktop() async {
    final cloudSongs = await fetchCloudLibrarySongs();
    if (cloudSongs.isEmpty) return [];

    final localDir = await WebSearchPage.getMusicDownloadDirectory();
    final localDbSongs = DatabaseService.instance.getAllSongs();

    // Map existing local files and titles for fast matching
    final existingFilenames = <String>{};
    if (await localDir.exists()) {
      try {
        final list = await localDir.list().toList();
        for (final entry in list) {
          if (entry is File) {
            existingFilenames.add(p.basename(entry.path).toLowerCase());
          }
        }
      } catch (_) {}
    }

    final existingTitles = localDbSongs
        .map((s) => s.title.trim().toLowerCase())
        .toSet();

    final missing = <CloudSongMetadata>[];
    for (final song in cloudSongs) {
      final fn = song.filename.toLowerCase();
      final title = song.title.toLowerCase();

      final alreadyOnDisk = existingFilenames.contains(fn);
      final alreadyInDb = existingTitles.contains(title);

      if (!alreadyOnDisk && !alreadyInDb) {
        missing.add(song);
      }
    }

    return missing;
  }

  /// Downloads missing songs from Firebase Storage into the Windows music directory,
  /// saves them locally, and adds them to the local library.
  Future<int> downloadCloudSongsToLocal({
    required List<CloudSongMetadata> songs,
    void Function(int completed, int total, String currentSong)? onProgress,
  }) async {
    if (songs.isEmpty) return 0;

    final targetDir = await WebSearchPage.getMusicDownloadDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    int downloadedCount = 0;
    final newlyDownloadedFiles = <File>[];

    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      onProgress?.call(downloadedCount, songs.length, song.title);

      try {
        List<int>? bytes;

        // Try downloading via storageUrl with http
        if (song.storageUrl.isNotEmpty) {
          final res = await http.get(Uri.parse(song.storageUrl));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            bytes = res.bodyBytes;
          }
        }

        // Fallback to Firebase Storage SDK directly
        if (bytes == null && song.storagePath.isNotEmpty && _isInitialized) {
          final data = await _storage.ref(song.storagePath).getData(100 * 1024 * 1024); // max 100MB
          if (data != null && data.isNotEmpty) {
            bytes = data;
          }
        }

        if (bytes != null) {
          final targetFile = File(p.join(targetDir.path, song.filename));
          await targetFile.writeAsBytes(bytes);
          newlyDownloadedFiles.add(targetFile);
          downloadedCount++;
          debugPrint("FirebaseService: Downloaded ${song.title} (${bytes.length} bytes) to ${targetFile.path}");
        }
      } catch (e) {
        debugPrint("FirebaseService: Failed to download song ${song.title}: $e");
      }
    }

    // Rescan library with newly downloaded songs
    if (newlyDownloadedFiles.isNotEmpty) {
      try {
        await ScannerService.importFiles(newlyDownloadedFiles);
      } catch (e) {
        debugPrint("FirebaseService: Library import notice: $e");
      }
    }

    onProgress?.call(downloadedCount, songs.length, "Finished");
    return downloadedCount;
  }
}

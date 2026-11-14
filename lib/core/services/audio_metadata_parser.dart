import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ParsedMetadata {
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int bitrate;
  final int sampleRate;
  final String format;
  final String genre;
  final String year;
  final String? lyrics;
  final Uint8List? pictureBytes;
  final String? pictureMime;

  const ParsedMetadata({
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.bitrate,
    required this.sampleRate,
    required this.format,
    this.genre = "Uncategorized",
    this.year = "",
    this.lyrics,
    this.pictureBytes,
    this.pictureMime,
  });
}

class AudioMetadataParser {
  /// Reads exact requested byte count from a file stream, handling partial I/O chunks.
  static Future<Uint8List> _readFully(RandomAccessFile raf, int length) async {
    final buffer = Uint8List(length);
    int totalRead = 0;
    while (totalRead < length) {
      final read = await raf.readInto(buffer, totalRead, length);
      if (read <= 0) break;
      totalRead += read;
    }
    if (totalRead < length) {
      return buffer.sublist(0, totalRead);
    }
    return buffer;
  }

  static Future<ParsedMetadata> parseFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    final defaultTitle = p.basenameWithoutExtension(file.path);

    try {
      if (ext == '.mp3') {
        return await _parseMp3(file, defaultTitle);
      } else if (ext == '.flac') {
        return await _parseFlac(file, defaultTitle);
      } else if (ext == '.wav') {
        return await _parseWav(file, defaultTitle);
      } else if (ext == '.m4a' || ext == '.aac' || ext == '.mp4') {
        return await _parseM4a(file, defaultTitle);
      } else if (ext == '.ogg') {
        return await _parseOgg(file, defaultTitle);
      }
    } catch (e) {
      debugPrint("Error parsing metadata for ${file.path}: $e");
    }

    return ParsedMetadata(
      title: defaultTitle,
      artist: "Unknown Artist",
      album: "Unknown Album",
      durationMs: 210000,
      bitrate: 320,
      sampleRate: 44100,
      format: ext.replaceAll('.', '').toUpperCase(),
    );
  }

  // --- MP3 ID3v2 & ID3v1 Parser ---
  static Future<ParsedMetadata> _parseMp3(File file, String defaultTitle) async {
    final raf = await file.open(mode: FileMode.read);
    final header = await _readFully(raf, 10);

    String title = defaultTitle;
    String artist = "Unknown Artist";
    String album = "Unknown Album";
    String genre = "Uncategorized";
    String year = "";
    String? lyrics;
    int durationMs = 0;
    Uint8List? pictureBytes;

    if (header.length >= 10 &&
        header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) { // "ID3"
      final int version = header[3]; // 2 = v2.2, 3 = v2.3, 4 = v2.4
      final int flags = header[5];
      final bool hasExtendedHeader = (flags & 0x40) != 0;
      final int tagSize = _readSynchsafe32(header, 6);

      if (tagSize > 0 && tagSize < 20000000) {
        final tagBytes = await _readFully(raf, tagSize);
        int offset = 0;

        // Skip extended header if present
        if (hasExtendedHeader && tagBytes.length >= 4) {
          final extSize = (version == 4)
              ? _readSynchsafe32(tagBytes, 0)
              : ByteData.sublistView(tagBytes).getUint32(0, Endian.big);
          offset = (version == 4) ? extSize : (4 + extSize);
          if (offset >= tagBytes.length) offset = 0;
        }

        final bd = ByteData.sublistView(tagBytes);

        if (version == 2) {
          // ID3v2.2 (3-char frame IDs, 3-byte size, 6-byte header)
          while (offset + 6 < tagBytes.length) {
            if (tagBytes[offset] == 0) break;
            final frameId = String.fromCharCodes(tagBytes.sublist(offset, offset + 3));
            final frameSize = (tagBytes[offset + 3] << 16) |
                (tagBytes[offset + 4] << 8) |
                tagBytes[offset + 5];

            if (frameSize <= 0 || offset + 6 + frameSize > tagBytes.length) break;
            final frameData = tagBytes.sublist(offset + 6, offset + 6 + frameSize);

            if (frameId == 'TT2') title = _decodeTextFrame(frameData);
            if (frameId == 'TP1') artist = _decodeTextFrame(frameData);
            if (frameId == 'TAL') album = _decodeTextFrame(frameData);
            if (frameId == 'TCO') genre = _decodeTextFrame(frameData);
            if (frameId == 'TYE') year = _decodeTextFrame(frameData);
            if (frameId == 'PIC' && pictureBytes == null) {
              pictureBytes = _extractApicPicture(frameData);
            }

            offset += 6 + frameSize;
          }
        } else {
          // ID3v2.3 / ID3v2.4 (4-char frame IDs, 4-byte size, 10-byte header)
          while (offset + 10 < tagBytes.length) {
            if (tagBytes[offset] == 0) break;
            final frameId = String.fromCharCodes(tagBytes.sublist(offset, offset + 4));

            int frameSize = 0;
            if (version == 4) {
              frameSize = _readSynchsafe32(tagBytes, offset + 4);
            } else {
              frameSize = bd.getUint32(offset + 4, Endian.big);
            }

            if (frameSize <= 0 || offset + 10 + frameSize > tagBytes.length) break;
            final frameData = tagBytes.sublist(offset + 10, offset + 10 + frameSize);

            if (frameId == 'TIT2') {
              title = _decodeTextFrame(frameData);
            } else if (frameId == 'TPE1') {
              artist = _decodeTextFrame(frameData);
            } else if (frameId == 'TALB') {
              album = _decodeTextFrame(frameData);
            } else if (frameId == 'TCON') {
              genre = _decodeTextFrame(frameData);
            } else if (frameId == 'TYER' || frameId == 'TDRC') {
              year = _decodeTextFrame(frameData);
            } else if (frameId == 'TLEN') {
              final lenStr = _decodeTextFrame(frameData);
              durationMs = int.tryParse(lenStr) ?? 0;
            } else if (frameId == 'USLT' && lyrics == null) {
              lyrics = _decodeUsltFrame(frameData);
            } else if (frameId == 'APIC' && pictureBytes == null) {
              pictureBytes = _extractApicPicture(frameData);
            }

            offset += 10 + frameSize;
          }
        }
      }
    }

    // ID3v1 Fallback at end of file if title/artist was not in ID3v2
    try {
      final fileLength = await raf.length();
      if (fileLength > 128 && (title == defaultTitle || artist == "Unknown Artist")) {
        await raf.setPosition(fileLength - 128);
        final v1Bytes = await _readFully(raf, 128);
        if (v1Bytes.length == 128 &&
            v1Bytes[0] == 0x54 && v1Bytes[1] == 0x41 && v1Bytes[2] == 0x47) { // "TAG"
          if (title == defaultTitle) {
            final t = latin1.decode(v1Bytes.sublist(3, 33)).trim();
            if (t.isNotEmpty) title = t;
          }
          if (artist == "Unknown Artist") {
            final a = latin1.decode(v1Bytes.sublist(33, 63)).trim();
            if (a.isNotEmpty) artist = a;
          }
          if (album == "Unknown Album") {
            final al = latin1.decode(v1Bytes.sublist(63, 93)).trim();
            if (al.isNotEmpty) album = al;
          }
        }
      }
    } catch (_) {}

    await raf.close();

    final stat = await file.stat();
    if (durationMs <= 0 && stat.size > 0) {
      durationMs = ((stat.size * 8) / (320 * 1000) * 1000).round();
    }

    return ParsedMetadata(
      title: title.isNotEmpty ? title : defaultTitle,
      artist: artist,
      album: album,
      durationMs: durationMs > 0 ? durationMs : 210000,
      bitrate: 320,
      sampleRate: 44100,
      format: "MP3",
      genre: _normalizeGenre(genre),
      year: year,
      lyrics: lyrics,
      pictureBytes: pictureBytes,
    );
  }

  // --- FLAC Parser ---
  static Future<ParsedMetadata> _parseFlac(File file, String defaultTitle) async {
    final raf = await file.open(mode: FileMode.read);
    final header = await _readFully(raf, 4);

    String title = defaultTitle;
    String artist = "Unknown Artist";
    String album = "Unknown Album";
    String genre = "Uncategorized";
    String year = "";
    int durationMs = 0;
    int sampleRate = 44100;
    int bitsPerSample = 16;
    Uint8List? pictureBytes;

    if (header.length == 4 &&
        header[0] == 0x66 && header[1] == 0x4C &&
        header[2] == 0x61 && header[3] == 0x43) { // "fLaC"
      bool isLast = false;
      while (!isLast) {
        final blockHeader = await _readFully(raf, 4);
        if (blockHeader.length < 4) break;

        isLast = (blockHeader[0] & 0x80) != 0;
        final blockType = blockHeader[0] & 0x7F;
        final blockSize = (blockHeader[1] << 16) | (blockHeader[2] << 8) | blockHeader[3];

        if (blockSize <= 0 || blockSize > 25000000) break;

        final blockData = await _readFully(raf, blockSize);

        if (blockType == 0 && blockSize >= 34) {
          // STREAMINFO
          sampleRate = (blockData[10] << 12) | (blockData[11] << 4) | (blockData[12] >> 4);
          bitsPerSample = (((blockData[12] & 0x01) << 4) | (blockData[13] >> 4)) + 1;
          final int totalSamples = ((blockData[13] & 0x0F) * 4294967296) +
              (blockData[14] << 24) +
              (blockData[15] << 16) +
              (blockData[16] << 8) +
              blockData[17];
          if (sampleRate > 0) {
            durationMs = ((totalSamples / sampleRate) * 1000).round();
          }
        } else if (blockType == 4) {
          // VORBIS_COMMENT
          final comments = _parseVorbisComments(blockData);
          if (comments.containsKey('TITLE')) title = comments['TITLE']!;
          if (comments.containsKey('ARTIST')) artist = comments['ARTIST']!;
          if (comments.containsKey('ALBUM')) album = comments['ALBUM']!;
          if (comments.containsKey('GENRE')) genre = comments['GENRE']!;
          if (comments.containsKey('DATE')) year = comments['DATE']!;
          if (comments.containsKey('YEAR')) year = comments['YEAR']!;
        } else if (blockType == 6 && pictureBytes == null) {
          // PICTURE
          pictureBytes = _extractFlacPicture(blockData);
        }
      }
    }
    await raf.close();

    return ParsedMetadata(
      title: title.isNotEmpty ? title : defaultTitle,
      artist: artist,
      album: album,
      durationMs: durationMs > 0 ? durationMs : 240000,
      bitrate: (sampleRate * bitsPerSample * 2) ~/ 1000,
      sampleRate: sampleRate,
      format: "FLAC",
      genre: _normalizeGenre(genre),
      year: year,
      pictureBytes: pictureBytes,
    );
  }

  // --- WAV RIFF Parser ---
  static Future<ParsedMetadata> _parseWav(File file, String defaultTitle) async {
    final raf = await file.open(mode: FileMode.read);
    final header = await _readFully(raf, 12);

    int sampleRate = 44100;
    int byteRate = 176400;
    int durationMs = 0;

    if (header.length == 12 &&
        header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 &&
        header[8] == 0x57 && header[9] == 0x41 && header[10] == 0x56 && header[11] == 0x45) {
      while (await raf.position() < await raf.length()) {
        final chunkHeader = await _readFully(raf, 8);
        if (chunkHeader.length < 8) break;

        final chunkId = String.fromCharCodes(chunkHeader.sublist(0, 4));
        final chunkSize = ByteData.sublistView(chunkHeader).getUint32(4, Endian.little);

        if (chunkId == 'fmt ' && chunkSize >= 16) {
          final fmtData = await _readFully(raf, chunkSize);
          final bd = ByteData.sublistView(fmtData);
          sampleRate = bd.getUint32(4, Endian.little);
          byteRate = bd.getUint32(8, Endian.little);
        } else if (chunkId == 'data') {
          if (byteRate > 0) {
            durationMs = ((chunkSize / byteRate) * 1000).round();
          }
          break;
        } else {
          await raf.setPosition(await raf.position() + chunkSize);
        }
      }
    }
    await raf.close();

    return ParsedMetadata(
      title: defaultTitle,
      artist: "Unknown Artist",
      album: "Unknown Album",
      durationMs: durationMs > 0 ? durationMs : 180000,
      bitrate: (byteRate * 8) ~/ 1000,
      sampleRate: sampleRate,
      format: "WAV",
    );
  }

  // --- M4A / AAC / MP4 Parser ---
  static Future<ParsedMetadata> _parseM4a(File file, String defaultTitle) async {
    String title = defaultTitle;
    String artist = "Unknown Artist";
    String album = "Unknown Album";
    String genre = "Uncategorized";
    String year = "";
    Uint8List? pictureBytes;

    try {
      final raf = await file.open(mode: FileMode.read);
      final length = await raf.length();
      // Read first 4MB to capture all moov/udta/meta/ilst metadata and artwork
      final readSize = length > 4194304 ? 4194304 : length;
      final buffer = await _readFully(raf, readSize);
      await raf.close();

      // Scan for embedded 'covr' box
      final covrPattern = [0x63, 0x6F, 0x76, 0x72]; // "covr"
      for (int i = 0; i <= buffer.length - 24; i++) {
        if (buffer[i] == covrPattern[0] &&
            buffer[i + 1] == covrPattern[1] &&
            buffer[i + 2] == covrPattern[2] &&
            buffer[i + 3] == covrPattern[3]) {
          // Inside covr box, look for child 'data' box (0x64, 0x61, 0x74, 0x61)
          for (int j = i + 4; j < i + 64 && j <= buffer.length - 16; j++) {
            if (buffer[j] == 0x64 && buffer[j + 1] == 0x61 &&
                buffer[j + 2] == 0x74 && buffer[j + 3] == 0x61) {
              final bd = ByteData.sublistView(buffer, j - 4, j);
              final dataBoxSize = bd.getUint32(0, Endian.big);
              // data box structure: 4-byte size, 4-byte 'data', 4-byte type, 4-byte locale, then image payload
              final payloadStart = j + 12;
              final payloadEnd = (j - 4) + dataBoxSize;
              if (payloadStart < buffer.length && payloadEnd <= buffer.length && payloadEnd > payloadStart) {
                pictureBytes = buffer.sublist(payloadStart, payloadEnd);
              }
              break;
            }
          }
          if (pictureBytes != null) break;
        }
      }

      // Fallback: direct JPEG / PNG magic byte scan if atom parse missed it
      if (pictureBytes == null) {
        for (int i = 0; i < buffer.length - 8; i++) {
          if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8 && buffer[i + 2] == 0xFF) {
            pictureBytes = _sliceJpeg(buffer.sublist(i));
            break;
          } else if (buffer[i] == 0x89 && buffer[i + 1] == 0x50 &&
              buffer[i + 2] == 0x4E && buffer[i + 3] == 0x47) {
            pictureBytes = _slicePng(buffer.sublist(i));
            break;
          }
        }
      }

      // Scan for common M4A text metadata tags (©nam, ©ART, ©alb, ©gen, ©day)
      title = _extractM4aString(buffer, [0xA9, 0x6E, 0x61, 0x6D]) ?? defaultTitle; // ©nam
      artist = _extractM4aString(buffer, [0xA9, 0x41, 0x52, 0x54]) ?? // ©ART
          _extractM4aString(buffer, [0x61, 0x41, 0x52, 0x54]) ?? "Unknown Artist"; // aART
      album = _extractM4aString(buffer, [0xA9, 0x61, 0x6C, 0x62]) ?? "Unknown Album"; // ©alb
      genre = _extractM4aString(buffer, [0xA9, 0x67, 0x65, 0x6E]) ?? "Uncategorized"; // ©gen
      year = _extractM4aString(buffer, [0xA9, 0x64, 0x61, 0x79]) ?? ""; // ©day
    } catch (_) {}

    return ParsedMetadata(
      title: title.isNotEmpty ? title : defaultTitle,
      artist: artist,
      album: album,
      durationMs: 220000,
      bitrate: 256,
      sampleRate: 44100,
      format: "M4A",
      genre: _normalizeGenre(genre),
      year: year,
      pictureBytes: pictureBytes,
    );
  }

  static String? _extractM4aString(Uint8List buffer, List<int> atomName) {
    try {
      for (int i = 0; i <= buffer.length - 24; i++) {
        if (buffer[i] == atomName[0] &&
            buffer[i + 1] == atomName[1] &&
            buffer[i + 2] == atomName[2] &&
            buffer[i + 3] == atomName[3]) {
          // Look for 'data' child atom
          for (int j = i + 4; j < i + 64 && j <= buffer.length - 16; j++) {
            if (buffer[j] == 0x64 && buffer[j + 1] == 0x61 &&
                buffer[j + 2] == 0x74 && buffer[j + 3] == 0x61) {
              final bd = ByteData.sublistView(buffer, j - 4, j);
              final dataBoxSize = bd.getUint32(0, Endian.big);
              final textStart = j + 12;
              final textEnd = (j - 4) + dataBoxSize;
              if (textStart < buffer.length && textEnd <= buffer.length && textEnd > textStart) {
                return utf8.decode(buffer.sublist(textStart, textEnd), allowMalformed: true).trim();
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // --- OGG Parser ---
  static Future<ParsedMetadata> _parseOgg(File file, String defaultTitle) async {
    return ParsedMetadata(
      title: defaultTitle,
      artist: "Unknown Artist",
      album: "Unknown Album",
      durationMs: 200000,
      bitrate: 320,
      sampleRate: 44100,
      format: "OGG",
    );
  }

  static int _readSynchsafe32(Uint8List bytes, int offset) {
    return (bytes[offset] << 21) |
        (bytes[offset + 1] << 14) |
        (bytes[offset + 2] << 7) |
        bytes[offset + 3];
  }

  static String _decodeTextFrame(Uint8List data) {
    if (data.isEmpty) return "";
    final encoding = data[0];
    final textBytes = data.sublist(1);
    try {
      if (encoding == 1 || encoding == 2) {
        return utf8.decode(textBytes, allowMalformed: true).replaceAll('\x00', '');
      } else {
        return latin1.decode(textBytes).replaceAll('\x00', '');
      }
    } catch (_) {
      return String.fromCharCodes(textBytes).replaceAll('\x00', '');
    }
  }

  static String? _decodeUsltFrame(Uint8List data) {
    try {
      if (data.length < 5) return null;
      int offset = 4; // skip encoding and 3-char language code
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }
      offset++; // skip null terminator of content descriptor
      if (offset < data.length) {
        return utf8.decode(data.sublist(offset), allowMalformed: true);
      }
    } catch (_) {}
    return null;
  }

  /// Extracts JPEG image bytes with exact EOI marker bound
  static Uint8List _sliceJpeg(Uint8List bytes) {
    for (int i = bytes.length - 2; i >= 2; i--) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) { // JPEG EOI
        return bytes.sublist(0, i + 2);
      }
    }
    return bytes;
  }

  /// Extracts PNG image bytes with exact IEND chunk bound
  static Uint8List _slicePng(Uint8List bytes) {
    // Look for IEND chunk (49 45 4E 44 + 4 byte CRC)
    for (int i = 0; i <= bytes.length - 8; i++) {
      if (bytes[i] == 0x49 && bytes[i + 1] == 0x45 &&
          bytes[i + 2] == 0x4E && bytes[i + 3] == 0x44) {
        final end = i + 8;
        if (end <= bytes.length) {
          return bytes.sublist(0, end);
        }
      }
    }
    return bytes;
  }

  static Uint8List? _extractApicPicture(Uint8List data) {
    try {
      if (data.length < 10) return null;

      // 1. Scan for JPEG signature (FF D8 FF)
      for (int i = 1; i < data.length - 3; i++) {
        if (data[i] == 0xFF && data[i + 1] == 0xD8 && data[i + 2] == 0xFF) {
          return _sliceJpeg(data.sublist(i));
        }
      }

      // 2. Scan for PNG signature (89 50 4E 47 0D 0A 1A 0A)
      for (int i = 1; i < data.length - 8; i++) {
        if (data[i] == 0x89 && data[i + 1] == 0x50 && data[i + 2] == 0x4E && data[i + 3] == 0x47) {
          return _slicePng(data.sublist(i));
        }
      }

      // 3. Fallback offset scanner for ID3 specification
      int offset = 1;
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }
      offset++;
      if (offset >= data.length) return null;
      offset++; // skip picture type
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }
      offset++;
      if (offset < data.length) {
        return data.sublist(offset);
      }
    } catch (_) {}
    return null;
  }

  static Map<String, String> _parseVorbisComments(Uint8List data) {
    final Map<String, String> comments = {};
    try {
      final bd = ByteData.sublistView(data);
      int offset = 0;
      final vendorLen = bd.getUint32(offset, Endian.little);
      offset += 4 + vendorLen;
      if (offset + 4 > data.length) return comments;
      final count = bd.getUint32(offset, Endian.little);
      offset += 4;

      for (int i = 0; i < count; i++) {
        if (offset + 4 > data.length) break;
        final len = bd.getUint32(offset, Endian.little);
        offset += 4;
        if (offset + len > data.length) break;
        final commentStr = utf8.decode(data.sublist(offset, offset + len), allowMalformed: true);
        offset += len;
        final eqIdx = commentStr.indexOf('=');
        if (eqIdx != -1) {
          final key = commentStr.substring(0, eqIdx).toUpperCase();
          final val = commentStr.substring(eqIdx + 1);
          comments[key] = val;
        }
      }
    } catch (_) {}
    return comments;
  }

  static Uint8List? _extractFlacPicture(Uint8List data) {
    try {
      if (data.length < 32) return null;

      // 1. Direct scan for JPEG / PNG signature
      for (int i = 4; i < data.length - 3; i++) {
        if (data[i] == 0xFF && data[i + 1] == 0xD8 && data[i + 2] == 0xFF) {
          return _sliceJpeg(data.sublist(i));
        }
      }
      for (int i = 4; i < data.length - 8; i++) {
        if (data[i] == 0x89 && data[i + 1] == 0x50 && data[i + 2] == 0x4E && data[i + 3] == 0x47) {
          return _slicePng(data.sublist(i));
        }
      }

      // 2. Structured FLAC picture header parsing
      final bd = ByteData.sublistView(data);
      int offset = 4; // skip picture type
      final mimeLen = bd.getUint32(offset, Endian.big);
      offset += 4 + mimeLen;
      final descLen = bd.getUint32(offset, Endian.big);
      offset += 4 + descLen;
      offset += 16; // skip width, height, depth, colors
      if (offset + 4 > data.length) return null;
      final dataLen = bd.getUint32(offset, Endian.big);
      offset += 4;
      if (offset + dataLen <= data.length) {
        return data.sublist(offset, offset + dataLen);
      }
    } catch (_) {}
    return null;
  }

  static String _normalizeGenre(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "Uncategorized";
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      final idx = int.tryParse(trimmed.substring(1, trimmed.length - 1));
      if (idx != null && idx < _id3v1Genres.length) {
        return _id3v1Genres[idx];
      }
    }
    return trimmed;
  }

  static const List<String> _id3v1Genres = [
    "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge",
    "Hip-Hop", "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R&B",
    "Rap", "Reggae", "Rock", "Techno", "Industrial", "Alternative", "Ska",
    "Death Metal", "Pranks", "Soundtrack", "Euro-Techno", "Ambient",
    "Trip-Hop", "Vocal", "Jazz+Funk", "Fusion", "Trance", "Classical",
    "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel",
    "Noise", "AlternRock", "Bass", "Soul", "Punk", "Space", "Meditative",
    "Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic",
    "Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk",
    "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta",
    "Top 40", "Christian Rap", "Pop/Funk", "Jungle", "Native American",
    "Cabaret", "New Wave", "Psychadelic", "Rave", "Showtunes", "Trailer",
    "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz", "Polka", "Retro",
    "Musical", "Rock & Roll", "Hard Rock", "Folk", "Folk-Rock",
    "National Folk", "Swing", "Fast Fusion", "Bebob", "Latin", "Revival",
    "Celtic", "Bluegrass", "Avantgarde", "Gothic Rock", "Progressive Rock",
    "Psychedelic Rock", "Symphonic Rock", "Slow Rock", "Big Band",
    "Chorus", "Easy Listening", "Acoustic", "Humour", "Speech", "Chanson",
    "Opera", "Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus",
    "Porn Groove", "Satire", "Slow Jam", "Club", "Tango", "Samba",
    "Folklore", "Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle",
    "Duet", "Punk Rock", "Drum Solo", "A capella", "Euro-House", "Dance Hall"
  ];
}

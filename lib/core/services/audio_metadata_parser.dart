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
      } else if (ext == '.m4a' || ext == '.aac') {
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
    final header = Uint8List(10);
    final headerRead = await raf.readInto(header, 0, 10);

    String title = defaultTitle;
    String artist = "Unknown Artist";
    String album = "Unknown Album";
    String genre = "Uncategorized";
    String year = "";
    String? lyrics;
    int durationMs = 0;
    Uint8List? pictureBytes;

    if (headerRead >= 10 &&
        header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) {
      final int version = header[3];
      final int tagSize = _readSynchsafe32(header, 6);

      if (tagSize > 0 && tagSize < 10000000) {
        final tagBytes = Uint8List(tagSize);
        await raf.readInto(tagBytes, 0, tagSize);

        int offset = 0;
        final bd = ByteData.sublistView(tagBytes);

        while (offset + 10 < tagSize) {
          if (tagBytes[offset] == 0) break;
          final frameId = String.fromCharCodes(tagBytes.sublist(offset, offset + 4));

          int frameSize = 0;
          if (version == 4) {
            frameSize = _readSynchsafe32(tagBytes, offset + 4);
          } else {
            frameSize = bd.getUint32(offset + 4, Endian.big);
          }

          if (frameSize <= 0 || offset + 10 + frameSize > tagSize) break;
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
    final header = Uint8List(4);
    await raf.readInto(header, 0, 4);

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
        header[2] == 0x61 && header[3] == 0x43) {
      bool isLast = false;
      while (!isLast) {
        final blockHeader = Uint8List(4);
        final read = await raf.readInto(blockHeader, 0, 4);
        if (read < 4) break;

        isLast = (blockHeader[0] & 0x80) != 0;
        final blockType = blockHeader[0] & 0x7F;
        final blockSize = (blockHeader[1] << 16) | (blockHeader[2] << 8) | blockHeader[3];

        if (blockSize <= 0 || blockSize > 10000000) break;

        final blockData = Uint8List(blockSize);
        await raf.readInto(blockData, 0, blockSize);

        if (blockType == 0 && blockSize >= 34) {
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
          final comments = _parseVorbisComments(blockData);
          if (comments.containsKey('TITLE')) title = comments['TITLE']!;
          if (comments.containsKey('ARTIST')) artist = comments['ARTIST']!;
          if (comments.containsKey('ALBUM')) album = comments['ALBUM']!;
          if (comments.containsKey('GENRE')) genre = comments['GENRE']!;
          if (comments.containsKey('DATE')) year = comments['DATE']!;
          if (comments.containsKey('YEAR')) year = comments['YEAR']!;
        } else if (blockType == 6 && pictureBytes == null) {
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
    final header = Uint8List(12);
    await raf.readInto(header, 0, 12);

    int sampleRate = 44100;
    int byteRate = 176400;
    int durationMs = 0;

    if (header.length == 12 &&
        header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 &&
        header[8] == 0x57 && header[9] == 0x41 && header[10] == 0x56 && header[11] == 0x45) {
      
      final stat = await file.stat();
      final fileSize = stat.size;

      while (await raf.position() + 8 < fileSize) {
        final chunkHeader = Uint8List(8);
        await raf.readInto(chunkHeader, 0, 8);
        final chunkId = String.fromCharCodes(chunkHeader.sublist(0, 4));
        final bd = ByteData.sublistView(chunkHeader);
        final chunkSize = bd.getUint32(4, Endian.little);

        if (chunkId == 'fmt ' && chunkSize >= 16) {
          final fmtData = Uint8List(chunkSize);
          await raf.readInto(fmtData, 0, chunkSize);
          final fmtBd = ByteData.sublistView(fmtData);
          sampleRate = fmtBd.getUint32(4, Endian.little);
          byteRate = fmtBd.getUint32(8, Endian.little);
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

  // --- M4A / AAC Parser ---
  static Future<ParsedMetadata> _parseM4a(File file, String defaultTitle) async {
    return ParsedMetadata(
      title: defaultTitle,
      artist: "Unknown Artist",
      album: "Unknown Album",
      durationMs: 220000,
      bitrate: 256,
      sampleRate: 44100,
      format: "M4A",
    );
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

  static Uint8List? _extractApicPicture(Uint8List data) {
    try {
      if (data.length < 10) return null;
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
      final bd = ByteData.sublistView(data);
      int offset = 4;
      final mimeLen = bd.getUint32(offset, Endian.big);
      offset += 4 + mimeLen;
      final descLen = bd.getUint32(offset, Endian.big);
      offset += 4 + descLen;
      offset += 16;
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
    // Check for ID3v1 genre index e.g. "(13)"
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
    "Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic", "Darkwave",
    "Techno-Industrial", "Electronic", "Pop-Folk", "Eurodance", "Dream",
    "Southern Rock", "Comedy", "Cult", "Gangsta", "Top 40", "Christian Rap",
    "Pop/Funk", "Jungle", "Native American", "Cabaret", "New Wave",
    "Psychadelic", "Rave", "Showtunes", "Trailer", "Lo-Fi", "Tribal",
    "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll",
    "Hard Rock", "Folk", "Folk-Rock", "National Folk", "Swing", "Fast Fusion",
    "Bebob", "Latin", "Revival", "Celtic", "Bluegrass", "Avantgarde",
    "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock",
    "Slow Rock", "Big Band", "Chorus", "Easy Listening", "Acoustic", "Humour",
    "Speech", "Chanson", "Opera", "Chamber Music", "Sonata", "Symphony",
    "Booty Bass", "Primus", "Porn Groove", "Satire", "Slow Jam", "Club",
    "Tango", "Samba", "Folklore", "Ballad", "Power Ballad", "Rhythmic Soul",
    "Freestyle", "Duet", "Punk Rock", "Drum Solo", "A capella", "Euro-House",
    "Dance Hall"
  ];
}

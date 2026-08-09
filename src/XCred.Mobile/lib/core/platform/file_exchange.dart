import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PickedFileData {
  final String name;
  final Uint8List bytes;
  final String mimeType;
  const PickedFileData({required this.name, required this.bytes, required this.mimeType});
}

/// Platform abstraction for attachment upload/download — architecture.md §5/§6. One
/// interface, one implementation for now (Android); iOS-specific behavior, if any, is a
/// Phase 4 concern.
abstract class FileExchange {
  Future<PickedFileData?> pickFile();

  /// Saves [bytes] under [filename] and hands off to the OS share sheet — matches
  /// MOB-ATT-02: the file must open correctly with its original name/extension/MIME
  /// type, the mobile equivalent of the exact bug fixed in the web app earlier this
  /// project (attachment downloads losing their filename/type).
  Future<void> saveOrShare(String filename, Uint8List bytes, String mimeType);
}

class DefaultFileExchange implements FileExchange {
  @override
  Future<PickedFileData?> pickFile() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedFileData(
      name: file.name,
      bytes: bytes,
      mimeType: _guessMimeType(file.name),
    );
  }

  @override
  Future<void> saveOrShare(String filename, Uint8List bytes, String mimeType) async {
    // share_plus needs a real file on disk to attach — write to a scratch dir (not the
    // permanent app documents directory; this is a transient export, not vault storage).
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType, name: filename)]),
    );
  }

  static const Map<String, String> _extensionMimeTypes = {
    '.pdf': 'application/pdf',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.txt': 'text/plain',
    '.csv': 'text/csv',
    '.json': 'application/json',
    '.zip': 'application/zip',
    '.doc': 'application/msword',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls': 'application/vnd.ms-excel',
    '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  static String _guessMimeType(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return _extensionMimeTypes[ext] ?? 'application/octet-stream';
  }
}

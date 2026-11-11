import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A file picked, recorded or edited on this device. On Android and iOS its
/// path is a file path; on the web it is a `blob:` URL held by the page, which
/// `dart:io` cannot open.
class NusaChatLocalFile {
  const NusaChatLocalFile._(); // coverage:ignore-line

  /// Overrides [isWeb] in tests, so the web branches run on the VM.
  @visibleForTesting
  static bool? debugIsWeb;

  static bool get isWeb => debugIsWeb ?? kIsWeb;

  static Future<int> length(String path) => XFile(path).length();

  static Future<Uint8List> readAsBytes(String path) => XFile(path).readAsBytes();

  /// A blob URL cannot be checked without fetching it; it lives as long as the page.
  static bool exists(String path) => isWeb ? path.isNotEmpty : File(path).existsSync();

  static ImageProvider image(String path) => isWeb ? NetworkImage(path) : FileImage(File(path));
}

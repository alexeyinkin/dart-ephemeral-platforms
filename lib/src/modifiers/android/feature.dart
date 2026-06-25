import 'dart:io';

import 'package:path/path.dart' as p;

import '../modifier.dart';

/// Adds a `<uses-feature>` tag to AndroidManifest.xml.
class AndroidFeatureModifier extends Modifier {
  final String name;
  final bool? required;

  AndroidFeatureModifier(this.name, {this.required});

  @override
  Future<void> modify(String projectDir) async {
    final manifestPath = p.join(
      projectDir,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    );
    final file = File(manifestPath);

    if (!await file.exists()) {
      return;
    }

    final content = await file.readAsString();
    if (content.contains('<uses-feature android:name="$name"')) {
      return; // Already exists
    }

    final manifestIndex = content.indexOf('<manifest');
    if (manifestIndex == -1) return;

    final manifestEndIndex = content.indexOf('>', manifestIndex);
    if (manifestEndIndex == -1) return;

    final insertIndex = manifestEndIndex + 1;

    final requiredAttr = required != null
        ? ' android:required="$required"'
        : '';
    final tag = '\n    <uses-feature android:name="$name"$requiredAttr/>';

    final newContent =
        content.substring(0, insertIndex) +
        tag +
        content.substring(insertIndex);

    await file.writeAsString(newContent);
    print('Added Android feature $name to ${file.path}');
  }
}

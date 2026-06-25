import 'dart:io';

import 'package:path/path.dart' as p;

import '../modifier.dart';

/// Adds a `<uses-permission>` tag to AndroidManifest.xml.
class AndroidPermissionModifier extends Modifier {
  final String name;
  final Map<String, String> attributes;

  AndroidPermissionModifier(this.name, {this.attributes = const {}});

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
    if (content.contains('<uses-permission android:name="$name"')) {
      return; // Already exists
    }

    final manifestIndex = content.indexOf('<manifest');
    if (manifestIndex == -1) return;

    final manifestEndIndex = content.indexOf('>', manifestIndex);
    if (manifestEndIndex == -1) return;

    final insertIndex = manifestEndIndex + 1;

    final attributesStr = attributes.entries
        .map((e) => '${e.key}="${e.value}"')
        .join(' ');

    final tagAttributes = attributesStr.isNotEmpty ? ' $attributesStr' : '';
    final tag = '\n    <uses-permission android:name="$name"$tagAttributes/>';

    final newContent =
        content.substring(0, insertIndex) +
        tag +
        content.substring(insertIndex);

    await file.writeAsString(newContent);
    print('Added Android permission $name to ${file.path}');
  }
}

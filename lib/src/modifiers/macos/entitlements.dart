import 'dart:io';

import 'package:path/path.dart' as p;

import '../modifier.dart';

/// Adds a single entitlement [keyName] with [value].
class MacOsEntitlementsModifier extends Modifier {
  final String keyName;
  final bool value;

  MacOsEntitlementsModifier(this.keyName, this.value);

  @override
  Future<void> modify(String projectDir) async {
    final macosDir = p.join(projectDir, 'macos', 'Runner');
    final debugFile = File(p.join(macosDir, 'DebugProfile.entitlements'));
    final releaseFile = File(p.join(macosDir, 'Release.entitlements'));

    await _modifyEntitlementsFile(debugFile);
    await _modifyEntitlementsFile(releaseFile);
  }

  Future<void> _modifyEntitlementsFile(File file) async {
    if (!await file.exists()) {
      return;
    }

    final lines = await file.readAsLines();
    final newLines = <String>[];

    bool foundKey = false;
    bool updatingValue = false;
    bool inDict = false;
    int dictCloseIndex = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      if (trimmedLine == '<dict>') {
        inDict = true;
      }

      if (inDict && trimmedLine == '</dict>') {
        dictCloseIndex =
            newLines.length; // Will insert before this if not found
      }

      if (updatingValue) {
        // Replace the value line
        newLines.add('\t<${value ? 'true' : 'false'}/>');
        updatingValue = false;
        continue;
      }

      if (trimmedLine == '<key>$keyName</key>') {
        foundKey = true;
        updatingValue = true;
      }

      newLines.add(line);
    }

    if (!foundKey && dictCloseIndex != -1) {
      // Insert new key and value right before </dict>
      newLines.insert(dictCloseIndex, '\t<key>$keyName</key>');
      newLines.insert(dictCloseIndex + 1, '\t<${value ? 'true' : 'false'}/>');
    }

    await file.writeAsString('${newLines.join('\n')}\n');
    print('Modified ${file.path}');
  }
}

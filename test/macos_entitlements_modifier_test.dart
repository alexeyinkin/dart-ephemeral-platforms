import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ephemeral_platforms/ephemeral_platforms.dart';
import 'package:test/test.dart';

void main() {
  group('MacOsEntitlementsModifier', () {
    late Directory tempDir;
    late File debugFile;
    late File releaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('modifiers_test_');
      final runnerDir = Directory(p.join(tempDir.path, 'macos', 'Runner'));
      await runnerDir.create(recursive: true);

      debugFile = File(p.join(runnerDir.path, 'DebugProfile.entitlements'));
      releaseFile = File(p.join(runnerDir.path, 'Release.entitlements'));

      const initialXml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
</dict>
</plist>''';

      await debugFile.writeAsString(initialXml);
      await releaseFile.writeAsString(initialXml);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('updates existing entitlement', () async {
      final modifier = MacOsEntitlementsModifier(
        'com.apple.security.network.server',
        false,
      );
      await modifier.modify(tempDir.path);

      final debugContent = await debugFile.readAsString();

      const expectedXml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<false/>
</dict>
</plist>
''';

      expect(debugContent, expectedXml);
    });

    test('adds new entitlement', () async {
      final modifier = MacOsEntitlementsModifier(
        'com.apple.security.device.serial',
        true,
      );
      await modifier.modify(tempDir.path);

      final debugContent = await debugFile.readAsString();

      const expectedXml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
	<key>com.apple.security.device.serial</key>
	<true/>
</dict>
</plist>
''';

      expect(debugContent, expectedXml);
    });
  });
}

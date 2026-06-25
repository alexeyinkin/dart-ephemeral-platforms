import 'dart:io';

import 'package:ephemeral_platforms/src/modifiers/android/feature.dart';
import 'package:ephemeral_platforms/src/modifiers/android/permission.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Android Modifiers', () {
    late Directory tempDir;
    late File manifestFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'android_modifiers_test_',
      );
      final manifestDir = Directory(
        p.join(tempDir.path, 'android', 'app', 'src', 'main'),
      );
      await manifestDir.create(recursive: true);
      manifestFile = File(p.join(manifestDir.path, 'AndroidManifest.xml'));
      await manifestFile.writeAsString('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.app">
    <application
        android:label="app"
        android:name="\${applicationName}">
        <activity
            android:name=".MainActivity"
            android:exported="true">
        </activity>
    </application>
</manifest>
''');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('AndroidPermissionModifier adds permission', () async {
      final modifier = AndroidPermissionModifier(
        'android.permission.BLUETOOTH',
      );
      await modifier.modify(tempDir.path);

      final content = await manifestFile.readAsString();
      expect(
        content,
        contains(
          '<uses-permission android:name="android.permission.BLUETOOTH"/>',
        ),
      );
    });

    test('AndroidPermissionModifier adds permission with attributes', () async {
      final modifier = AndroidPermissionModifier(
        'android.permission.BLUETOOTH_SCAN',
        attributes: {'android:usesPermissionFlags': 'neverForLocation'},
      );
      await modifier.modify(tempDir.path);

      final content = await manifestFile.readAsString();
      expect(
        content,
        contains(
          '<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>',
        ),
      );
    });

    test('AndroidFeatureModifier adds feature', () async {
      final modifier = AndroidFeatureModifier('android.hardware.bluetooth');
      await modifier.modify(tempDir.path);

      final content = await manifestFile.readAsString();
      expect(
        content,
        contains('<uses-feature android:name="android.hardware.bluetooth"/>'),
      );
    });

    test('AndroidFeatureModifier adds feature with required flag', () async {
      final modifier = AndroidFeatureModifier(
        'android.hardware.bluetooth_le',
        required: false,
      );
      await modifier.modify(tempDir.path);

      final content = await manifestFile.readAsString();
      expect(
        content,
        contains(
          '<uses-feature android:name="android.hardware.bluetooth_le" android:required="false"/>',
        ),
      );
    });
  });
}

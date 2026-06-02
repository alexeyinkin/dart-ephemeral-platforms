import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';
import 'package:test/test.dart';

void main() {
  group('ephemeral_platforms integration', () {
    late Directory tempDir;
    late String packagePath;

    setUp(() async {
      packagePath = Directory.current.path;
      tempDir = await Directory.systemTemp.createTemp(
        'ephemeral_platforms_test_123_',
      );

      // Create a dummy flutter project
      await Shell(
        workingDirectory: tempDir.path,
      ).run('flutter create . --platforms macos --project-name dummy_app');

      // Add ephemeral_platforms.yaml
      final yamlContent = '''
ephemeral_platforms:
  flutter_create:
    org: com.example.test
  platforms:
    macos:
      enabled: true
      entitlements:
        com.apple.security.device.serial: true
        com.apple.security.network.server: false
''';
      await File(
        p.join(tempDir.path, 'ephemeral_platforms.yaml'),
      ).writeAsString(yamlContent);

      // Add macos/ to .gitignore to mimic the actual use-case
      final gitignoreFile = File(p.join(tempDir.path, '.gitignore'));
      await gitignoreFile.writeAsString('\nmacos/\n', mode: FileMode.append);

      // Initialize git to simulate version control
      final shell = Shell(workingDirectory: tempDir.path);
      await shell.run('git init');
      await shell.run('git config user.email "test@example.com"');
      await shell.run('git config user.name "Test User"');
      await shell.run('git add .');
      await shell.run('git commit -m "Init"');

      // Create dummy file AFTER commit so it is untracked
      final dummyFile = File(
        p.join(tempDir.path, 'macos', 'dummy_untracked.txt'),
      );
      if (!await dummyFile.parent.exists()) {
        await dummyFile.parent.create(recursive: true);
      }
      await dummyFile.writeAsString('I should be deleted');

      print('Dummy file exists before run: ${await dummyFile.exists()}');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('cleans, recreates and applies overrides', () async {
      final shell = Shell(workingDirectory: tempDir.path);

      // Run the package CLI via dart run
      await shell.run(
        'dart run ${p.join(packagePath, 'bin', 'apply.dart')}',
      );

      // Verify the untracked dummy file was deleted
      final dummyFile = File(
        p.join(tempDir.path, 'macos', 'dummy_untracked.txt'),
      );
      expect(
        await dummyFile.exists(),
        isFalse,
        reason: 'Untracked file should have been cleaned',
      );

      // Verify the flutter create arg (--org com.example.test) was applied
      final pbxprojFile = File(
        p.join(tempDir.path, 'macos', 'Runner.xcodeproj', 'project.pbxproj'),
      );
      final pbxprojContent = await pbxprojFile.readAsString();
      expect(
        pbxprojContent,
        contains('com.example.test'),
        reason: 'Organization should be applied to Xcode project',
      );

      // Verify entitlements are modified
      final debugFile = File(
        p.join(tempDir.path, 'macos', 'Runner', 'DebugProfile.entitlements'),
      );
      final content = await debugFile.readAsString();

      expect(content, contains('<key>com.apple.security.network.server</key>'));
      expect(
        content,
        contains('<false/>'),
        reason: 'Network server should be set to false',
      );
      expect(content, contains('<key>com.apple.security.device.serial</key>'));
      expect(
        content,
        contains('<true/>'),
        reason: 'Device serial should be set to true',
      );
    });
  });
}

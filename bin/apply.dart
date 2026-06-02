import 'dart:io';

import 'package:ephemeral_platforms/ephemeral_platforms.dart';

void main(List<String> arguments) async {
  final manager = EphemeralPlatformsManager(Directory.current.path);
  try {
    await manager.run();
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    stderr.writeln('Error running apply: $e');
    exitCode = 1;
  }
}

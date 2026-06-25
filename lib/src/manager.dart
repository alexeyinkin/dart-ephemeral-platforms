import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'modifiers/android/feature.dart';
import 'modifiers/android/permission.dart';
import 'modifiers/macos/entitlements.dart';
import 'modifiers/modifier.dart';

/// Cleans the platform directories, runs `flutter create`,
/// and applies the config.
class EphemeralPlatformsManager {
  final String projectPath;

  EphemeralPlatformsManager(this.projectPath);

  /// Cleans the platform directories, runs `flutter create`,
  /// and applies the config.
  Future<void> run() async {
    final config = await _loadConfig();
    if (config == null) {
      throw Exception('No ephemeral_platforms configuration found.');
    }

    final enabledPlatforms = _getEnabledPlatforms(config);
    if (enabledPlatforms.isEmpty) {
      throw Exception('No enabled platforms found in configuration.');
    }

    final modifiers = _parseModifiers(config, enabledPlatforms);
    final flutterCreateArgs = config['flutter_create'] as YamlMap?;

    await _cleanPlatforms(enabledPlatforms);
    await _runFlutterCreate(enabledPlatforms, flutterCreateArgs);

    for (final modifier in modifiers) {
      await modifier.modify(projectPath);
    }
  }

  Future<YamlMap?> _loadConfig() async {
    // Check pubspec.yaml first
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      final pubspecYaml = loadYaml(await pubspecFile.readAsString()) as YamlMap;
      if (pubspecYaml.containsKey('ephemeral_platforms')) {
        return pubspecYaml['ephemeral_platforms'] as YamlMap;
      }
    }

    // Check ephemeral_platforms.yaml
    final configFile = File(p.join(projectPath, 'ephemeral_platforms.yaml'));
    if (configFile.existsSync()) {
      final configYaml = loadYaml(await configFile.readAsString());
      // Handle case where ephemeral_platforms.yaml has a top-level `ephemeral_platforms` key or is just the raw map
      if (configYaml is YamlMap) {
        if (configYaml.containsKey('ephemeral_platforms')) {
          return configYaml['ephemeral_platforms'] as YamlMap;
        }
        return configYaml;
      }
    }

    return null;
  }

  List<String> _getEnabledPlatforms(YamlMap config) {
    final platforms = <String>[];

    final platformsConfig = config['platforms'];
    if (platformsConfig is YamlMap) {
      for (final key in platformsConfig.keys) {
        final platformConfig = platformsConfig[key];
        if (platformConfig is YamlMap) {
          final enabled = platformConfig['enabled'];
          // Default is enabled unless explicitly false
          if (enabled == null || enabled == true) {
            platforms.add(key.toString());
          }
        } else {
          // Default is enabled for simple configs
          platforms.add(key.toString());
        }
      }
    }
    return platforms;
  }

  List<Modifier> _parseModifiers(
    YamlMap config,
    List<String> enabledPlatforms,
  ) {
    final modifiers = <Modifier>[];
    final platformsConfig = config['platforms'];

    if (platformsConfig is YamlMap) {
      for (final platform in enabledPlatforms) {
        final platformConfig = platformsConfig[platform];
        if (platformConfig is YamlMap) {
          switch (platform) {
            case 'android':
              modifiers.addAll(_parseAndroidModifiers(platformConfig));
            case 'macos':
              modifiers.addAll(_parseMacOsModifiers(platformConfig));
          }
        }
      }
    }

    return modifiers;
  }

  List<Modifier> _parseMacOsModifiers(YamlMap platformConfig) {
    final modifiers = <Modifier>[];
    if (platformConfig.containsKey('entitlements')) {
      final entitlements = platformConfig['entitlements'];
      if (entitlements is YamlMap) {
        modifiers.addAll(_parseMacOsEntitlements(entitlements));
      }
    }
    return modifiers;
  }

  List<Modifier> _parseAndroidModifiers(YamlMap platformConfig) {
    final modifiers = <Modifier>[];

    if (platformConfig.containsKey('permissions')) {
      final permissions = platformConfig['permissions'];
      if (permissions is YamlMap) {
        modifiers.addAll(_parseAndroidPermissions(permissions));
      }
    }

    if (platformConfig.containsKey('features')) {
      final features = platformConfig['features'];
      if (features is YamlMap) {
        modifiers.addAll(_parseAndroidFeatures(features));
      }
    }

    return modifiers;
  }

  List<Modifier> _parseAndroidPermissions(YamlMap permissions) {
    final modifiers = <Modifier>[];
    for (final entry in permissions.entries) {
      final name = entry.key.toString();
      final value = entry.value;

      switch (value) {
        case true:
        case null:
          modifiers.add(AndroidPermissionModifier(name));
        case YamlMap map:
          final attributes = <String, String>{};
          for (final attr in map.entries) {
            attributes[attr.key.toString()] = attr.value.toString();
          }
          modifiers.add(
            AndroidPermissionModifier(name, attributes: attributes),
          );
      }
    }
    return modifiers;
  }

  List<Modifier> _parseAndroidFeatures(YamlMap features) {
    final modifiers = <Modifier>[];
    for (final entry in features.entries) {
      final name = entry.key.toString();
      final value = entry.value;

      switch (value) {
        case true:
        case null:
          modifiers.add(AndroidFeatureModifier(name));
        case YamlMap map:
          final requiredFlag = map['required'];
          modifiers.add(
            AndroidFeatureModifier(
              name,
              required: requiredFlag is bool ? requiredFlag : null,
            ),
          );
      }
    }
    return modifiers;
  }

  List<Modifier> _parseMacOsEntitlements(YamlMap entitlementsConfig) {
    final modifiers = <Modifier>[];
    for (final entry in entitlementsConfig.entries) {
      if (entry.value is bool) {
        modifiers.add(
          MacOsEntitlementsModifier(entry.key.toString(), entry.value as bool),
        );
      }
    }
    return modifiers;
  }

  Future<void> _cleanPlatforms(List<String> platforms) async {
    for (final platform in platforms) {
      final platformDir = Directory(p.join(projectPath, platform));
      if (platformDir.existsSync()) {
        print('Cleaning platform: $platform');
        final result = await Process.run('git', [
          'clean',
          '-fdx',
          platform,
        ], workingDirectory: projectPath);
        if (result.exitCode != 0) {
          throw Exception('Failed to clean $platform:\n${result.stderr}');
        }
      }
    }
  }

  Future<void> _runFlutterCreate(
    List<String> platforms,
    YamlMap? createArgs,
  ) async {
    final args = ['create', '.'];

    if (createArgs != null) {
      for (final entry in createArgs.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (value is bool) {
          if (value) {
            args.add('--$key');
          }
        } else {
          args.add('--$key');
          args.add(value.toString());
        }
      }
    }

    args.add('--platforms');
    args.add(platforms.join(','));

    print('Running flutter create with args: ${args.join(' ')}');
    final result = await Process.run(
      'flutter',
      args,
      workingDirectory: projectPath,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to run flutter create:\n${result.stderr}');
    }
  }
}

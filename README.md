Re-creates the platform directories and applies modifications from your config.

## The Problem

A Flutter app for each platform requires platform directories:
`ios`, `android`, `macos`, `windows`, `linux`, and `web`.
New Flutter versions bring changes to what's expected to be there.
As a result, at some point a Flutter app stops building even if you don't touch it.
The code may be perfectly fine, it's just the config —
the new Flutter may not support your older Gradle version,
or something happens to CocoaPods, etc.

The current industry solution is to own entire platform directories
with all config in them
and fix these issues manually when stuff breaks.

The hobbyist solution is to delete a platform directory
when the app stops building
and create a new one with `flutter create --platforms=...`

This creates a blank platform directory with up-to-date config
that will build, but if you had anything customized it gets lost.
You then need to adjust permissions and other stuff.

## The Solution

This package allows you to specify
just how your platform directories should differ
from whatever the current default is.
It deletes the platform directories for you
and applies those targeted changes.

This allows you to own the very few lines that matter
instead of the entire platform directories with tens of files
and thousands of lines of boilerplate config.

## Usage

### 1. Add the package to dev_dependencies

### 2. Define the config

In the root directory of your app,
create the file `ephemeral_platforms.yaml`:

```yaml
platforms:
  macos:
    entitlements:
      com.apple.security.device.serial: true
```

### 3. Remove the platform directories from version control

You may keep the files you want to preserve under version control.


### 4. Run the command

```bash
dart run ephemeral_platforms:apply
```

It will:

1. In every configured platform, delete all files not under version control.
2. For every platform, run `flutter create`.
3. Apply changes from your config.


## Supported Config Changes

I created this package to solve my immediate problems.
As a result, it only supports the platforms and the changes I had to preserve.
The example in the usage shows the entire supported config.

## Adding Support for More Configuration

The `modifiers` directory contains all supported modifiers,
one `Modifier` subclass per type of supported modification.

1. Study the currently included modifiers.
2. Create your own after them.
3. Add the code to instantiate it from YAML to `EphemeralPlatformsManager`.
4. Add tests. Ideally, they should make sure the app still builds.
5. Submit a PR.

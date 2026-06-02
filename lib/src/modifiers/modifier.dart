/// The base class for all modifiers.
abstract class Modifier {
  /// Applies the modification.
  Future<void> modify(String projectDir);
}

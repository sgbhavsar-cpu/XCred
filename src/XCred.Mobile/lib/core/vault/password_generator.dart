import 'dart:math';

// Ported from crypto.ts's generatePassword — same character sets, same modulo-indexed
// selection from a Random.secure() source (the Dart equivalent of
// crypto.getRandomValues), so generated passwords have the same character-class
// composition behavior as the web app's generator (not byte-identical output, since
// it's independently random each time by design).
class PasswordGeneratorOptions {
  final int length;
  final bool uppercase;
  final bool lowercase;
  final bool numbers;
  final bool symbols;
  final bool excludeAmbiguous;

  const PasswordGeneratorOptions({
    this.length = 20,
    this.uppercase = true,
    this.lowercase = true,
    this.numbers = true,
    this.symbols = true,
    this.excludeAmbiguous = false,
  });

  bool get hasAnyClassSelected => uppercase || lowercase || numbers || symbols;

  PasswordGeneratorOptions copyWith({
    int? length,
    bool? uppercase,
    bool? lowercase,
    bool? numbers,
    bool? symbols,
    bool? excludeAmbiguous,
  }) =>
      PasswordGeneratorOptions(
        length: length ?? this.length,
        uppercase: uppercase ?? this.uppercase,
        lowercase: lowercase ?? this.lowercase,
        numbers: numbers ?? this.numbers,
        symbols: symbols ?? this.symbols,
        excludeAmbiguous: excludeAmbiguous ?? this.excludeAmbiguous,
      );
}

/// Returns null when no character class is selected — unlike crypto.ts's web
/// implementation (which silently falls back to lowercase-only), the mobile UX
/// requirement (sprint-plan.md MOB-GEN-01) is to disable generation with a clear
/// message instead of silently producing a weaker password than requested.
String? generatePassword(PasswordGeneratorOptions options) {
  if (!options.hasAnyClassSelected) return null;

  var chars = '';
  if (options.uppercase) {
    chars += options.excludeAmbiguous ? 'ABCDEFGHJKLMNPQRSTUVWXYZ' : 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  }
  if (options.lowercase) {
    chars += options.excludeAmbiguous ? 'abcdefghjkmnpqrstuvwxyz' : 'abcdefghijklmnopqrstuvwxyz';
  }
  if (options.numbers) {
    chars += options.excludeAmbiguous ? '23456789' : '0123456789';
  }
  if (options.symbols) {
    chars += '!@#\$%^&*()_+-=[]{}|;:,.<>?';
  }

  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < options.length; i++) {
    buffer.write(chars[random.nextInt(chars.length)]);
  }
  return buffer.toString();
}

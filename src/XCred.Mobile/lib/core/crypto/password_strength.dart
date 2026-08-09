// Port of passwordStrength() in src/XCred.Web/src/lib/crypto.ts — display-only, not a
// security control, so exact algorithmic parity (unlike CryptoService) isn't required,
// just a consistent-feeling meter.
class PasswordStrength {
  final int score; // 0-4
  final String label;
  const PasswordStrength(this.score, this.label);
}

PasswordStrength passwordStrength(String password) {
  if (password.isEmpty) return const PasswordStrength(0, 'None');
  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 14) score++;
  if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
  if (password.length >= 20) score = (score + 1).clamp(0, 5);
  final clamped = (score / 1.2).floor().clamp(0, 4);
  const labels = ['Very Weak', 'Weak', 'Fair', 'Strong', 'Very Strong'];
  return PasswordStrength(clamped, labels[clamped]);
}

import 'package:flutter/material.dart';

import '../../../core/crypto/password_strength.dart';
import '../../../core/vault/password_generator.dart';

/// MOB-GEN-01 — bottom sheet matching the validated mockup: length slider (8-128,
/// default 20), 4 character-class toggles + exclude-ambiguous, live regenerate,
/// strength meter, "Use This Password" writes back to the calling field.
Future<String?> showPasswordGeneratorSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _PasswordGeneratorSheet(),
  );
}

class _PasswordGeneratorSheet extends StatefulWidget {
  const _PasswordGeneratorSheet();

  @override
  State<_PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<_PasswordGeneratorSheet> {
  PasswordGeneratorOptions _options = const PasswordGeneratorOptions();
  String? _generated;

  @override
  void initState() {
    super.initState();
    _generated = generatePassword(_options);
  }

  void _update(PasswordGeneratorOptions options) {
    setState(() {
      _options = options;
      _generated = generatePassword(options);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strength = _generated != null ? passwordStrength(_generated!) : null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Password Generator', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _generated ?? 'Select at least one character type',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _generated == null ? Theme.of(context).hintColor : null,
              ),
            ),
          ),
          if (strength != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Strength', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text(strength.label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (strength.score + 1) / 5,
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Length', style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text('${_options.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            min: 8,
            max: 128,
            value: _options.length.toDouble(),
            onChanged: (v) => _update(_options.copyWith(length: v.round())),
          ),
          Wrap(
            spacing: 4,
            children: [
              _classToggle('Uppercase (A-Z)', _options.uppercase,
                  (v) => _update(_options.copyWith(uppercase: v))),
              _classToggle('Lowercase (a-z)', _options.lowercase,
                  (v) => _update(_options.copyWith(lowercase: v))),
              _classToggle('Numbers (0-9)', _options.numbers,
                  (v) => _update(_options.copyWith(numbers: v))),
              _classToggle('Symbols (!@#…)', _options.symbols,
                  (v) => _update(_options.copyWith(symbols: v))),
              _classToggle('Exclude ambiguous', _options.excludeAmbiguous,
                  (v) => _update(_options.copyWith(excludeAmbiguous: v))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _update(_options),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerate'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _generated == null
                      ? null
                      : () => Navigator.of(context).pop(_generated),
                  child: const Text('Use This Password'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _classToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: value,
      onSelected: onChanged,
    );
  }
}

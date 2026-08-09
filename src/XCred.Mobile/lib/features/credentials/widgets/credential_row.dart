import 'package:flutter/material.dart';

import '../../../core/models/credential_models.dart';
import '../../../core/vault/credential_type_meta.dart';

/// Shared row rendering for the Credentials tree screen (grouped and ungrouped
/// sections both use this) — mirrors the web app's `CredentialRow.tsx`.
class CredentialRow extends StatelessWidget {
  const CredentialRow({
    required this.cred,
    required this.decrypted,
    required this.onTap,
    this.indent = false,
    super.key,
  });

  final CredentialListItem cred;
  final DecryptedCredentialMeta? decrypted;
  final VoidCallback onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      credentialTypeLabel(cred.type),
      if (decrypted?.subtitle != null && decrypted!.subtitle!.isNotEmpty) decrypted!.subtitle!,
    ];
    return ListTile(
      contentPadding: EdgeInsets.only(left: indent ? 48 : 16, right: 16),
      leading: Text(credentialTypeIcon(cred.type), style: const TextStyle(fontSize: 24)),
      title: Row(
        children: [
          Flexible(
            child: Text(decrypted?.name ?? '…',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (cred.isExpired) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Expired', style: TextStyle(fontSize: 10, color: Colors.red)),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitleParts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

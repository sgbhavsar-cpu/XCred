// Ported from src/XCred.Web/src/lib/links.ts — see that file's comment for the researched
// scheme reliability notes (http(s)/mailto/tel are native; ssh/telnet/rdp are best-effort,
// only doing anything if the device has a registered handler app).
import 'package:url_launcher/url_launcher.dart';

import 'credential_fields.dart';

bool isValidUrl(String value) {
  final v = value.trim();
  if (v.isEmpty) return false;
  final uri = Uri.tryParse(v);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

String mailtoLink(String email) => 'mailto:${email.trim()}';

String telLink(String phone) => 'tel:${phone.trim().replaceAll(RegExp(r'[^\d+]'), '')}';

String sshLink(String host, String? username) {
  final user = username?.trim();
  final prefix = (user != null && user.isNotEmpty) ? '${Uri.encodeComponent(user)}@' : '';
  return 'ssh://$prefix${host.trim()}';
}

String rdpLink(String host, String? port) {
  final trimmedPort = port?.trim();
  final portSuffix = (trimmedPort != null && trimmedPort.isNotEmpty && trimmedPort != '3389')
      ? ':$trimmedPort'
      : '';
  return 'rdp://${host.trim()}$portSuffix';
}

String? networkDeviceLink(String? protocol, String host, String? port) {
  final trimmedHost = host.trim();
  if (trimmedHost.isEmpty) return null;
  final trimmedPort = port?.trim();
  switch (protocol) {
    case 'Web':
      final scheme = trimmedPort == '443' ? 'https' : 'http';
      final portSuffix = (trimmedPort != null &&
              trimmedPort.isNotEmpty &&
              trimmedPort != '80' &&
              trimmedPort != '443')
          ? ':$trimmedPort'
          : '';
      return '$scheme://$trimmedHost$portSuffix';
    case 'Telnet':
      return 'telnet://$trimmedHost${(trimmedPort != null && trimmedPort.isNotEmpty) ? ':$trimmedPort' : ''}';
    case 'SSH':
      return 'ssh://$trimmedHost${(trimmedPort != null && trimmedPort.isNotEmpty) ? ':$trimmedPort' : ''}';
    default:
      return null;
  }
}

/// Resolves the "open" link (if any) for a single field, given the full set of
/// currently-decrypted field values (some links, like SSH, borrow a sibling field —
/// e.g. `username` — the same way the web app's `computeFieldLink` does).
String? computeFieldLink(FieldDef field, String value, Map<String, String> allValues) {
  final v = value.trim();
  if (v.isEmpty) return null;
  if (field.type == 'url') return isValidUrl(v) ? v : null;
  switch (field.linkType) {
    case 'email':
      return mailtoLink(v);
    case 'tel':
      return telLink(v);
    case 'ssh':
      return sshLink(v, allValues['username']);
    case 'rdp':
      return rdpLink(v, allValues['port']);
    default:
      return null;
  }
}

Future<void> openSmartLink(String href) async {
  final uri = Uri.parse(href);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String linkTooltip(FieldDef field) {
  switch (field.linkType) {
    case 'email':
      return 'Open in your default mail app';
    case 'tel':
      return 'Call with your default phone/VoIP app';
    case 'ssh':
      return 'Open with your registered SSH handler, if one is configured — otherwise '
          'nothing will happen';
    case 'rdp':
      return 'Open with your registered RDP client, if one is configured — otherwise '
          'nothing will happen';
    case 'network-device-ip':
      return 'Open — for Telnet/SSH this needs a registered handler app to actually do '
          'anything';
    default:
      return 'Open';
  }
}

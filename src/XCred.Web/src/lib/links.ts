import { isValidUrl } from './utils';
import type { FieldDef } from './vault';

// Which schemes are reliable vs. best-effort (researched — see docs/requirements.md §11.1):
// - http(s):, mailto:, tel: — natively handled by every browser, no setup required.
// - ssh:, telnet: — valid IANA URI schemes, but neither browser ships a built-in handler;
//   they only do anything if the user has registered a local app for that scheme
//   (e.g. via Windows registry, PuTTY, OpenSSH). We still offer the link — it's a free
//   convenience when configured, and a harmless no-op/browser error when it isn't.

export function mailtoLink(email: string): string {
  return `mailto:${email.trim()}`;
}

export function telLink(phone: string): string {
  return `tel:${phone.trim().replace(/[^\d+]/g, '')}`;
}

export function sshLink(host: string, username?: string): string {
  const user = username?.trim();
  return `ssh://${user ? `${encodeURIComponent(user)}@` : ''}${host.trim()}`;
}

export function networkDeviceLink(protocol: string, host: string, port?: string): string | null {
  const trimmedHost = host.trim();
  if (!trimmedHost) return null;
  const trimmedPort = port?.trim();
  switch (protocol) {
    case 'Web': {
      const scheme = trimmedPort === '443' ? 'https' : 'http';
      const portSuffix = trimmedPort && trimmedPort !== '80' && trimmedPort !== '443' ? `:${trimmedPort}` : '';
      return `${scheme}://${trimmedHost}${portSuffix}`;
    }
    case 'Telnet':
      return `telnet://${trimmedHost}${trimmedPort ? `:${trimmedPort}` : ''}`;
    case 'SSH':
      return `ssh://${trimmedHost}${trimmedPort ? `:${trimmedPort}` : ''}`;
    default:
      return null;
  }
}

/** Resolves the "open" link (if any) for a single field, given the full set of currently-entered field values. */
export function computeFieldLink(field: FieldDef, value: string, allValues: Record<string, string>): string | null {
  const v = value.trim();
  if (!v) return null;
  if (field.type === 'url') return isValidUrl(v) ? v : null;
  switch (field.linkType) {
    case 'email': return mailtoLink(v);
    case 'tel': return telLink(v);
    case 'ssh': return sshLink(v, allValues.username);
    default: return null;
  }
}

/** http(s) opens in a new tab (stay in the vault); custom schemes (mailto/tel/ssh/telnet) hand off
 *  to the OS without navigating the current page, so we assign location.href instead. */
export function openSmartLink(href: string) {
  if (href.startsWith('http://') || href.startsWith('https://')) {
    window.open(href, '_blank', 'noopener,noreferrer');
  } else {
    window.location.href = href;
  }
}

export function linkTooltip(field: FieldDef): string {
  switch (field.linkType) {
    case 'email': return 'Open in your default mail app';
    case 'tel': return 'Call with your default phone/VoIP app';
    case 'ssh': return 'Open with your registered SSH handler, if one is configured (e.g. Windows OpenSSH or PuTTY registry setup) — otherwise nothing will happen';
    case 'network-device-ip': return 'Open — for Telnet/SSH this needs a registered handler app to actually do anything';
    default: return 'Open in a new tab';
  }
}

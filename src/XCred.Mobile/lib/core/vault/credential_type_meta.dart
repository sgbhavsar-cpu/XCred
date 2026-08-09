// Ported from src/XCred.Web/src/lib/utils.ts's credentialTypeLabel/credentialTypeIcon.
const Map<String, String> _kTypeLabels = {
  'WebsiteLogin': 'Website Login',
  'Database': 'Database',
  'ApiKey': 'API Key',
  'SshKey': 'SSH Key',
  'CreditCard': 'Payment Card',
  'SecureNote': 'Secure Note',
  'WiFi': 'Wi-Fi',
  'SoftwareLicense': 'Software License',
  'Certificate': 'Certificate',
  'EnvironmentVariables': 'Environment Variables',
  'BankAccount': 'Bank Account',
  'MobileBankingPin': 'Mobile Banking PIN',
  'NetworkDevice': 'Network Device',
  'Rdp': 'Remote Desktop (RDP)',
  'EmailAccount': 'Email Account',
  'IdentityDocument': 'Identity Document',
  'InsurancePolicy': 'Insurance Policy',
  'RecoveryCodes': 'Recovery Codes',
  'Generic': 'Generic',
};

const Map<String, String> _kTypeIcons = {
  'WebsiteLogin': '🌐',
  'Database': '🗄️',
  'ApiKey': '🔑',
  'SshKey': '🖥️',
  'CreditCard': '💳',
  'SecureNote': '📝',
  'WiFi': '📶',
  'SoftwareLicense': '📦',
  'Certificate': '📜',
  'EnvironmentVariables': '⚙️',
  'BankAccount': '🏦',
  'MobileBankingPin': '📱',
  'NetworkDevice': '🌐',
  'Rdp': '🖧',
  'EmailAccount': '📧',
  'IdentityDocument': '🪪',
  'InsurancePolicy': '🛡️',
  'RecoveryCodes': '🔢',
  'Generic': '🔒',
};

String credentialTypeLabel(String type) => _kTypeLabels[type] ?? type;
String credentialTypeIcon(String type) => _kTypeIcons[type] ?? '🔒';

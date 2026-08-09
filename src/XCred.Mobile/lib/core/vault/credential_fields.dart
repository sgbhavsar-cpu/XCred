// Ported field-for-field from src/XCred.Web/src/lib/vault.ts's CREDENTIAL_FIELDS — the
// authoritative per-type field inventory. Keep in sync manually; there's no shared
// schema between the TS and Dart codebases (see requirements §6.2's interop note — only
// the *crypto* is required to be byte-identical, not the UI field table, but drifting
// this out of sync would silently break credentials created on one platform and viewed
// on the other).
class FieldDef {
  final String key;
  final String label;
  final String type; // text | password | textarea | select | url | list
  final String? placeholder;
  final bool optional;
  final List<String>? options;
  final int? rows;
  final String? linkType; // email | tel | ssh | rdp | network-device-ip

  const FieldDef({
    required this.key,
    required this.label,
    required this.type,
    this.placeholder,
    this.optional = false,
    this.options,
    this.rows,
    this.linkType,
  });
}

const Map<String, List<FieldDef>> kCredentialFields = {
  'WebsiteLogin': [
    FieldDef(key: 'url', label: 'URL', type: 'url', placeholder: 'https://example.com'),
    FieldDef(key: 'username', label: 'Username / Email', type: 'text'),
    FieldDef(key: 'password', label: 'Password', type: 'password'),
    FieldDef(key: 'totp', label: 'TOTP Secret', type: 'text', optional: true),
    FieldDef(key: 'recoveryEmail', label: 'Recovery Email', type: 'text', optional: true, linkType: 'email'),
    FieldDef(key: 'recoveryPhone', label: 'Recovery Phone', type: 'text', optional: true, linkType: 'tel'),
  ],
  'Database': [
    FieldDef(key: 'host', label: 'Host', type: 'text'),
    FieldDef(key: 'port', label: 'Port', type: 'text'),
    FieldDef(key: 'database', label: 'Database Name', type: 'text'),
    FieldDef(key: 'username', label: 'Username', type: 'text'),
    FieldDef(key: 'password', label: 'Password', type: 'password'),
    FieldDef(key: 'connectionType', label: 'Connection Type', type: 'select', options: [
      'PostgreSQL', 'MySQL', 'SQL Server', 'Oracle', 'MongoDB', 'Redis', 'SQLite', 'Other'
    ]),
  ],
  'ApiKey': [
    FieldDef(key: 'serviceName', label: 'Service Name', type: 'text'),
    FieldDef(key: 'keyValue', label: 'API Key / Token', type: 'password'),
    FieldDef(key: 'keyId', label: 'Key ID / Client ID', type: 'text', optional: true),
    FieldDef(key: 'environment', label: 'Environment', type: 'select', options: [
      'Production', 'Staging', 'Development', 'Testing'
    ]),
  ],
  'SshKey': [
    FieldDef(key: 'host', label: 'Host / Server', type: 'text', optional: true, linkType: 'ssh'),
    FieldDef(key: 'username', label: 'Username', type: 'text', optional: true),
    FieldDef(key: 'privateKey', label: 'Private Key', type: 'textarea', rows: 6),
    FieldDef(key: 'publicKey', label: 'Public Key', type: 'textarea', optional: true, rows: 3),
    FieldDef(key: 'passphrase', label: 'Passphrase', type: 'password', optional: true),
  ],
  'CreditCard': [
    FieldDef(key: 'cardholderName', label: 'Cardholder Name', type: 'text'),
    FieldDef(key: 'cardNumber', label: 'Card Number', type: 'text'),
    FieldDef(key: 'cardNetwork', label: 'Card Network', type: 'select', optional: true, options: [
      'Visa', 'Mastercard', 'RuPay', 'Amex', 'Other'
    ]),
    FieldDef(key: 'expiryMonth', label: 'Expiry Month', type: 'text'),
    FieldDef(key: 'expiryYear', label: 'Expiry Year', type: 'text'),
    FieldDef(key: 'cvv', label: 'CVV', type: 'password'),
    FieldDef(key: 'atmPin', label: 'ATM PIN', type: 'password', optional: true),
    FieldDef(key: 'billingAddress', label: 'Billing Address', type: 'textarea', optional: true, rows: 2),
  ],
  'SecureNote': [
    FieldDef(key: 'body', label: 'Note Content', type: 'textarea', rows: 8),
  ],
  'WiFi': [
    FieldDef(key: 'ssid', label: 'Network Name (SSID)', type: 'text'),
    FieldDef(key: 'password', label: 'Password', type: 'password'),
    FieldDef(key: 'securityType', label: 'Security Type', type: 'select', options: [
      'WPA3', 'WPA2', 'WPA', 'WEP', 'Open'
    ]),
  ],
  'SoftwareLicense': [
    FieldDef(key: 'productName', label: 'Product Name', type: 'text'),
    FieldDef(key: 'licenseKey', label: 'License Key', type: 'password'),
    FieldDef(key: 'licenseHolder', label: 'License Holder', type: 'text', optional: true),
    FieldDef(key: 'seats', label: 'Seats / Quantity', type: 'text', optional: true),
    FieldDef(key: 'vendor', label: 'Vendor', type: 'text', optional: true),
  ],
  'Certificate': [
    FieldDef(key: 'certificate', label: 'Certificate (PEM)', type: 'textarea', rows: 6),
    FieldDef(key: 'privateKey', label: 'Private Key (PEM)', type: 'textarea', optional: true, rows: 6),
    FieldDef(key: 'passphrase', label: 'Passphrase', type: 'password', optional: true),
    FieldDef(key: 'issuer', label: 'Issuer / CA', type: 'text', optional: true),
  ],
  'EnvironmentVariables': [
    FieldDef(key: 'content', label: 'Environment Variables (.env format)', type: 'textarea', rows: 10),
  ],
  'BankAccount': [
    FieldDef(key: 'bankName', label: 'Bank Name', type: 'text'),
    FieldDef(key: 'accountHolderName', label: 'Account Holder Name', type: 'text'),
    FieldDef(key: 'accountNumber', label: 'Account Number', type: 'password'),
    FieldDef(key: 'ifscSwiftCode', label: 'IFSC / SWIFT Code', type: 'text'),
    FieldDef(key: 'branch', label: 'Branch', type: 'text', optional: true),
    FieldDef(key: 'accountType', label: 'Account Type', type: 'select', options: [
      'Savings', 'Current', 'Salary', 'Fixed Deposit', 'Loan', 'Other'
    ]),
    FieldDef(key: 'customerId', label: 'Customer ID (CIF)', type: 'text', optional: true),
  ],
  'MobileBankingPin': [
    FieldDef(key: 'bankOrAppName', label: 'Bank / App Name', type: 'text'),
    FieldDef(key: 'mobileNumber', label: 'Mobile Number', type: 'text', linkType: 'tel'),
    FieldDef(key: 'customerId', label: 'Customer ID', type: 'text', optional: true),
    FieldDef(key: 'loginPin', label: 'Login PIN', type: 'password'),
    FieldDef(key: 'transactionPin', label: 'Transaction PIN (MPIN)', type: 'password'),
  ],
  'NetworkDevice': [
    FieldDef(key: 'deviceName', label: 'Device Name', type: 'text'),
    FieldDef(key: 'ipAddresses', label: 'IP Address(es)', type: 'list', linkType: 'network-device-ip'),
    FieldDef(key: 'protocol', label: 'Protocol', type: 'select', options: ['Web', 'Telnet', 'SSH', 'Other']),
    FieldDef(key: 'port', label: 'Port', type: 'text', optional: true),
    FieldDef(key: 'username', label: 'Username', type: 'text'),
    FieldDef(key: 'password', label: 'Password', type: 'password'),
  ],
  'Rdp': [
    FieldDef(key: 'host', label: 'Host / Server', type: 'text', linkType: 'rdp'),
    FieldDef(key: 'port', label: 'Port', type: 'text', optional: true),
    FieldDef(key: 'domain', label: 'Domain', type: 'text', optional: true),
    FieldDef(key: 'username', label: 'Username', type: 'text'),
    FieldDef(key: 'password', label: 'Password', type: 'password'),
  ],
  'EmailAccount': [
    FieldDef(key: 'emailAddress', label: 'Email Address', type: 'text', linkType: 'email'),
    FieldDef(key: 'password', label: 'Password', type: 'password'),
    FieldDef(key: 'recoveryEmail', label: 'Recovery Email', type: 'text', optional: true, linkType: 'email'),
    FieldDef(key: 'recoveryPhone', label: 'Recovery Phone', type: 'text', optional: true, linkType: 'tel'),
    FieldDef(key: 'imapSmtpHost', label: 'IMAP / SMTP Host', type: 'text', optional: true),
  ],
  'IdentityDocument': [
    FieldDef(key: 'documentType', label: 'Document Type', type: 'select', options: [
      'Passport', 'Aadhaar', 'PAN', 'Driving License', 'Other'
    ]),
    FieldDef(key: 'documentNumber', label: 'Document Number', type: 'password'),
    FieldDef(key: 'fullName', label: 'Full Name', type: 'text'),
    FieldDef(key: 'issueDate', label: 'Issue Date', type: 'text', optional: true),
    FieldDef(key: 'expiryDate', label: 'Expiry Date', type: 'text', optional: true),
  ],
  'InsurancePolicy': [
    FieldDef(key: 'provider', label: 'Provider', type: 'text'),
    FieldDef(key: 'policyNumber', label: 'Policy Number', type: 'password'),
    FieldDef(key: 'policyType', label: 'Policy Type', type: 'select', options: [
      'Life', 'Health', 'Motor', 'Home', 'Travel', 'Other'
    ]),
    FieldDef(key: 'sumInsured', label: 'Sum Insured', type: 'text', optional: true),
    FieldDef(key: 'premiumDueDate', label: 'Premium Due Date', type: 'text', optional: true),
    FieldDef(key: 'nominee', label: 'Nominee', type: 'text', optional: true),
  ],
  'RecoveryCodes': [
    FieldDef(key: 'serviceName', label: 'Service Name', type: 'text'),
    FieldDef(key: 'codes', label: 'Backup / Recovery Codes', type: 'textarea', rows: 8),
  ],
  'Generic': [
    FieldDef(key: 'username', label: 'Username', type: 'text', optional: true),
    FieldDef(key: 'password', label: 'Password', type: 'password', optional: true),
  ],
};

final List<String> kCredentialTypes = kCredentialFields.keys.toList();

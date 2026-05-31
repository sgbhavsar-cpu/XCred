import { encrypt, decrypt, generateCredentialKey, encryptKeyWithPublicKey, decryptKeyWithPrivateKey } from './crypto';

export interface CredentialPayload {
  name: string;
  [key: string]: unknown;
}

export async function encryptCredentialData(
  data: CredentialPayload,
  userPublicKey: string
): Promise<{ encryptedData: string; dataIv: string; encryptedCredentialKey: string }> {
  const credentialKey = await generateCredentialKey();
  const { ciphertext: encryptedData, iv: dataIv } = await encrypt(credentialKey, JSON.stringify(data));
  const encryptedCredentialKey = await encryptKeyWithPublicKey(userPublicKey, credentialKey);
  return { encryptedData, dataIv, encryptedCredentialKey };
}

export async function decryptCredentialData(
  encryptedData: string,
  dataIv: string,
  encryptedCredentialKey: string,
  userPrivateKey: CryptoKey
): Promise<Record<string, string>> {
  const credentialKey = await decryptKeyWithPrivateKey(userPrivateKey, encryptedCredentialKey);
  const plaintext = await decrypt(credentialKey, encryptedData, dataIv);
  return JSON.parse(plaintext);
}

export interface FieldDef {
  key: string;
  label: string;
  type: 'text' | 'password' | 'textarea' | 'select' | 'url';
  placeholder?: string;
  optional?: boolean;
  options?: string[];
  rows?: number;
}

export const CREDENTIAL_FIELDS: Record<string, FieldDef[]> = {
  WebsiteLogin: [
    { key: 'url', label: 'URL', type: 'url', placeholder: 'https://example.com' },
    { key: 'username', label: 'Username / Email', type: 'text', placeholder: 'you@example.com' },
    { key: 'password', label: 'Password', type: 'password' },
    { key: 'totp', label: 'TOTP Secret', type: 'text', placeholder: 'Optional', optional: true },
  ],
  Database: [
    { key: 'host', label: 'Host', type: 'text', placeholder: 'db.example.com' },
    { key: 'port', label: 'Port', type: 'text', placeholder: '5432' },
    { key: 'database', label: 'Database Name', type: 'text' },
    { key: 'username', label: 'Username', type: 'text' },
    { key: 'password', label: 'Password', type: 'password' },
    { key: 'connectionType', label: 'Connection Type', type: 'select', options: ['PostgreSQL', 'MySQL', 'SQL Server', 'Oracle', 'MongoDB', 'Redis', 'SQLite', 'Other'] },
  ],
  ApiKey: [
    { key: 'serviceName', label: 'Service Name', type: 'text', placeholder: 'Stripe, AWS, GitHub…' },
    { key: 'keyValue', label: 'API Key / Token', type: 'password' },
    { key: 'keyId', label: 'Key ID / Client ID', type: 'text', optional: true },
    { key: 'environment', label: 'Environment', type: 'select', options: ['Production', 'Staging', 'Development', 'Testing'] },
  ],
  SshKey: [
    { key: 'host', label: 'Host / Server', type: 'text', placeholder: 'server.example.com', optional: true },
    { key: 'username', label: 'Username', type: 'text', optional: true },
    { key: 'privateKey', label: 'Private Key', type: 'textarea', placeholder: '-----BEGIN RSA PRIVATE KEY-----', rows: 6 },
    { key: 'publicKey', label: 'Public Key', type: 'textarea', placeholder: 'ssh-rsa AAAA…', optional: true, rows: 3 },
    { key: 'passphrase', label: 'Passphrase', type: 'password', optional: true },
  ],
  CreditCard: [
    { key: 'cardholderName', label: 'Cardholder Name', type: 'text' },
    { key: 'cardNumber', label: 'Card Number', type: 'text', placeholder: '•••• •••• •••• ••••' },
    { key: 'expiryMonth', label: 'Expiry Month', type: 'text', placeholder: 'MM' },
    { key: 'expiryYear', label: 'Expiry Year', type: 'text', placeholder: 'YYYY' },
    { key: 'cvv', label: 'CVV', type: 'password' },
    { key: 'billingAddress', label: 'Billing Address', type: 'textarea', optional: true, rows: 2 },
  ],
  SecureNote: [
    { key: 'body', label: 'Note Content', type: 'textarea', rows: 8 },
  ],
  WiFi: [
    { key: 'ssid', label: 'Network Name (SSID)', type: 'text' },
    { key: 'password', label: 'Password', type: 'password' },
    { key: 'securityType', label: 'Security Type', type: 'select', options: ['WPA3', 'WPA2', 'WPA', 'WEP', 'Open'] },
  ],
  SoftwareLicense: [
    { key: 'productName', label: 'Product Name', type: 'text' },
    { key: 'licenseKey', label: 'License Key', type: 'password' },
    { key: 'licenseHolder', label: 'License Holder', type: 'text', optional: true },
    { key: 'seats', label: 'Seats / Quantity', type: 'text', optional: true },
    { key: 'vendor', label: 'Vendor', type: 'text', optional: true },
  ],
  Certificate: [
    { key: 'certificate', label: 'Certificate (PEM)', type: 'textarea', placeholder: '-----BEGIN CERTIFICATE-----', rows: 6 },
    { key: 'privateKey', label: 'Private Key (PEM)', type: 'textarea', placeholder: '-----BEGIN PRIVATE KEY-----', optional: true, rows: 6 },
    { key: 'passphrase', label: 'Passphrase', type: 'password', optional: true },
    { key: 'issuer', label: 'Issuer / CA', type: 'text', optional: true },
  ],
  EnvironmentVariables: [
    { key: 'content', label: 'Environment Variables (.env format)', type: 'textarea', rows: 10, placeholder: 'DATABASE_URL=postgresql://...\nAPI_KEY=sk-...' },
  ],
  Generic: [
    { key: 'username', label: 'Username', type: 'text', optional: true },
    { key: 'password', label: 'Password', type: 'password', optional: true },
  ],
};

export const CREDENTIAL_TYPES = Object.keys(CREDENTIAL_FIELDS);

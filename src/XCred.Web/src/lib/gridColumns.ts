/** Per-type field mapping that drives the "Credentials Grid" spreadsheet view (CredentialGridView).
 *  Each credential type exposes wildly different fields (see CREDENTIAL_FIELDS in vault.ts), so the
 *  grid needs a fixed set of generic columns — Address, Password, Transaction Password/PIN — backed
 *  by whichever field actually carries that meaning for a given type. Blank cells for types that
 *  don't have a matching field are expected, same as blank cells in a real spreadsheet. */
export interface GridColumnMap {
  /** The field shown in the "Address" column — a URL, host, IP, email, or other identifying value. */
  addressKey?: string;
  /** A secondary identifying field shown under the address (e.g. username, cardholder name). */
  secondaryKey?: string;
  /** The field shown in the "Password" column. Always masked in the grid regardless of its FieldDef type. */
  primarySecretKey?: string;
  /** The field shown in the "Transaction Password / PIN" column. Always masked in the grid. */
  secondarySecretKey?: string;
}

export const CREDENTIAL_GRID_COLUMNS: Record<string, GridColumnMap> = {
  WebsiteLogin: { addressKey: 'url', secondaryKey: 'username', primarySecretKey: 'password' },
  Database: { addressKey: 'host', secondaryKey: 'username', primarySecretKey: 'password' },
  ApiKey: { addressKey: 'serviceName', secondaryKey: 'keyId', primarySecretKey: 'keyValue' },
  SshKey: { addressKey: 'host', secondaryKey: 'username', primarySecretKey: 'privateKey', secondarySecretKey: 'passphrase' },
  CreditCard: { addressKey: 'cardNumber', secondaryKey: 'cardholderName', primarySecretKey: 'cvv', secondarySecretKey: 'atmPin' },
  SecureNote: {},
  WiFi: { addressKey: 'ssid', primarySecretKey: 'password' },
  SoftwareLicense: { addressKey: 'productName', secondaryKey: 'licenseHolder', primarySecretKey: 'licenseKey' },
  Certificate: { addressKey: 'issuer', primarySecretKey: 'certificate', secondarySecretKey: 'passphrase' },
  EnvironmentVariables: {},
  BankAccount: { addressKey: 'accountNumber', secondaryKey: 'bankName', primarySecretKey: 'loginPassword', secondarySecretKey: 'transactionPassword' },
  MobileBankingPin: { addressKey: 'mobileNumber', secondaryKey: 'bankOrAppName', primarySecretKey: 'loginPin', secondarySecretKey: 'transactionPin' },
  NetworkDevice: { addressKey: 'ipAddresses', secondaryKey: 'username', primarySecretKey: 'password' },
  Rdp: { addressKey: 'host', secondaryKey: 'username', primarySecretKey: 'password' },
  WindowsServer: { addressKey: 'serverOrDomainName', secondaryKey: 'username', primarySecretKey: 'password' },
  EmailAccount: { addressKey: 'emailAddress', primarySecretKey: 'password' },
  IdentityDocument: { addressKey: 'documentType', secondaryKey: 'fullName', primarySecretKey: 'documentNumber' },
  InsurancePolicy: { addressKey: 'provider', primarySecretKey: 'policyNumber' },
  RecoveryCodes: { addressKey: 'serviceName', primarySecretKey: 'codes' },
  Generic: { secondaryKey: 'username', primarySecretKey: 'password' },
};

/** Reads a field value out of a decrypted fields map, flattening JSON list-type values (e.g. NetworkDevice's
 *  ipAddresses) into a comma-separated string so it fits in a single grid cell. */
export function readGridField(fields: Record<string, string> | undefined, key?: string): string {
  if (!fields || !key) return '';
  const raw = fields[key];
  if (!raw) return '';
  if (raw.startsWith('[')) {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return parsed.filter(Boolean).join(', ');
    } catch {
      // not JSON — fall through and return the raw string
    }
  }
  return raw;
}

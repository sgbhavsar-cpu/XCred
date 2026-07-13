# XCred — Credential Type Field Reference

This is the authoritative, field-by-field list for every credential type. It mirrors
`src/XCred.Web/src/lib/vault.ts` (`CREDENTIAL_FIELDS`) exactly — if the two ever disagree,
the code wins and this file should be updated to match.

All type-specific fields below are stored inside the single AES-256-GCM encrypted JSON blob
per credential (`Credential.EncryptedData`); the server never sees field names or values in
plaintext. Every type also implicitly has: **Name**, **Notes**, **Custom Fields**, **Tags**,
**Folder**, **Credential Group**, **Expiry Date**, and **File Attachments** (see requirements
§4.2–4.4, §5.4).

Field type legend: `text`, `password` (masked + copy + strength meter), `textarea` (multi-line),
`url` (validated, with an "open in new tab" action), `select` (fixed options), `list`
(repeatable text rows, stored as a JSON string array — e.g. multiple IP addresses).

---

## Website Login
| Field | Type | Notes |
|---|---|---|
| URL | url | |
| Username / Email | text | |
| Password | password | |
| TOTP Secret | text | optional |
| Recovery Email | text | optional |
| Recovery Phone | text | optional |

## Database
| Field | Type | Notes |
|---|---|---|
| Host | text | |
| Port | text | |
| Database Name | text | |
| Username | text | |
| Password | password | |
| Connection Type | select | PostgreSQL, MySQL, SQL Server, Oracle, MongoDB, Redis, SQLite, Other |

## API Key / Token
| Field | Type | Notes |
|---|---|---|
| Service Name | text | |
| API Key / Token | password | |
| Key ID / Client ID | text | optional |
| Environment | select | Production, Staging, Development, Testing |

## SSH Key Pair
| Field | Type | Notes |
|---|---|---|
| Host / Server | text | optional |
| Username | text | optional |
| Private Key | textarea | |
| Public Key | textarea | optional |
| Passphrase | password | optional |

## Payment Card (Credit / Debit)
| Field | Type | Notes |
|---|---|---|
| Cardholder Name | text | |
| Card Number | text | |
| Card Network | select | Visa, Mastercard, RuPay, Amex, Other — optional |
| Expiry Month | text | MM |
| Expiry Year | text | YYYY |
| CVV | password | |
| ATM PIN | password | optional |
| Billing Address | textarea | optional |

## Secure Note
| Field | Type | Notes |
|---|---|---|
| Note Content | textarea | |

## Wi-Fi
| Field | Type | Notes |
|---|---|---|
| Network Name (SSID) | text | |
| Password | password | |
| Security Type | select | WPA3, WPA2, WPA, WEP, Open |

## Software License
| Field | Type | Notes |
|---|---|---|
| Product Name | text | |
| License Key | password | |
| License Holder | text | optional |
| Seats / Quantity | text | optional |
| Vendor | text | optional |

## Certificate
| Field | Type | Notes |
|---|---|---|
| Certificate (PEM) | textarea | |
| Private Key (PEM) | textarea | optional |
| Passphrase | password | optional |
| Issuer / CA | text | optional |

## Environment Variables
| Field | Type | Notes |
|---|---|---|
| Environment Variables (.env format) | textarea | multi-line `KEY=value` |

## Bank Account *(new)*
| Field | Type | Notes |
|---|---|---|
| Bank Name | text | |
| Account Holder Name | text | |
| Account Number | password | |
| IFSC / SWIFT Code | text | |
| Branch | text | optional |
| Account Type | select | Savings, Current, Salary, Fixed Deposit, Loan, Other |
| Customer ID (CIF) | text | optional |

Use a **Credential Group** (§5.4 of requirements.md) to tie a Bank Account credential together
with its related Payment Card, netbanking Website Login, and Mobile Banking PIN credentials.

## Mobile Banking / App PIN *(new)*
| Field | Type | Notes |
|---|---|---|
| Bank / App Name | text | |
| Mobile Number | text | |
| Customer ID | text | optional |
| Login PIN | password | |
| Transaction PIN (MPIN) | password | |

## Network Device *(new)*
| Field | Type | Notes |
|---|---|---|
| Device Name | text | |
| IP Address(es) | list | one or more IPs/hostnames |
| Protocol | select | Web (HTTP/HTTPS), Telnet, SSH, Other |
| Port | text | optional |
| Username | text | |
| Password | password | |

## Email Account *(new)*
| Field | Type | Notes |
|---|---|---|
| Email Address | text | |
| Password | password | |
| Recovery Email | text | optional |
| Recovery Phone | text | optional |
| IMAP / SMTP Host | text | optional |

## Identity Document *(new)*
| Field | Type | Notes |
|---|---|---|
| Document Type | select | Passport, Aadhaar, PAN, Driving License, Other |
| Document Number | password | |
| Full Name | text | |
| Issue Date | text | optional |
| Expiry Date | text | optional — also settable as the credential's top-level Expiry Date for alerts |

## Insurance Policy *(new)*
| Field | Type | Notes |
|---|---|---|
| Provider | text | |
| Policy Number | password | |
| Policy Type | select | Life, Health, Motor, Home, Travel, Other |
| Sum Insured | text | optional |
| Premium Due Date | text | optional |
| Nominee | text | optional |

## Recovery Codes *(new)*
| Field | Type | Notes |
|---|---|---|
| Service Name | text | |
| Backup / Recovery Codes | textarea | multi-line, one code per line |

## Generic
| Field | Type | Notes |
|---|---|---|
| Username | text | optional |
| Password | password | optional |

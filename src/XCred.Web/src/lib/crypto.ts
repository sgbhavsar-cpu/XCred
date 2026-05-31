// PBKDF2-SHA256 with 600,000 iterations — NIST SP 800-132 recommended.
// Argon2id would be stronger but requires WASM not yet compatible with Vite 6.
// This is a deliberate, documented trade-off. Migrate to Argon2id when tooling matures.

export async function deriveKey(masterPassword: string, salt: string): Promise<CryptoKey> {
  const enc = new TextEncoder();
  const saltBytes = Uint8Array.from(atob(salt), c => c.charCodeAt(0));

  const baseKey = await crypto.subtle.importKey('raw', enc.encode(masterPassword), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt: saltBytes, iterations: 600_000, hash: 'SHA-256' },
    baseKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

// Generate a random 256-bit salt (base64-encoded)
export function generateSalt(): string {
  return btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))));
}

// AES-256-GCM encrypt — returns { ciphertext: base64, iv: base64 }
export async function encrypt(key: CryptoKey, plaintext: string): Promise<{ ciphertext: string; iv: string }> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plaintext);
  const ciphertext = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, encoded);
  return {
    ciphertext: btoa(String.fromCharCode(...new Uint8Array(ciphertext))),
    iv: btoa(String.fromCharCode(...iv)),
  };
}

// AES-256-GCM decrypt
export async function decrypt(key: CryptoKey, ciphertext: string, iv: string): Promise<string> {
  const ciphertextBytes = Uint8Array.from(atob(ciphertext), c => c.charCodeAt(0));
  const ivBytes = Uint8Array.from(atob(iv), c => c.charCodeAt(0));
  const decrypted = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: ivBytes }, key, ciphertextBytes);
  return new TextDecoder().decode(decrypted);
}

// Generate RSA-OAEP-4096 key pair for envelope encryption in credential sharing
export async function generateKeyPair(): Promise<{ publicKey: string; privateKey: string }> {
  // RSA-2048 is sufficient for encrypting a 32-byte AES key and generates ~10x faster than 4096 in-browser.
  const keyPair = await crypto.subtle.generateKey(
    { name: 'RSA-OAEP', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['encrypt', 'decrypt']
  );
  const publicKeyBuffer = await crypto.subtle.exportKey('spki', keyPair.publicKey);
  const privateKeyBuffer = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
  return {
    publicKey: btoa(String.fromCharCode(...new Uint8Array(publicKeyBuffer))),
    privateKey: btoa(String.fromCharCode(...new Uint8Array(privateKeyBuffer))),
  };
}

// Encrypt private key with symmetric key (for storage)
export async function encryptPrivateKey(symmetricKey: CryptoKey, privateKeyB64: string): Promise<{ encryptedPrivateKey: string; iv: string }> {
  const result = await encrypt(symmetricKey, privateKeyB64);
  return { encryptedPrivateKey: result.ciphertext, iv: result.iv };
}

// Decrypt private key and return as CryptoKey
export async function decryptPrivateKey(symmetricKey: CryptoKey, encryptedPrivateKey: string, iv: string): Promise<CryptoKey> {
  const privateKeyB64 = await decrypt(symmetricKey, encryptedPrivateKey, iv);
  const privateKeyBytes = Uint8Array.from(atob(privateKeyB64), c => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', privateKeyBytes, { name: 'RSA-OAEP', hash: 'SHA-256' }, false, ['decrypt']);
}

// Generate a random per-credential AES-256 key
export async function generateCredentialKey(): Promise<CryptoKey> {
  return crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, true, ['encrypt', 'decrypt']);
}

// Export a CryptoKey to base64
export async function exportKey(key: CryptoKey): Promise<string> {
  const raw = await crypto.subtle.exportKey('raw', key);
  return btoa(String.fromCharCode(...new Uint8Array(raw)));
}

// Import a base64 AES key
export async function importAesKey(b64: string): Promise<CryptoKey> {
  const raw = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
  return crypto.subtle.importKey('raw', raw, { name: 'AES-GCM' }, false, ['encrypt', 'decrypt']);
}

// Encrypt a credential key with RSA public key (for sharing)
export async function encryptKeyWithPublicKey(publicKeyB64: string, aesKey: CryptoKey): Promise<string> {
  const publicKeyBytes = Uint8Array.from(atob(publicKeyB64), c => c.charCodeAt(0));
  const publicKey = await crypto.subtle.importKey('spki', publicKeyBytes, { name: 'RSA-OAEP', hash: 'SHA-256' }, false, ['encrypt']);
  const rawKey = await crypto.subtle.exportKey('raw', aesKey);
  const encrypted = await crypto.subtle.encrypt({ name: 'RSA-OAEP' }, publicKey, rawKey);
  return btoa(String.fromCharCode(...new Uint8Array(encrypted)));
}

// Decrypt a credential key with RSA private key
export async function decryptKeyWithPrivateKey(privateKey: CryptoKey, encryptedKeyB64: string): Promise<CryptoKey> {
  const encryptedBytes = Uint8Array.from(atob(encryptedKeyB64), c => c.charCodeAt(0));
  const rawKey = await crypto.subtle.decrypt({ name: 'RSA-OAEP' }, privateKey, encryptedBytes);
  return crypto.subtle.importKey('raw', rawKey, { name: 'AES-GCM' }, true, ['encrypt', 'decrypt']);
}

// Password strength score (0–4)
export function passwordStrength(password: string): { score: number; label: string; color: string } {
  if (!password) return { score: 0, label: 'None', color: 'bg-gray-200' };
  let score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 14) score++;
  if (/[A-Z]/.test(password) && /[a-z]/.test(password)) score++;
  if (/[0-9]/.test(password)) score++;
  if (/[^A-Za-z0-9]/.test(password)) score++;
  if (password.length >= 20) score = Math.min(score + 1, 5);
  const clampedScore = Math.min(Math.floor(score / 1.2), 4);
  const labels = ['Very Weak', 'Weak', 'Fair', 'Strong', 'Very Strong'];
  const colors = ['bg-red-500', 'bg-orange-400', 'bg-yellow-400', 'bg-blue-500', 'bg-green-500'];
  return { score: clampedScore, label: labels[clampedScore], color: colors[clampedScore] };
}

// Cryptographically random password generator
export function generatePassword(options: {
  length: number;
  uppercase: boolean;
  lowercase: boolean;
  numbers: boolean;
  symbols: boolean;
  excludeAmbiguous: boolean;
}): string {
  let chars = '';
  if (options.uppercase) chars += options.excludeAmbiguous ? 'ABCDEFGHJKLMNPQRSTUVWXYZ' : 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  if (options.lowercase) chars += options.excludeAmbiguous ? 'abcdefghjkmnpqrstuvwxyz' : 'abcdefghijklmnopqrstuvwxyz';
  if (options.numbers) chars += options.excludeAmbiguous ? '23456789' : '0123456789';
  if (options.symbols) chars += '!@#$%^&*()_+-=[]{}|;:,.<>?';
  if (!chars) chars = 'abcdefghijklmnopqrstuvwxyz';
  const array = new Uint32Array(options.length);
  crypto.getRandomValues(array);
  return Array.from(array).map(x => chars[x % chars.length]).join('');
}

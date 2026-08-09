// Phase 1 of the RSA-OAEP-2048 interop spike (MOB-SETUP-02).
// Uses Node's WebCrypto (crypto.subtle) with the EXACT same algorithm calls as
// src/XCred.Web/src/lib/crypto.ts, so the vectors this produces are indistinguishable
// from what the real web app would produce. Dart (spike/dart_interop_spike.dart) consumes
// this file and must reproduce every value below via CryptoService.
import { webcrypto as crypto } from 'node:crypto';
import { writeFileSync } from 'node:fs';

const b64 = (buf) => Buffer.from(buf).toString('base64');
const b64ToBytes = (s) => Uint8Array.from(Buffer.from(s, 'base64'));

// --- PBKDF2 + AES-GCM vector (mirrors deriveKey/encrypt in crypto.ts) ---
const masterPassword = 'Admin@#1234%^&*()';
const saltBytes = crypto.getRandomValues(new Uint8Array(32));
const salt = b64(saltBytes);

const baseKey = await crypto.subtle.importKey(
  'raw', new TextEncoder().encode(masterPassword), 'PBKDF2', false, ['deriveKey']
);
const aesKey = await crypto.subtle.deriveKey(
  { name: 'PBKDF2', salt: saltBytes, iterations: 600_000, hash: 'SHA-256' },
  baseKey,
  { name: 'AES-GCM', length: 256 },
  false,
  ['encrypt', 'decrypt']
);

const plaintext = 'XCred mobile interop spike — if you can read this, PBKDF2+AES-GCM match.';
const iv = crypto.getRandomValues(new Uint8Array(12));
const ciphertextBuf = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, aesKey, new TextEncoder().encode(plaintext));

// --- RSA-OAEP-2048/SHA-256 vector (mirrors generateKeyPair/encryptKeyWithPublicKey) ---
const rsaKeyPair = await crypto.subtle.generateKey(
  { name: 'RSA-OAEP', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
  true,
  ['encrypt', 'decrypt']
);
const spki = b64(await crypto.subtle.exportKey('spki', rsaKeyPair.publicKey));
const pkcs8 = b64(await crypto.subtle.exportKey('pkcs8', rsaKeyPair.privateKey));

// A known 32-byte "credential AES key" — the exact kind of payload encryptKeyWithPublicKey wraps.
const knownAesKeyBytes = crypto.getRandomValues(new Uint8Array(32));
const wrappedKeyBuf = await crypto.subtle.encrypt({ name: 'RSA-OAEP' }, rsaKeyPair.publicKey, knownAesKeyBytes);

const vectors = {
  pbkdf2AesGcm: {
    masterPassword,
    salt,
    iterations: 600_000,
    plaintext,
    iv: b64(iv),
    ciphertext: b64(ciphertextBuf),
  },
  rsaOaep: {
    spkiPublicKey: spki,
    pkcs8PrivateKey: pkcs8,
    knownAesKeyB64: b64(knownAesKeyBytes),
    wrappedKeyB64: b64(wrappedKeyBuf),
  },
};

writeFileSync(new URL('./interop_vectors.json', import.meta.url), JSON.stringify(vectors, null, 2));
console.log('Wrote interop_vectors.json');
console.log('  salt bytes:', saltBytes.length, ' iv bytes:', iv.length);
console.log('  spki b64 len:', spki.length, ' pkcs8 b64 len:', pkcs8.length);

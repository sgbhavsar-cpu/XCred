// Phase 2 of the RSA-OAEP-2048 interop spike (MOB-SETUP-02).
// Reads dart_output.json (produced by test/crypto_interop_spike_test.dart's CryptoService)
// and proves real WebCrypto — the exact API the web app's crypto.ts uses — can import
// Dart's SPKI public key / PKCS8 private key and decrypt what Dart encrypted. This is the
// direction that matters most for sharing: a mobile-generated key pair must be usable by
// the web app.
import { webcrypto as crypto } from 'node:crypto';
import { readFileSync } from 'node:fs';

const b64ToBytes = (s) => Uint8Array.from(Buffer.from(s, 'base64'));
const bytesToB64 = (buf) => Buffer.from(buf).toString('base64');

const output = JSON.parse(readFileSync(new URL('./dart_output.json', import.meta.url), 'utf8'));

const publicKey = await crypto.subtle.importKey(
  'spki', b64ToBytes(output.spkiPublicKey), { name: 'RSA-OAEP', hash: 'SHA-256' }, false, ['encrypt']
);
const privateKey = await crypto.subtle.importKey(
  'pkcs8', b64ToBytes(output.pkcs8PrivateKey), { name: 'RSA-OAEP', hash: 'SHA-256' }, false, ['decrypt']
);

// 1. Decrypt what Dart encrypted, using the private key Dart exported.
const decryptedBuf = await crypto.subtle.decrypt({ name: 'RSA-OAEP' }, privateKey, b64ToBytes(output.wrappedValueB64));
const decrypted = bytesToB64(decryptedBuf);
if (decrypted !== output.knownValueB64) {
  console.error('FAIL: WebCrypto could not recover the value Dart encrypted.');
  console.error('  expected:', output.knownValueB64);
  console.error('  got:     ', decrypted);
  process.exit(1);
}
console.log('PASS: WebCrypto decrypted Dart-encrypted ciphertext correctly (PKCS8 export OK).');

// 2. Encrypt something fresh with Dart's SPKI-imported public key, confirm it round-trips
//    through the same private key (proves the SPKI export is a genuinely valid public key,
//    not just coincidentally decryptable).
const freshValue = crypto.getRandomValues(new Uint8Array(32));
const freshCipher = await crypto.subtle.encrypt({ name: 'RSA-OAEP' }, publicKey, freshValue);
const freshDecrypted = new Uint8Array(await crypto.subtle.decrypt({ name: 'RSA-OAEP' }, privateKey, freshCipher));
if (bytesToB64(freshDecrypted) !== bytesToB64(freshValue)) {
  console.error('FAIL: round-trip through Dart-exported SPKI public key + PKCS8 private key failed.');
  process.exit(1);
}
console.log('PASS: WebCrypto encrypt-with-Dart-SPKI-key -> decrypt-with-Dart-PKCS8-key round-trips correctly.');
console.log('\nRSA-OAEP-2048/SHA-256 interop spike: CONFIRMED bidirectional (Dart <-> WebCrypto).');

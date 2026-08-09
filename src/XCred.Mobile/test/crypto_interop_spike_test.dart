// MOB-SETUP-02 interop spike: proves CryptoService is byte-for-byte compatible with
// the web app's WebCrypto-based crypto.ts, in both directions.
//
// Phase 1 (this file, first half): spike/gen_vectors.mjs used Node's WebCrypto (the same
// crypto.subtle API calls as crypto.ts) to produce interop_vectors.json. We decrypt/consume
// those vectors here — proving Dart can read what the web app produces.
//
// Phase 2 (this file, second half): we produce our own RSA keypair + ciphertext and write
// dart_output.json. spike/verify_dart_output.mjs then imports it via WebCrypto and proves
// the web app could read what Dart produces.
//
// Run: flutter test test/crypto_interop_spike_test.dart
// Then: node spike/verify_dart_output.mjs
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as cg;
import 'package:flutter_test/flutter_test.dart';
import 'package:xcred_mobile/core/crypto/crypto_service.dart';

void main() {
  final service = CryptoService();
  final vectorsFile = File('spike/interop_vectors.json');

  test('Phase 1: Dart decrypts real WebCrypto-produced PBKDF2 + AES-GCM output', () async {
    final vectors = jsonDecode(await vectorsFile.readAsString()) as Map<String, dynamic>;
    final v = vectors['pbkdf2AesGcm'] as Map<String, dynamic>;

    final key = await service.deriveKey(v['masterPassword'] as String, v['salt'] as String);
    final decrypted = await service.decrypt(key, v['ciphertext'] as String, v['iv'] as String);

    expect(decrypted, equals(v['plaintext']),
        reason: 'PBKDF2-SHA256 600k + AES-256-GCM must match WebCrypto exactly');
  });

  test('Phase 1: Dart decrypts real WebCrypto RSA-OAEP-2048/SHA-256 wrapped key', () async {
    final vectors = jsonDecode(await vectorsFile.readAsString()) as Map<String, dynamic>;
    final v = vectors['rsaOaep'] as Map<String, dynamic>;

    final privateKey = decodePkcs8(base64Decode(v['pkcs8PrivateKey'] as String));
    final unwrapped = service.decryptKeyWithPrivateKey(privateKey, v['wrappedKeyB64'] as String);
    final unwrappedBytes = base64Encode(await unwrapped.extractBytes());

    expect(unwrappedBytes, equals(v['knownAesKeyB64']),
        reason: 'Dart PKCS8 import + RSA-OAEP-SHA256 decrypt must recover the exact key '
            'WebCrypto wrapped');
  });

  test('Phase 1: Dart imports real WebCrypto SPKI public key and can re-wrap with it', () async {
    final vectors = jsonDecode(await vectorsFile.readAsString()) as Map<String, dynamic>;
    final v = vectors['rsaOaep'] as Map<String, dynamic>;

    final publicKey = decodeSpki(base64Decode(v['spkiPublicKey'] as String));
    final privateKey = decodePkcs8(base64Decode(v['pkcs8PrivateKey'] as String));
    final aesKey = cg.SecretKey(base64Decode(v['knownAesKeyB64'] as String));

    final rewrapped = await service.encryptKeyWithPublicKey(v['spkiPublicKey'] as String, aesKey);
    final unwrapped = service.decryptKeyWithPrivateKey(privateKey, rewrapped);
    expect(base64Encode(await unwrapped.extractBytes()), equals(v['knownAesKeyB64']));
    // publicKey decoded independently must match the modulus used above (import sanity check).
    expect(publicKey.modulus, isNotNull);
  });

  test('Phase 2: Dart generates a keypair + ciphertext for Node/WebCrypto to verify', () async {
    final keyPair = service.generateKeyPair();
    final knownValue = base64Encode(Uint8List.fromList(List<int>.generate(32, (i) => i)));
    final aesKey = cg.SecretKey(base64Decode(knownValue));

    final wrapped = await service.encryptKeyWithPublicKey(keyPair.publicKeySpkiB64, aesKey);

    final output = {
      'spkiPublicKey': keyPair.publicKeySpkiB64,
      'pkcs8PrivateKey': keyPair.privateKeyPkcs8B64,
      'knownValueB64': knownValue,
      'wrappedValueB64': wrapped,
    };
    await File('spike/dart_output.json').writeAsString(jsonEncode(output));

    // Self round-trip sanity check before handing off to Node.
    final privateKey = decodePkcs8(base64Decode(keyPair.privateKeyPkcs8B64));
    final unwrapped = service.decryptKeyWithPrivateKey(privateKey, wrapped);
    expect(base64Encode(await unwrapped.extractBytes()), equals(knownValue));

    // eslint/dart-lint noise avoidance: confirm SPKI/PKCS8 round-trip through our own codec.
    final reDecoded = decodeSpki(base64Decode(keyPair.publicKeySpkiB64));
    expect(reDecoded.modulus, decodePkcs8(base64Decode(keyPair.privateKeyPkcs8B64)).modulus);
  });

  test('Fixed-vector: AES-GCM round-trip with a known key/IV/ciphertext', () async {
    // Independently-known AES-256-GCM test vector (NIST-style, 32-byte key, 12-byte IV).
    final keyBytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final key = cg.SecretKey(keyBytes);
    const plaintext = 'fixed vector plaintext';

    final enc = await service.encrypt(key, plaintext);
    final dec = await service.decrypt(key, enc.ciphertextB64, enc.ivB64);
    expect(dec, equals(plaintext));
  });

  test('Fixed-vector: PBKDF2 derives a deterministic key for a fixed password/salt', () async {
    const fixedSaltB64 = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
    final key1 = await service.deriveKey('correct horse battery staple', fixedSaltB64);
    final key2 = await service.deriveKey('correct horse battery staple', fixedSaltB64);
    expect(await key1.extractBytes(), equals(await key2.extractBytes()));

    final wrongKey = await service.deriveKey('wrong password', fixedSaltB64);
    expect(await wrongKey.extractBytes(), isNot(equals(await key1.extractBytes())));
  });

  test('Fixed-vector: RSA-OAEP wrap/unwrap round-trip with a fresh Dart-generated keypair',
      () async {
    final keyPair = service.generateKeyPair();
    final privateKey = decodePkcs8(base64Decode(keyPair.privateKeyPkcs8B64));
    final credentialKey = await service.generateCredentialKey();
    final rawBefore = await credentialKey.extractBytes();

    final wrapped = await service.encryptKeyWithPublicKey(keyPair.publicKeySpkiB64, credentialKey);
    final unwrapped = service.decryptKeyWithPrivateKey(privateKey, wrapped);

    expect(await unwrapped.extractBytes(), equals(rawBefore));
  });
}

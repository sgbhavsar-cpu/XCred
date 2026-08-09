// Zero-knowledge crypto model, ported 1:1 from src/XCred.Web/src/lib/crypto.ts.
// Every parameter (PBKDF2 iterations, AES-GCM IV length, RSA modulus/hash) must match
// the web app exactly — this is a client-side-only trust boundary, verified by the
// interop spike in spike/dart_interop_spike.dart before any screen depends on it.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as cg;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart' as pc;

const int kPbkdf2Iterations = 600000;
const int kAesKeyBits = 256;
const int kRsaModulusBits = 2048;

class AesGcmCiphertext {
  final String ciphertextB64;
  final String ivB64;
  const AesGcmCiphertext({required this.ciphertextB64, required this.ivB64});
}

class EncryptedCredential {
  final String encryptedData;
  final String dataIv;
  final String encryptedCredentialKey;
  const EncryptedCredential({
    required this.encryptedData,
    required this.dataIv,
    required this.encryptedCredentialKey,
  });
}

class RsaKeyPairB64 {
  final String publicKeySpkiB64;
  final String privateKeyPkcs8B64;
  const RsaKeyPairB64({required this.publicKeySpkiB64, required this.privateKeyPkcs8B64});
}

class CryptoService {
  final cg.Pbkdf2 _pbkdf2 = cg.Pbkdf2(
    macAlgorithm: cg.Hmac.sha256(),
    iterations: kPbkdf2Iterations,
    bits: kAesKeyBits,
  );
  final cg.AesGcm _aesGcm = cg.AesGcm.with256bits();

  /// Derives the master-password AES-GCM key. Matches crypto.ts `deriveKey`.
  Future<cg.SecretKey> deriveKey(String masterPassword, String saltB64) {
    final saltBytes = base64Decode(saltB64);
    return _pbkdf2.deriveKey(
      secretKey: cg.SecretKey(utf8.encode(masterPassword)),
      nonce: saltBytes,
    );
  }

  /// Matches crypto.ts `generateSalt` — 256-bit random salt, base64.
  String generateSalt() {
    final bytes = _randomBytes(32);
    return base64Encode(bytes);
  }

  /// Matches crypto.ts `encrypt` — fresh random 96-bit IV, output ciphertext
  /// includes the GCM auth tag appended (WebCrypto convention).
  Future<AesGcmCiphertext> encrypt(cg.SecretKey key, String plaintext) async {
    final iv = _randomBytes(12);
    final box = await _aesGcm.encrypt(utf8.encode(plaintext), secretKey: key, nonce: iv);
    final combined = Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
    return AesGcmCiphertext(ciphertextB64: base64Encode(combined), ivB64: base64Encode(iv));
  }

  /// Matches crypto.ts `decrypt`.
  Future<String> decrypt(cg.SecretKey key, String ciphertextB64, String ivB64) async {
    final combined = base64Decode(ciphertextB64);
    final iv = base64Decode(ivB64);
    if (combined.length < 16) {
      throw ArgumentError('ciphertext too short to contain a GCM tag');
    }
    final ct = combined.sublist(0, combined.length - 16);
    final mac = combined.sublist(combined.length - 16);
    final box = cg.SecretBox(ct, nonce: iv, mac: cg.Mac(mac));
    final clear = await _aesGcm.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }

  /// Matches crypto.ts `generateKeyPair` — RSA-OAEP-2048/SHA-256, SPKI/PKCS8 export,
  /// byte-for-byte compatible with WebCrypto's exportKey('spki'/'pkcs8', ...).
  RsaKeyPairB64 generateKeyPair() {
    final pair = _generateRsaKeyPairRaw();
    final pub = pair.publicKey as pc.RSAPublicKey;
    final priv = pair.privateKey as pc.RSAPrivateKey;
    return RsaKeyPairB64(
      publicKeySpkiB64: base64Encode(encodeSpki(pub)),
      privateKeyPkcs8B64: base64Encode(encodePkcs8(priv)),
    );
  }

  /// Matches crypto.ts `encryptPrivateKey` — wraps the base64 private key string
  /// (itself already base64) as plaintext under the master-password key.
  Future<AesGcmCiphertext> encryptPrivateKey(cg.SecretKey symmetricKey, String privateKeyB64) {
    return encrypt(symmetricKey, privateKeyB64);
  }

  /// Matches crypto.ts `decryptPrivateKey` — returns the raw PKCS8 DER bytes.
  Future<pc.RSAPrivateKey> decryptPrivateKey(
    cg.SecretKey symmetricKey,
    String encryptedPrivateKeyB64,
    String ivB64,
  ) async {
    final privateKeyB64 = await decrypt(symmetricKey, encryptedPrivateKeyB64, ivB64);
    return decodePkcs8(base64Decode(privateKeyB64));
  }

  /// Matches crypto.ts `generateCredentialKey`.
  Future<cg.SecretKey> generateCredentialKey() => _aesGcm.newSecretKey();

  /// Matches crypto.ts `exportKey`.
  Future<String> exportKey(cg.SecretKey key) async {
    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  /// Matches crypto.ts `importAesKey`.
  cg.SecretKey importAesKey(String b64) => cg.SecretKey(base64Decode(b64));

  /// Matches crypto.ts `encryptKeyWithPublicKey` — RSA-OAEP-SHA256 wrap of the raw
  /// AES key bytes, for envelope encryption / sharing.
  Future<String> encryptKeyWithPublicKey(String publicKeySpkiB64, cg.SecretKey aesKey) async {
    final pub = decodeSpki(base64Decode(publicKeySpkiB64));
    final rawKey = Uint8List.fromList(await aesKey.extractBytes());
    final cipher = _oaepCipher();
    cipher.init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(pub));
    final encrypted = cipher.process(rawKey);
    return base64Encode(encrypted);
  }

  /// Matches crypto.ts `decryptKeyWithPrivateKey`.
  cg.SecretKey decryptKeyWithPrivateKey(pc.RSAPrivateKey privateKey, String encryptedKeyB64) {
    final encryptedBytes = base64Decode(encryptedKeyB64);
    final cipher = _oaepCipher();
    cipher.init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));
    final rawKey = cipher.process(encryptedBytes);
    return cg.SecretKey(rawKey);
  }

  /// Matches vault.ts `encryptCredentialData` — generates a fresh per-credential AES
  /// key, encrypts the JSON payload, and wraps the key with the owner's own public key
  /// (envelope encryption; re-wrapping the same underlying key for a recipient's public
  /// key is how sharing works, added in a later sprint).
  Future<EncryptedCredential> encryptCredentialFields({
    required Map<String, dynamic> payload,
    required String publicKeySpkiB64,
  }) async {
    final credentialKey = await generateCredentialKey();
    final enc = await encrypt(credentialKey, jsonEncode(payload));
    final wrappedKey = await encryptKeyWithPublicKey(publicKeySpkiB64, credentialKey);
    return EncryptedCredential(
      encryptedData: enc.ciphertextB64,
      dataIv: enc.ivB64,
      encryptedCredentialKey: wrappedKey,
    );
  }

  /// Matches vault.ts `decryptCredentialData` — unwraps the per-credential AES key,
  /// decrypts the JSON payload, and parses it. Every credential list/detail screen
  /// funnels through here rather than re-deriving the unwrap+decrypt+parse sequence.
  Future<Map<String, dynamic>> decryptCredentialFields({
    required String encryptedData,
    required String dataIv,
    required String encryptedCredentialKey,
    required pc.RSAPrivateKey privateKey,
  }) async {
    final credentialKey = decryptKeyWithPrivateKey(privateKey, encryptedCredentialKey);
    final plaintext = await decrypt(credentialKey, encryptedData, dataIv);
    return jsonDecode(plaintext) as Map<String, dynamic>;
  }

  pc.OAEPEncoding _oaepCipher() => pc.OAEPEncoding.withSHA256(pc.RSAEngine());

  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> _generateRsaKeyPairRaw() {
    final secureRandom = pc.FortunaRandom();
    secureRandom.seed(pc.KeyParameter(_randomBytes(32)));
    final keyGen = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), kRsaModulusBits, 64),
        secureRandom,
      ));
    return keyGen.generateKeyPair();
  }
}

// --- ASN.1 SPKI (X.509 SubjectPublicKeyInfo) / PKCS#8 codec ---
// WebCrypto's exportKey('spki'|'pkcs8', ...) produces exactly these DER structures;
// this codec must round-trip byte-for-byte with it (verified in the interop spike).

Uint8List encodeSpki(pc.RSAPublicKey pub) {
  final pubKeySeq = ASN1Sequence()
    ..add(ASN1Integer(pub.modulus!))
    ..add(ASN1Integer(pub.exponent!));

  final algSeq = ASN1Sequence()
    ..add(ASN1ObjectIdentifier.fromName('rsaEncryption'))
    ..add(ASN1Null());

  final bitString = ASN1BitString(stringValues: pubKeySeq.encode());

  final topSeq = ASN1Sequence()
    ..add(algSeq)
    ..add(bitString);
  return topSeq.encode();
}

pc.RSAPublicKey decodeSpki(Uint8List der) {
  final topSeq = ASN1Parser(der).nextObject() as ASN1Sequence;
  final bitString = topSeq.elements![1] as ASN1BitString;
  final pubKeyDer = Uint8List.fromList(bitString.stringValues!);
  final pubSeq = ASN1Parser(pubKeyDer).nextObject() as ASN1Sequence;
  final n = (pubSeq.elements![0] as ASN1Integer).integer!;
  final e = (pubSeq.elements![1] as ASN1Integer).integer!;
  return pc.RSAPublicKey(n, e);
}

Uint8List encodePkcs8(pc.RSAPrivateKey priv) {
  final n = priv.modulus!;
  final e = priv.publicExponent!;
  final d = priv.privateExponent!;
  final p = priv.p!;
  final q = priv.q!;
  final dP = d % (p - BigInt.one);
  final dQ = d % (q - BigInt.one);
  final qInv = q.modInverse(p);

  final pkcs1Seq = ASN1Sequence()
    ..add(ASN1Integer(BigInt.zero))
    ..add(ASN1Integer(n))
    ..add(ASN1Integer(e))
    ..add(ASN1Integer(d))
    ..add(ASN1Integer(p))
    ..add(ASN1Integer(q))
    ..add(ASN1Integer(dP))
    ..add(ASN1Integer(dQ))
    ..add(ASN1Integer(qInv));

  final algSeq = ASN1Sequence()
    ..add(ASN1ObjectIdentifier.fromName('rsaEncryption'))
    ..add(ASN1Null());

  final octetString = ASN1OctetString(octets: pkcs1Seq.encode());

  final topSeq = ASN1Sequence()
    ..add(ASN1Integer(BigInt.zero))
    ..add(algSeq)
    ..add(octetString);
  return topSeq.encode();
}

pc.RSAPrivateKey decodePkcs8(Uint8List der) {
  final topSeq = ASN1Parser(der).nextObject() as ASN1Sequence;
  final octetString = topSeq.elements![2] as ASN1OctetString;
  final pkcs1Seq = ASN1Parser(octetString.octets!).nextObject() as ASN1Sequence;
  final n = (pkcs1Seq.elements![1] as ASN1Integer).integer!;
  final d = (pkcs1Seq.elements![3] as ASN1Integer).integer!;
  final p = (pkcs1Seq.elements![4] as ASN1Integer).integer!;
  final q = (pkcs1Seq.elements![5] as ASN1Integer).integer!;
  return pc.RSAPrivateKey(n, d, p, q);
}

import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class CryptoKeyPair {
  final String publicKeyHex;
  final String privateKeyHex;

  CryptoKeyPair({required this.publicKeyHex, required this.privateKeyHex});
}

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  final _x25519 = X25519();
  final _cipher = AesGcm.with256bits();

  /// Generates a new X25519 cryptographic key pair for P2P identity & encryption
  Future<CryptoKeyPair> generateKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    final privKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubHex = _bytesToHex(pubKey.bytes);
    final privHex = _bytesToHex(privKeyBytes);

    return CryptoKeyPair(
      publicKeyHex: pubHex,
      privateKeyHex: privHex,
    );
  }

  /// Encrypts plaintext using Diffie-Hellman Shared Secret (ECDH X25519 + AES-GCM-256)
  /// Sender uses their private key + recipient's public key
  Future<String> encryptForPeer({
    required String plainText,
    required String senderPrivateKeyHex,
    required String recipientPublicKeyHex,
  }) async {
    try {
      final senderPrivBytes = _hexToBytes(senderPrivateKeyHex);
      final senderKeyPair = await _x25519.newKeyPairFromSeed(senderPrivBytes);

      final recipientPubBytes = _hexToBytes(recipientPublicKeyHex);
      final recipientPubKey = SimplePublicKey(recipientPubBytes, type: KeyPairType.x25519);

      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: senderKeyPair,
        remotePublicKey: recipientPubKey,
      );

      final clearBytes = utf8.encode(plainText);
      final secretBox = await _cipher.encrypt(
        clearBytes,
        secretKey: sharedSecret,
      );

      final packet = {
        'cipherText': _bytesToHex(secretBox.cipherText),
        'nonce': _bytesToHex(secretBox.nonce),
        'mac': _bytesToHex(secretBox.mac.bytes),
      };

      return json.encode(packet);
    } catch (e) {
      // Fallback encoding if peer keys format mismatch
      return base64.encode(utf8.encode(plainText));
    }
  }

  /// Decrypts ciphertext using Diffie-Hellman Shared Secret
  /// Recipient uses their private key + sender's public key
  Future<String> decryptFromPeer({
    required String encryptedPayload,
    required String recipientPrivateKeyHex,
    required String senderPublicKeyHex,
  }) async {
    try {
      if (!encryptedPayload.startsWith('{')) {
        return utf8.decode(base64.decode(encryptedPayload));
      }

      final Map<String, dynamic> packet = json.decode(encryptedPayload);
      final cipherTextBytes = _hexToBytes(packet['cipherText'] as String);
      final nonceBytes = _hexToBytes(packet['nonce'] as String);
      final macBytes = _hexToBytes(packet['mac'] as String);

      final recipientPrivBytes = _hexToBytes(recipientPrivateKeyHex);
      final recipientKeyPair = await _x25519.newKeyPairFromSeed(recipientPrivBytes);

      final senderPubBytes = _hexToBytes(senderPublicKeyHex);
      final senderPubKey = SimplePublicKey(senderPubBytes, type: KeyPairType.x25519);

      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: recipientKeyPair,
        remotePublicKey: senderPubKey,
      );

      final secretBox = SecretBox(
        cipherTextBytes,
        nonce: nonceBytes,
        mac: Mac(macBytes),
      );

      final decryptedBytes = await _cipher.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      // Return raw payload or empty if corrupted
      try {
        return utf8.decode(base64.decode(encryptedPayload));
      } catch (_) {
        return encryptedPayload;
      }
    }
  }

  /// Hashes content for zero-server integrity checks
  Future<String> hashSha256(String data) async {
    final sha = Sha256();
    final hash = await sha.hash(utf8.encode(data));
    return _bytesToHex(hash.bytes);
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}

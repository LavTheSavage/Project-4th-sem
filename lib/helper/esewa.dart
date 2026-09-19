import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateEsewaSignature({
  required String totalAmount,
  required String transactionUuid,
  required String productCode,
  required String secretKey,
}) {
  // Order MUST be strictly: total_amount,transaction_uuid,product_code
  final inputString =
      'total_amount=$totalAmount,transaction_uuid=$transactionUuid,product_code=$productCode';
  final key = utf8.encode(secretKey);
  final bytes = utf8.encode(inputString);

  final hmacSha256 = Hmac(sha256, key);
  final digest = hmacSha256.convert(bytes);

  return base64.encode(digest.bytes);
}

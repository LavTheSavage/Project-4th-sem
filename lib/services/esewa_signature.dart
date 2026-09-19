import 'dart:convert';
import 'package:crypto/crypto.dart';

class EsewaSignature {
  /// Generates Base64 HMAC-SHA256 signature required by eSewa v2
  static String generate({
    required String totalAmount,
    required String transactionUuid,
    required String productCode,
    required String secretKey,
  }) {
    // String template MUST match this exact order
    final input =
        'total_amount=$totalAmount,transaction_uuid=$transactionUuid,product_code=$productCode';
    final keyBytes = utf8.encode(secretKey);
    final inputBytes = utf8.encode(input);

    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(inputBytes);

    return base64.encode(digest.bytes);
  }
}

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'esewa_signature.dart';

class EsewaPaymentHandler {
  static void processPayment({
    required BuildContext context,
    required String amount,
    required String transactionUuid,
    required Function(String transactionUuid, String refId) onSuccess,
    required Function(String error) onFailure,
  }) {
    const productCode = 'EPAYTEST';
    const secretKey = '8gBm/:&EnhH.1/q';

    final signature = EsewaSignature.generate(
      totalAmount: amount,
      transactionUuid: transactionUuid,
      productCode: productCode,
      secretKey: secretKey,
    );

    const esewaUrl = 'https://rc-epay.esewa.com.np/api/epay/main/v2/form';

    // Create dynamic HTML Form using package:web
    final form = web.HTMLFormElement()
      ..method = 'POST'
      ..action = esewaUrl;

    final fields = {
      'amount': amount,
      'tax_amount': '0',
      'total_amount': amount,
      'transaction_uuid': transactionUuid,
      'product_code': productCode,
      'product_service_charge': '0',
      'product_delivery_charge': '0',
      'success_url': 'http://localhost:3000/payment-success',
      'failure_url': 'http://localhost:3000/payment-failure',
      'signed_field_names': 'total_amount,transaction_uuid,product_code',
      'signature': signature,
    };

    fields.forEach((key, value) {
      final input = web.HTMLInputElement()
        ..type = 'hidden'
        ..name = key
        ..value = value;
      form.appendChild(input);
    });

    web.document.body?.appendChild(form);
    form.submit();
  }
}

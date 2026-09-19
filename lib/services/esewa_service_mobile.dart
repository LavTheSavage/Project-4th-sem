import 'package:flutter/material.dart';
import 'package:esewa_flutter/esewa_flutter.dart';

class EsewaPaymentHandler {
  static void processPayment({
    required BuildContext context,
    required String amount,
    required String transactionUuid,
    required Function(String transactionUuid, String refId) onSuccess,
    required Function(String error) onFailure,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
          child: EsewaPayButton(
            paymentConfig: ESewaConfig.dev(
              amount: double.parse(amount),
              productCode: 'EPAYTEST',
              secretKey: '8gBm/:&EnhH.1/q',
              transactionUuid: transactionUuid,
              successUrl: 'https://developer.esewa.com.np/success',
              failureUrl: 'https://developer.esewa.com.np/failure',
            ),
            onSuccess: (EsewaPaymentResult result) {
              Navigator.pop(sheetContext);
              if (result.hasData && result.data != null) {
                // Returns Base64 payload in data string
                onSuccess(transactionUuid, result.data!.data ?? '');
              } else {
                onFailure(
                  'Payment completed but no response payload was received.',
                );
              }
            },
            onFailure: (error) {
              Navigator.pop(sheetContext);
              onFailure(error.toString());
            },
          ),
        );
      },
    );
  }
}

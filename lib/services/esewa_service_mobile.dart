import 'package:esewa_flutter/esewa_flutter.dart';
import 'package:flutter/material.dart';

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
              amt: double.parse(amount),
              pid: transactionUuid,
              su: 'https://developer.esewa.com.np/success',
              fu: 'https://developer.esewa.com.np/failure',
              scd: 'EPAYTEST',
            ),
            onSuccess: (EsewaPaymentResponse result) {
              Navigator.pop(sheetContext);
              final refId = result.refId ?? '';
              if (refId.isEmpty) {
                onFailure(
                  'Payment completed but no reference ID was returned.',
                );
                return;
              }
              onSuccess(transactionUuid, refId);
            },
            onFailure: (String message) {
              Navigator.pop(sheetContext);
              onFailure(message);
            },
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../services/esewa_service.dart'; // Import conditional export dispatcher

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final String orderAmount = "100";
  bool isLoading = false;

  void handlePayment() {
    setState(() => isLoading = true);

    // Generate unique ID per transaction
    final String transactionUuid =
        'ORDER_${DateTime.now().millisecondsSinceEpoch}';

    EsewaPaymentHandler.processPayment(
      context: context,
      amount: orderAmount,
      transactionUuid: transactionUuid,
      onSuccess: (txnUuid, refId) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Successful! Ref ID: $refId'),
            backgroundColor: Colors.green,
          ),
        );
        // Next: Send refId & txnUuid to your backend server for verification
      },
      onFailure: (error) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Total Amount: NPR $orderAmount',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF60BB46), // eSewa Green
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                onPressed: isLoading ? null : handlePayment,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Pay with eSewa',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

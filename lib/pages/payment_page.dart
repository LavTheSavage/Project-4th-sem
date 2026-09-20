import 'package:flutter/material.dart';

/// Gateway UI only. Keep all payment-provider calls and server-side verification
/// here when the eSewa and Khalti integrations are added.
class PaymentPage extends StatelessWidget {
  final String bookingId;
  final String itemName;
  final dynamic totalPrice;

  const PaymentPage({
    super.key,
    required this.bookingId,
    required this.itemName,
    required this.totalPrice,
  });

  void _showNotConnected(BuildContext context, String provider) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$provider payment'),
        content: Text(
          '$provider is ready to be connected for this approved booking. '
          'Add its checkout call and verify the payment on your server before '
          'setting this booking to paid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay for booking')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                itemName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount due: Rs $totalPrice',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Color(0xFF1E88E5)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your request was approved. Choose a payment method to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => _showNotConnected(context, 'eSewa'),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Pay with eSewa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF60BB46),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showNotConnected(context, 'Khalti'),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Pay with Khalti'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C2D91),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const Spacer(),
              Text(
                'Booking ID: $bookingId',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

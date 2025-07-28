import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ventzor/model/quote.dart';

class QuoteDetailsPage extends StatelessWidget {
  final Quote quote;

  const QuoteDetailsPage({required this.quote, super.key});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final statusColor = _getStatusColor(quote.status);

    return Scaffold(
      appBar: AppBar(title: Text('Quote #${quote.id.substring(0, 8)}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status:', style: TextStyle(fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            quote.status[0].toUpperCase() +
                                quote.status.substring(1),
                            style: TextStyle(color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Client: ${quote.clientName}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created: ${dateFormat.format(quote.createdAt)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (quote.expiryDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Expires: ${dateFormat.format(quote.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: quote.expiryDate!.isBefore(DateTime.now())
                              ? Colors.red
                              : null,
                        ),
                      ),
                    ],
                    if (quote.createdBy != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Created by: ${quote.createdBy}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...quote.items.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.description),
                  trailing: Text(
                    '${item.quantity} × ${currencyFormat.format(item.price)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  leading: Text(
                    currencyFormat.format(item.lineTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text(currencyFormat.format(quote.subtotal)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tax:'),
                        Text(currencyFormat.format(quote.tax)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          currencyFormat.format(quote.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (quote.notes != null && quote.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Notes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Text(quote.notes!),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.blue;
      case 'sent':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

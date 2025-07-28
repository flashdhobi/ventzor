import 'package:flutter/material.dart';
import 'package:ventzor/model/invoice.dart';

class InvoiceItemCard extends StatelessWidget {
  final InvoiceItem item;
  final ValueChanged<InvoiceItem> onChanged;
  final VoidCallback onDelete;

  const InvoiceItemCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            TextFormField(
              initialValue: item.description,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (value) =>
                  onChanged(item.copyWith(description: value)),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => onChanged(
                      item.copyWith(
                        quantity: double.tryParse(value) ?? item.quantity,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: item.unitPrice.toString(),
                    decoration: const InputDecoration(labelText: 'Unit Price'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => onChanged(
                      item.copyWith(
                        unitPrice: double.tryParse(value) ?? item.unitPrice,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '\$${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

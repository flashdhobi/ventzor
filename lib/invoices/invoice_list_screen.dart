import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ventzor/invoices/invoice_edit_screen.dart';
import 'package:ventzor/model/invoice.dart';
import 'package:ventzor/services/invoice_service.dart';

class InvoiceListScreen extends StatelessWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final invoiceRepo = Provider.of<InvoiceRepository>(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InvoiceEditScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Invoice>>(
        stream: invoiceRepo.getInvoices(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final invoices = snapshot.data!;

          if (invoices.isEmpty) {
            return const Center(child: Text('No invoices found'));
          }

          return ListView.builder(
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return ListTile(
                title: Text('Invoice #${invoice.invoiceNumber}'),
                subtitle: Text(
                  '${invoice.clientName} - ${DateFormat.yMd().format(invoice.date)}',
                ),
                trailing: Text('\$${invoice.total.toStringAsFixed(2)}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceEditScreen(invoice: invoice),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

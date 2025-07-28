import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ventzor/model/client.dart';
import 'package:ventzor/model/job.dart';
import 'package:ventzor/model/quote.dart';
import 'package:ventzor/services/client_service.dart';
import 'package:ventzor/services/job_service.dart';
import 'package:ventzor/services/quote_service.dart';

class JobEditScreen extends StatefulWidget {
  final Job? job;
  final DateTime? initialDate;
  final String orgId;

  const JobEditScreen({
    super.key,
    this.job,
    this.initialDate,
    required this.orgId,
  });

  @override
  State<JobEditScreen> createState() => _JobEditScreenState();
}

class _JobEditScreenState extends State<JobEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _estimatedCostController;
  late DateTime _startTime;
  late DateTime _endTime;
  List<String> _assignedTeamMembers = [];
  bool _isRecurring = false;
  String _recurrenceType = 'weekly';
  int _recurrenceInterval = 1;
  int _recurrenceCount = 1;

  // Client selection
  Client? _selectedClient;
  bool _loadingClients = false;
  List<Client> _clients = [];
  String? _clientSearchQuery;

  // Quote selection
  Quote? _selectedQuote;
  bool _loadingQuotes = false;
  List<Quote> _quotes = [];
  StreamSubscription<Quote?>? _quoteSubscription;

  final List<String> _availableTeamMembers = [
    'John Smith',
    'Sarah Johnson',
    'Mike Brown',
    'Emily Davis',
  ];
  @override
  void initState() {
    super.initState();
    _initializeForm();
    // Wait for form initialization before loading clients
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClients().then((_) {
        if (widget.job != null) {
          _loadInitialClientAndQuote(widget.job!.clientId, widget.job!.quoteId);
        }
      });
    });
  }

  void _initializeForm() {
    if (widget.job != null) {
      _titleController = TextEditingController(text: widget.job!.title);
      _descriptionController = TextEditingController(
        text: widget.job!.description,
      );
      _locationController = TextEditingController(text: widget.job!.location);
      _estimatedCostController = TextEditingController(
        text: widget.job!.estimatedCost.toStringAsFixed(2),
      );
      _startTime = widget.job!.startTime;
      _endTime = widget.job!.endTime;
      _assignedTeamMembers = widget.job!.assignedTeamMembers;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationController = TextEditingController();
      _estimatedCostController = TextEditingController(text: '0.00');
      _startTime = widget.initialDate ?? DateTime.now();
      _endTime = _startTime.add(const Duration(hours: 1));
    }
  }

  Future<void> _loadClients({String? query}) async {
    final clientRepo = Provider.of<ClientRepository>(context, listen: false);
    setState(() => _loadingClients = true);

    try {
      final clients = query == null || query.isEmpty
          ? await clientRepo.getClientsByOrg(widget.orgId)
          : await clientRepo.searchClients(widget.orgId, query);

      setState(() => _clients = clients);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load clients: $e')));
    } finally {
      setState(() => _loadingClients = false);
    }
  }

  Future<void> _loadInitialClientAndQuote(
    String clientId,
    String quoteId,
  ) async {
    if (!mounted || _clients.isEmpty) return;

    // Find matching client
    final matchingClient = _clients.firstWhere(
      (c) => c.id == clientId,
      orElse: () {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Client $clientId not found')));
        }
        return _clients.first;
      },
    );

    setState(() {
      _selectedClient = matchingClient;
      _loadingQuotes = true;
    });

    try {
      // Load accepted quotes first
      await _loadAcceptedQuotes(clientId);

      // Then try to find the specific quote
      if (quoteId.isNotEmpty) {
        final quoteRepo = Provider.of<QuoteRepository>(context, listen: false);
        _quoteSubscription?.cancel();
        _quoteSubscription = quoteRepo
            .getQuote(quoteId)
            .listen(
              (quote) {
                if (mounted) {
                  setState(() {
                    _selectedQuote = _quotes.firstWhere(
                      (q) => q.id == quote.id,
                      orElse: () => quote,
                    );
                    _estimatedCostController.text = quote.total.toStringAsFixed(
                      2,
                    );
                  });
                }
              },
              onError: (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load quote: $e')),
                  );
                }
              },
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading quote data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingQuotes = false);
      }
    }
  }

  Future<void> _loadAcceptedQuotes(String clientId) async {
    if (!mounted) return;

    final quoteRepo = Provider.of<QuoteRepository>(context, listen: false);
    setState(() => _loadingQuotes = true);

    try {
      final quotes = await quoteRepo.getQuotesByClientAndStatus(
        clientId,
        'accepted',
      );
      if (mounted) {
        setState(() {
          _quotes = quotes;
          // Ensure selected quote exists in the new list
          if (_selectedQuote != null &&
              !quotes.any((q) => q.id == _selectedQuote!.id)) {
            _selectedQuote = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load quotes: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingQuotes = false);
      }
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final dateTime = await showDateTimePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (dateTime != null) {
      setState(() => _startTime = dateTime);
      if (_endTime.isBefore(_startTime)) {
        setState(() => _endTime = _startTime.add(const Duration(hours: 1)));
      }
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final dateTime = await showDateTimePicker(
      context: context,
      initialDate: _endTime,
      firstDate: _startTime,
      lastDate: DateTime(2100),
    );
    if (dateTime != null) {
      setState(() => _endTime = dateTime);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _estimatedCostController.dispose();
    _quoteSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job == null ? 'Create New Job' : 'Edit Job'),

        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveJob),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Client Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _loadingClients
                      ? const Center(child: CircularProgressIndicator())
                      : _clients.isEmpty
                      ? const Text(
                          'No clients found',
                          style: TextStyle(color: Colors.grey),
                        )
                      : DropdownButtonFormField<Client>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Client*',
                          ),
                          value: _selectedClient,
                          items: _clients.map((client) {
                            return DropdownMenuItem<Client>(
                              value: client,
                              child: SizedBox(
                                height: 60, // Fixed height for two lines
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      client.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      client.company ?? client.email,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          selectedItemBuilder: (context) {
                            return _clients.map((client) {
                              return Text(client.name);
                            }).toList();
                          },
                          onChanged: (Client? value) {
                            setState(() {
                              _selectedClient = value;
                              _selectedQuote = null;
                            });
                            if (value != null) {
                              _loadAcceptedQuotes(value.id);
                            }
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a client';
                            }
                            return null;
                          },
                          isExpanded: true,
                        ),
                ],
              ),

              const SizedBox(height: 16),

              // Quote Selection (only shown if client is selected)
              if (_selectedClient != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Quote (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedQuote != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedQuote = null;
                                _estimatedCostController.text = '0.00';
                              });
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingQuotes)
                      const Center(child: CircularProgressIndicator())
                    else if (_quotes.isEmpty)
                      const Text(
                        'No accepted quotes found for this client',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      DropdownButtonFormField<Quote>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Select a quote',
                        ),
                        value: _selectedQuote,
                        items: _quotes.map((quote) {
                          return DropdownMenuItem<Quote>(
                            value: quote,
                            child: SizedBox(
                              height: 64, // More height for three lines
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quote #${quote.id.substring(0, 8)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Total: \$${quote.total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Created: ${DateFormat.yMd().format(quote.createdAt)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        selectedItemBuilder: (context) {
                          return _quotes.map((quote) {
                            return Text('Quote #${quote.id.substring(0, 8)}');
                          }).toList();
                        },
                        onChanged: (Quote? value) {
                          setState(() {
                            _selectedQuote = value;
                            if (value != null) {
                              _estimatedCostController.text = value.total
                                  .toStringAsFixed(2);
                            }
                          });
                        },
                        isExpanded: true,
                      ),
                  ],
                ),

              const SizedBox(height: 16),

              // Job Details
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // Schedule Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Schedule *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: const Text('Start Time'),
                        subtitle: Text(
                          DateFormat.yMd().add_jm().format(_startTime),
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _selectStartTime(context),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('End Time'),
                        subtitle: Text(
                          DateFormat.yMd().add_jm().format(_endTime),
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _selectEndTime(context),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Recurring Job'),
                        value: _isRecurring,
                        onChanged: (value) {
                          setState(() {
                            _isRecurring = value;
                          });
                        },
                      ),
                      if (_isRecurring) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _recurrenceType,
                          decoration: const InputDecoration(
                            labelText: 'Recurrence Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _recurrenceType = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Repeat Every (interval)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: _recurrenceInterval.toString(),
                          onChanged: (value) {
                            final interval = int.tryParse(value) ?? 1;
                            setState(() {
                              _recurrenceInterval = interval > 0 ? interval : 1;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Number of Occurrences',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: _recurrenceCount.toString(),
                          onChanged: (value) {
                            final count = int.tryParse(value) ?? 1;
                            setState(() {
                              _recurrenceCount = count > 0 ? count : 1;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Team Members Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Team Members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Select Team Members',
                        ),
                        isExpanded: true,
                        items: _availableTeamMembers.map((member) {
                          return DropdownMenuItem<String>(
                            value: member,
                            child: Text(member),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null &&
                              !_assignedTeamMembers.contains(newValue)) {
                            setState(() {
                              _assignedTeamMembers.add(newValue);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _assignedTeamMembers.map((member) {
                          return Chip(
                            label: Text(member),
                            onDeleted: () {
                              setState(() {
                                _assignedTeamMembers.remove(member);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Estimated Cost
              TextFormField(
                controller: _estimatedCostController,
                decoration: const InputDecoration(
                  labelText: 'Estimated Cost *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (double.tryParse(value!) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saveJob,
                child: const Text('SAVE JOB', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClient == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a client')));
      return;
    }

    final job = Job(
      id: widget.job?.id,
      title: _titleController.text,
      clientId: _selectedClient!.id,
      quoteId: _selectedQuote?.id ?? '',
      description: _descriptionController.text,
      startTime: _startTime,
      endTime: _endTime,
      status: widget.job?.status ?? 'scheduled',
      assignedTeamMembers: _assignedTeamMembers,
      location: _locationController.text,
      estimatedCost: double.parse(_estimatedCostController.text),
      actualCost: widget.job?.actualCost ?? 0.0,
      // isRecurring: _isRecurring,
      // recurrenceType: _isRecurring ? _recurrenceType : null,
      // recurrenceInterval: _isRecurring ? _recurrenceInterval : null,
      // recurrenceCount: _isRecurring ? _recurrenceCount : null,
    );

    try {
      final jobRepo = Provider.of<JobRepository>(context, listen: false);
      if (job.id == null) {
        await jobRepo.addJob(job);
      } else {
        await jobRepo.updateJob(job);
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save job: $e')));
    }
  }

  Future<void> _confirmExit(BuildContext context) async {
    bool shouldExit =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
              'Are you sure you want to discard your changes?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      Navigator.pop(context);
    }
  }
}

Future<DateTime?> showDateTimePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );

  if (date == null) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate),
  );

  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ventzor/model/job.dart';
import 'package:ventzor/services/job_service.dart';

class JobEditScreen extends StatefulWidget {
  final Job? job;
  final DateTime? initialDate;

  const JobEditScreen({super.key, this.job, this.initialDate});

  @override
  State<JobEditScreen> createState() => _JobEditScreenState();
}

class _JobEditScreenState extends State<JobEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _clientIdController;
  late final TextEditingController _quoteIdController;
  late final TextEditingController _estimatedCostController;
  late DateTime _startTime;
  late DateTime _endTime;
  late List<String> _assignedTeamMembers;
  final _formKey = GlobalKey<FormState>();

  final List<String> _teamMembers = [
    'John Smith',
    'Sarah Johnson',
    'Mike Brown',
    'Emily Davis',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.job != null) {
      _titleController = TextEditingController(text: widget.job!.title);
      _descriptionController = TextEditingController(
        text: widget.job!.description,
      );
      _locationController = TextEditingController(text: widget.job!.location);
      _clientIdController = TextEditingController(text: widget.job!.clientId);
      _quoteIdController = TextEditingController(text: widget.job!.quoteId);
      _estimatedCostController = TextEditingController(
        text: widget.job!.estimatedCost.toString(),
      );
      _startTime = widget.job!.startTime;
      _endTime = widget.job!.endTime;
      _assignedTeamMembers = widget.job!.assignedTeamMembers;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationController = TextEditingController();
      _clientIdController = TextEditingController();
      _quoteIdController = TextEditingController();
      _estimatedCostController = TextEditingController(text: '0.0');
      _startTime = widget.initialDate ?? DateTime.now();
      _endTime = _startTime.add(const Duration(hours: 1));
      _assignedTeamMembers = [];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _clientIdController.dispose();
    _quoteIdController.dispose();
    _estimatedCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job == null ? 'Create New Job' : 'Edit Job'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _confirmExit(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveJob),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32, // Account for padding
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitleField(),
                      const SizedBox(height: 16),
                      _buildDescriptionField(),
                      const SizedBox(height: 16),
                      _buildLocationField(),
                      const SizedBox(height: 16),
                      Expanded(child: _buildDateTimeSection()),
                      const SizedBox(height: 16),
                      Expanded(child: _buildTeamMembersSection()),
                      const SizedBox(height: 16),
                      Expanded(child: _buildJobDetailsSection()),
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Job Title',
        border: OutlineInputBorder(),
      ),
      validator: (value) => value?.isEmpty ?? true ? 'Title is required' : null,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      decoration: const InputDecoration(
        labelText: 'Location',
        border: OutlineInputBorder(),
      ),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Location is required' : null,
    );
  }

  Widget _buildDateTimeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Schedule',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(DateFormat.yMd().add_jm().format(_startTime)),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final dateTime = await showDateTimePicker(
                  context: context,
                  initialDate: _startTime,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (dateTime != null) {
                  setState(() => _startTime = dateTime);
                  if (_endTime.isBefore(_startTime)) {
                    setState(
                      () => _endTime = _startTime.add(const Duration(hours: 1)),
                    );
                  }
                }
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(DateFormat.yMd().add_jm().format(_endTime)),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final dateTime = await showDateTimePicker(
                  context: context,
                  initialDate: _endTime,
                  firstDate: _startTime,
                  lastDate: DateTime(2100),
                );
                if (dateTime != null) {
                  setState(() => _endTime = dateTime);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Team Members',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._teamMembers.map((member) {
              return CheckboxListTile(
                title: Text(member),
                value: _assignedTeamMembers.contains(member),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _assignedTeamMembers.add(member);
                    } else {
                      _assignedTeamMembers.remove(member);
                    }
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Job Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientIdController,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Client ID is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quoteIdController,
              decoration: const InputDecoration(
                labelText: 'Quote ID',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Quote ID is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _estimatedCostController,
              decoration: const InputDecoration(
                labelText: 'Estimated Cost',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Estimated cost is required';
                if (double.tryParse(value!) == null)
                  return 'Enter a valid number';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _saveJob,
      child: const Text('SAVE JOB', style: TextStyle(fontSize: 16)),
    );
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;

    final job = Job(
      id: widget.job?.id,
      title: _titleController.text,
      clientId: _clientIdController.text,
      quoteId: _quoteIdController.text,
      description: _descriptionController.text,
      startTime: _startTime,
      endTime: _endTime,
      status: widget.job?.status ?? 'scheduled',
      assignedTeamMembers: _assignedTeamMembers,
      location: _locationController.text,
      estimatedCost: double.parse(_estimatedCostController.text),
      actualCost: widget.job?.actualCost ?? 0.0,
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ventzor/model/job.dart';
import 'package:ventzor/model/quote.dart';
import 'package:ventzor/scheduler/job_edit_screen.dart';
import 'package:ventzor/services/job_service.dart';
import 'package:ventzor/services/quote_service.dart';

class JobSchedulerScreen extends StatefulWidget {
  const JobSchedulerScreen({super.key});

  @override
  State<JobSchedulerScreen> createState() => _JobSchedulerScreenState();
}

class _JobSchedulerScreenState extends State<JobSchedulerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  String? _error;
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String _filterStatus = 'all';
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loaduser();
  }

  Future<void> _loaduser() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get user's organization ID
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      _orgId = userDoc.data()?['orgId'];
      if (_orgId == null) throw Exception('No organization assigned');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    JobEditScreen(initialDate: _selectedDay, orgId: _orgId!),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<Job>(
            firstDay: DateTime(2000),
            lastDay: DateTime(2050),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: (day) => _getJobsForDay(day),
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonDecoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              formatButtonTextStyle: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text('No day selected'))
                : _buildJobList(),
          ),
        ],
      ),
    );
  }

  List<Job> _getJobsForDay(DateTime day) {
    // This would be replaced with actual data from Firestore
    return [];
  }

  Widget _buildJobList() {
    final jobRepo = Provider.of<JobRepository>(context);
    final quoteRepo = Provider.of<QuoteRepository>(context);

    return StreamBuilder<List<Job>>(
      stream: jobRepo.getJobsForDay(_selectedDay!),
      builder: (context, jobSnapshot) {
        if (jobSnapshot.hasError) {
          return Center(child: Text('Error: ${jobSnapshot.error}'));
        }

        if (jobSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = jobSnapshot.data!
            .where(
              (job) => _filterStatus == 'all' || job.status == _filterStatus,
            )
            .toList();

        if (jobs.isEmpty) {
          return Center(
            child: Text(
              'No jobs for ${DateFormat.yMMMMd().format(_selectedDay!)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }

        return ListView.builder(
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Container(
                  width: 10,
                  height: double.infinity,
                  color: job.statusColor,
                ),
                title: Text(job.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.description),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat.jm().format(job.startTime)} - ${DateFormat.jm().format(job.endTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<Quote>(
                      stream: quoteRepo.getQuote(job.quoteId),
                      builder: (context, quoteSnapshot) {
                        if (quoteSnapshot.hasData) {
                          return Text(
                            'Quote: \$${quoteSnapshot.data!.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _handleJobAction(value, job),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'start',
                      child: Text('Start Job'),
                    ),
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Complete Job'),
                    ),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel Job'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
                onTap: () => _showJobDetails(context, job),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showJobDetails(BuildContext context, Job job) async {
    final quoteRepo = Provider.of<QuoteRepository>(context, listen: false);
    final quote = await quoteRepo.getQuote(job.quoteId).first;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(job.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(job.description, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Text(
                'Time: ${DateFormat.MMMMd().add_jm().format(job.startTime)} - ${DateFormat.jm().format(job.endTime)}',
              ),
              const SizedBox(height: 8),
              Text('Location: ${job.location}'),
              const SizedBox(height: 8),
              Text('Status: ${job.status.toUpperCase()}'),
              const SizedBox(height: 16),
              const Text(
                'Quote Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...quote.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.description),
                      Text('\$${item.price.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${quote.total.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleJobAction(String action, Job job) async {
    final jobRepo = Provider.of<JobRepository>(context, listen: false);

    try {
      switch (action) {
        case 'edit':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobEditScreen(job: job, orgId: _orgId!),
            ),
          );
          break;
        case 'start':
          await jobRepo.updateJobStatus(job.id!, 'in-progress');
          break;
        case 'complete':
          await jobRepo.updateJobStatus(job.id!, 'completed');
          break;
        case 'cancel':
          await jobRepo.updateJobStatus(job.id!, 'cancelled');
          break;
        case 'delete':
          await _deleteJob(job.id!);
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to $action job: $e')));
    }
  }

  Future<void> _deleteJob(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job?'),
        content: const Text('Are you sure you want to delete this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Provider.of<JobRepository>(context, listen: false).deleteJob(id);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete job: $e')));
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Jobs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('All Jobs'),
              value: 'all',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Scheduled'),
              value: 'scheduled',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('In Progress'),
              value: 'in-progress',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Completed'),
              value: 'completed',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Cancelled'),
              value: 'cancelled',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

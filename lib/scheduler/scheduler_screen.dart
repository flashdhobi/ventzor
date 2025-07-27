import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ventzor/model/event.dart';
import 'package:ventzor/scheduler/event_dialog.dart';
import 'package:ventzor/services/event_service.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  final List<Color> _eventColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
  ];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
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
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEventDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<Event>(
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
            eventLoader: (day) => _getEventsForDay(day),
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
                : _buildEventList(),
          ),
        ],
      ),
    );
  }

  List<Event> _getEventsForDay(DateTime day) {
    // This is a placeholder - in a real app, you'd get events from Firestore
    return [];
  }

  Widget _buildEventList() {
    final eventRepo = Provider.of<EventRepository>(context);

    return StreamBuilder<List<Event>>(
      stream: eventRepo.getEventsForDay(_selectedDay!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data!;

        if (events.isEmpty) {
          return Center(
            child: Text(
              'No events for ${DateFormat.yMMMMd().format(_selectedDay!)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }

        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Container(
                  width: 10,
                  height: double.infinity,
                  color: _eventColors[index % _eventColors.length],
                ),
                title: Text(event.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.description),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat.jm().format(event.from)} - ${DateFormat.jm().format(event.to)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteEvent(event.id!),
                ),
                onTap: () => _showEditEventDialog(context, event),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddEventDialog(BuildContext context) async {
    final event = await showDialog<Event>(
      context: context,
      builder: (context) => EventDialog(date: _selectedDay ?? DateTime.now()),
    );

    if (event != null) {
      try {
        await Provider.of<EventRepository>(
          context,
          listen: false,
        ).addEvent(event);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add event: $e')));
      }
    }
  }

  Future<void> _showEditEventDialog(BuildContext context, Event event) async {
    final updatedEvent = await showDialog<Event>(
      context: context,
      builder: (context) => EventDialog(event: event),
    );

    if (updatedEvent != null) {
      try {
        await Provider.of<EventRepository>(
          context,
          listen: false,
        ).updateEvent(updatedEvent);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update event: $e')));
      }
    }
  }

  Future<void> _deleteEvent(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('Are you sure you want to delete this event?'),
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
        await Provider.of<EventRepository>(
          context,
          listen: false,
        ).deleteEvent(id);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete event: $e')));
      }
    }
  }
}

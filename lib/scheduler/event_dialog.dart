import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ventzor/model/event.dart';

class EventDialog extends StatefulWidget {
  final Event? event;
  final DateTime? date;

  const EventDialog({super.key, this.event, this.date});

  @override
  State<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _from;
  late DateTime _to;
  late bool _isAllDay;
  late Color _selectedColor;

  final List<Color> _colorOptions = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController = TextEditingController(text: widget.event!.title);
      _descriptionController = TextEditingController(
        text: widget.event!.description,
      );
      _from = widget.event!.from;
      _to = widget.event!.to;
      _isAllDay = widget.event!.isAllDay;
      _selectedColor = _colorOptions.firstWhere(
        (color) => color.value.toString() == widget.event!.color,
        orElse: () => Colors.blue,
      );
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _from = widget.date ?? DateTime.now();
      _to = _from.add(const Duration(hours: 1));
      _isAllDay = false;
      _selectedColor = Colors.blue;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Add Event' : 'Edit Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('All Day'),
              value: _isAllDay,
              onChanged: (value) => setState(() => _isAllDay = value),
            ),
            ListTile(
              title: Text('From: ${DateFormat.yMd().add_jm().format(_from)}'),
              onTap: () async {
                if (_isAllDay) {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _from,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() => _from = date);
                    if (_to.isBefore(_from)) {
                      _to = _from.add(const Duration(days: 1));
                    }
                  }
                } else {
                  final dateTime = await showDateTimePicker(
                    context: context,
                    initialDate: _from,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (dateTime != null) {
                    setState(() => _from = dateTime);
                    if (_to.isBefore(_from)) {
                      _to = _from.add(const Duration(hours: 1));
                    }
                  }
                }
              },
            ),
            ListTile(
              title: Text('To: ${DateFormat.yMd().add_jm().format(_to)}'),
              onTap: () async {
                if (_isAllDay) {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _to,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() => _to = date);
                  }
                } else {
                  final dateTime = await showDateTimePicker(
                    context: context,
                    initialDate: _to,
                    firstDate: _from,
                    lastDate: DateTime(2100),
                  );
                  if (dateTime != null) {
                    setState(() => _to = dateTime);
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('Color'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _colorOptions.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor == color
                          ? Border.all(width: 2, color: Colors.black)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_titleController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Title is required')),
              );
              return;
            }

            final event = Event(
              id: widget.event?.id,
              title: _titleController.text,
              description: _descriptionController.text,
              from: _from,
              to: _to,
              isAllDay: _isAllDay,
              color: _selectedColor.value.toString(),
            );

            Navigator.pop(context, event);
          },
          child: const Text('Save'),
        ),
      ],
    );
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TuitionApp());
}

class TuitionApp extends StatelessWidget {
  const TuitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Class Manager',
      theme: ThemeData(
        primaryColor: Colors.blueAccent,
        brightness: Brightness.light,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
          bodyMedium: TextStyle(color: Colors.black54),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      home: const ClassListScreen(),
    );
  }
}

class ClassItem {
  String name;
  String day;
  List<bool> weekCheckboxes;

  ClassItem({
    required this.name,
    required this.day,
    required this.weekCheckboxes,
  });

  // Convert ClassItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'day': day,
      'weekCheckboxes': weekCheckboxes,
    };
  }

  // Convert JSON to ClassItem
  factory ClassItem.fromJson(Map<String, dynamic> json) {
    return ClassItem(
      name: json['name'],
      day: json['day'],
      weekCheckboxes: List<bool>.from(json['weekCheckboxes']),
    );
  }
}

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key});

  @override
  _ClassListScreenState createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  final List<ClassItem> _classes = [];
  final TextEditingController _classController = TextEditingController();
  String _selectedDay = 'Monday';

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadClasses(); // Load saved classes on app start
  }

  Future<void> _initializeNotifications() async {
     AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
     DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'attendance_category',
          actions: [
            DarwinNotificationAction.plain('YES_ACTION', 'Yes'),
            DarwinNotificationAction.plain('NO_ACTION', 'No'),
          ],
        ),
      ],
    );
    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) async {
      if (details.payload != null) {
        int classIndex = int.parse(details.payload!);
        if (details.actionId == 'YES_ACTION') {
          _markAttendanceForCurrentWeek(classIndex);  // Mark attendance if Yes is clicked
        }
      }
    });
  }

  void _addClass() {
    final className = _classController.text;
    if (className.isNotEmpty) {
      setState(() {
        _classes.add(ClassItem(
          name: className,
          day: _selectedDay,
          weekCheckboxes: [false, false, false, false],
        ));
        _classController.clear();
        scheduleWeeklyNotification(_classes.length - 1);
        _saveClasses(); // Save classes after adding a new one
      });
    } else {
      // Show error message if class name is empty
      _showErrorDialog('Class name cannot be empty.');
    }
  }

  Future<void> scheduleWeeklyNotification(int classIndex) async {
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    String classDay = _classes[classIndex].day;
    int dayIndex = _getDayIndex(classDay);

    // Notification with Yes/No actions for attendance reminder
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'class_reminder_channel',
      'Class Reminder',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('YES_ACTION', 'Yes'),
        AndroidNotificationAction('NO_ACTION', 'No'),
      ],
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      categoryIdentifier: 'attendance_category',
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      classIndex,
      'Class Attendance Reminder',
      'Did you attend ${_classes[classIndex].name} today?',
      _nextInstanceOfWeekday(dayIndex, hour: 22), // 10 PM
      NotificationDetails(android: androidDetails, iOS: iOSDetails),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: classIndex.toString(), // Send class index as payload
    );

    // Notification for class fee reminder on 4th week
    await flutterLocalNotificationsPlugin.zonedSchedule(
      classIndex + 100, // Different ID for fee reminder
      'Final Week Class Fee Reminder',
      'Reminder: The fees for ${_classes[classIndex].name}.',
      _nextInstanceOfWeekday(dayIndex, hour: 10, weekOffset: 3), // 10 AM on 4th week
      NotificationDetails(android: androidDetails, iOS: iOSDetails),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: classIndex.toString(),
    );
  }

  int _getDayIndex(String day) {
    switch (day) {
      case 'Monday':
        return DateTime.monday;
      case 'Tuesday':
        return DateTime.tuesday;
      case 'Wednesday':
        return DateTime.wednesday;
      case 'Thursday':
        return DateTime.thursday;
      case 'Friday':
        return DateTime.friday;
      case 'Saturday':
        return DateTime.saturday;
      case 'Sunday':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, {int hour = 9, int weekOffset = 0}) {
    tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local);
    scheduledDate = scheduledDate.add(Duration(days: weekOffset * 7)); // Corrected here
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate.add(Duration(hours: hour - scheduledDate.hour));
  }

  void _markAttendanceForCurrentWeek(int classIndex) {
    setState(() {
      for (int i = 0; i < _classes[classIndex].weekCheckboxes.length; i++) {
        if (!_classes[classIndex].weekCheckboxes[i]) {
          _classes[classIndex].weekCheckboxes[i] = true;
          break;
        }
      }

      // Check if all weeks are marked
      if (_classes[classIndex].weekCheckboxes.every((checked) => checked)) {
        // Reset checkboxes for the next cycle
        _classes[classIndex].weekCheckboxes = [false, false, false, false];
      }
      _saveClasses(); // Save attendance changes
    });
  }

  Future<void> _saveClasses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> encodedClasses = _classes.map((classItem) {
      return jsonEncode(classItem.toJson());
    }).toList();
    await prefs.setStringList('classes', encodedClasses);
  }

  Future<void> _loadClasses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? encodedClasses = prefs.getStringList('classes');
    if (encodedClasses != null) {
      setState(() {
        _classes.clear();
        _classes.addAll(encodedClasses.map((encodedClass) {
          return ClassItem.fromJson(jsonDecode(encodedClass));
        }).toList());
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tuition Classes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _classController,
              decoration: InputDecoration(
                labelText: 'Class Name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addClass,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_classes[index].name),
                          ),
                          DropdownButton<String>(
                            value: _classes[index].day,
                            items: const [
                              DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                              DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday')),
                              DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday')),
                              DropdownMenuItem(value: 'Thursday', child: Text('Thursday')),
                              DropdownMenuItem(value: 'Friday', child: Text('Friday')),
                              DropdownMenuItem(value: 'Saturday', child: Text('Saturday')),
                              DropdownMenuItem(value: 'Sunday', child: Text('Sunday')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _classes[index].day = value!;
                                _saveClasses();
                              });
                            },
                          ),
                        ],
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(4, (weekIndex) {
                          return Row(
                            children: [
                              Checkbox(
                                value: _classes[index].weekCheckboxes[weekIndex],
                                onChanged: (value) {
                                  setState(() {
                                    _classes[index].weekCheckboxes[weekIndex] = value!;
                                    // Reset checkboxes if all are checked
                                    if (_classes[index].weekCheckboxes.every((checked) => checked)) {
                                      _classes[index].weekCheckboxes = [false, false, false, false];
                                    }
                                    _saveClasses(); // Save changes to preferences
                                  });
                                },
                              ),
                              Text('W${weekIndex + 1}'),
                            ],
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

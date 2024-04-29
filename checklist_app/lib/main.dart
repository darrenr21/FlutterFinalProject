import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tz.initializeTimeZones();
  runApp(TodoApp());
}

class TodoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checklist App',
      theme: ThemeData(
        primaryColor: Colors.deepPurple,
        textTheme: TextTheme(
          bodyText1: TextStyle(color: Colors.white),
          bodyText2: TextStyle(color: Colors.white),
        ),
      ),
      home: TodoList(),
    );
  }
}

class TodoList extends StatefulWidget {
  @override
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _timerController = TextEditingController();
  final Map<String, int> _todos = {};
  final Map<String, Timer> _timers = {};
  SharedPreferences? _prefs;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    initNotifications();
    loadTodos();
  }

  @override
  void dispose() {
    _timers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

  void initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon.jpg');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void loadTodos() async {
    _prefs = await SharedPreferences.getInstance();
    List<String>? todosList = _prefs!.getStringList('todos');
    if (todosList != null) {
      for (var item in todosList) {
        var split = item.split(',');
        _todos[split[0]] = int.parse(split[1]);
      }
    }
    setState(() {});
  }

  void saveTodos() async {
    List<String> todosList =
        _todos.entries.map((e) => '${e.key},${e.value}').toList();
    await _prefs!.setStringList('todos', todosList);
  }

  void startTimer(String task) {
    final duration = Duration(seconds: _todos[task]!);
    if (_timers[task] != null) {
      _timers[task]!.cancel();
    }
    _timers[task] = Timer.periodic(Duration(seconds: 1), (timer) {
      if (timer.tick >= duration.inSeconds) {
        timer.cancel();
        onEnd(task);
      } else {
        setState(() {});
      }
    });
    _showNotification(task, duration); // Schedule a notification
  }

  void onEnd(String task) {
    setState(() {
      _todos.remove(task);
      _timers.remove(task);
    });
    saveTodos();
  }

  Future<void> _showNotification(String task, Duration duration) async {
    var scheduledTime = tz.TZDateTime.now(tz.local).add(duration);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'my_task_reminders',
      'My Task Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Reminder',
      'Your task "$task" is due!',
      scheduledTime,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void editTask(String oldTask) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Task', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        content: Column(
          children: [
            TextField(
              controller: _taskController..text = oldTask,
              decoration: InputDecoration(
                labelText: 'Task',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            TextField(
              controller: _timerController..text = _todos[oldTask].toString(),
              decoration: InputDecoration(
                labelText: 'Timer (in seconds)',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              style: TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Save', style: TextStyle(color: Colors.white)),
            onPressed: () {
              setState(() {
                int duration = int.parse(_timerController.text);
                _todos.remove(oldTask);
                _timers[oldTask]?.cancel();
                _timers.remove(oldTask);
                String newTask = _taskController.text;
                _todos[newTask] = duration;
                startTimer(newTask);
              });
              saveTodos();
              _taskController.clear();
              _timerController.clear();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Checklist')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.deepPurple],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _taskController,
                  decoration: InputDecoration(
                    labelText: 'Add a task',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
                TextField(
                  controller: _timerController,
                  decoration: InputDecoration(
                    labelText: 'Timer (in seconds)',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _todos[_taskController.text] =
                          int.parse(_timerController.text);
                      _taskController.clear();
                      _timerController.clear();
                    });
                    saveTodos();
                    startTimer(_taskController.text);
                  },
                  child: Text('Add Task'),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      String task = _todos.keys.elementAt(index);
                      Timer? timer = _timers[task];
                      int remaining = timer != null
                          ? _todos[task]! - timer.tick
                          : _todos[task]!;
                      return ListTile(
                        title: Text(
                          '$task (${formatDuration(Duration(seconds: remaining))})',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.timer, color: Colors.white),
                              onPressed: () {
                                startTimer(task);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.white),
                              onPressed: () {
                                editTask(task);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _todos.remove(task);
                                  _timers[task]?.cancel();
                                  _timers.remove(task);
                                });
                                saveTodos();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:background_task/background_task.dart';
import 'package:background_task_example/log_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;


import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tzz;

@pragma('vm:entry-point')
void backgroundHandler(Location data) async {
  tz.initializeTimeZones();
  await initializeNotifications();
  debugPrint('🇯🇵 backgroundHandler: ${DateTime.now()}, $data');

  SavedTimesController savedTimesController = Get.put(SavedTimesController());
  savedTimesController.saveCurrentTime(); // Save current time

  // Your other background tasks
  // Future(() async {
  //   await IsarRepository.configure();
  //   IsarRepository.isar.writeTxnSync(() {
  //     final latLng = LatLng()
  //       ..lat = data.lat ?? 0
  //       ..lng = data.lng ?? 0;
  //     IsarRepository.isar.latLngs.putSync(latLng);
  //   });
  // });

  // Call notification function if needed
  scheduleNotification("$data");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initializeNotifications();
  requestLocationPermission();

  // Initialize necessary objects
  SavedTimesController savedTimesController = SavedTimesController();
  savedTimesController.saveCurrentTime(); // Save current time initially

  await BackgroundTask.instance.setBackgroundHandler(backgroundHandler);
 //await IsarRepository.configure();
  await initializeDateFormatting('ja_JP');
  runApp(MyApp());


}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String _bgText = 'no start';
  String _statusText = 'status';
  bool _isEnabledEvenIfKilled = true;

  late final StreamSubscription<Location> _bgDisposer;
  late final StreamSubscription<StatusEvent> _statusDisposer;

  final SavedTimesController savedTimesController = Get.put(SavedTimesController());


  @override
  void initState() {
    super.initState();

    _bgDisposer = BackgroundTask.instance.stream.listen((event) {
      final message = '${DateTime.now()}: ${event.lat}, ${event.lng}';
      debugPrint(message);
      setState(() {
        _bgText = message;
      });
    });

    Future(() async {
      final result = await Permission.notification.request();
      debugPrint('notification: $result');
      if (Platform.isAndroid) {
        if (result.isGranted) {
          await BackgroundTask.instance.setAndroidNotification(
            title: 'バックグラウンド処理',
            message: 'バックグラウンド処理を実行中',
          );
        }
      }
    });

    _statusDisposer = BackgroundTask.instance.status.listen((event) {
      final message =
          'status: ${event.status.value}, message: ${event.message}';
      setState(() {
        _statusText = message;
      });
    });
  }

  @override
  void dispose() {
    _bgDisposer.cancel();
    _statusDisposer.cancel();
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
        actions: [
          IconButton(
            onPressed: () {
              //LogPage.show(context);
            },
            icon: const Icon(Icons.edit_location_alt),
            iconSize: 32,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _bgText,
                      textAlign: TextAlign.center,
                    ),
                  GetBuilder<SavedTimesController>(
                    builder: (controller) => Container(
                      color: Colors.pinkAccent, // Adjust the color as desired
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: controller.savedTimes.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              controller.savedTimes[index],
                              style: TextStyle(color: Colors.blue), // Text color
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                    ElevatedButton(
                      onPressed: () {
                        scheduleNotification("Testing Noti on Click");
                      },
                      child: Text("Testing Noti"),
                    ),

                    ElevatedButton(onPressed: savedTimesController.saveCurrentTime, child: Text("Test save")),

                    Text(
                      _statusText,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 2,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Monitor even if killed',
                              ),
                              WidgetSpan(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: CupertinoSwitch(
                                    value: _isEnabledEvenIfKilled,
                                    onChanged: (value) {
                                      setState(() {
                                        _isEnabledEvenIfKilled = value;
                                      });
                                    },
                                  ),
                                ),
                                alignment: PlaceholderAlignment.middle,
                              )
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        child: FilledButton(
                          onPressed: () async {
                            final status = Platform.isIOS
                                ? await Permission.locationAlways.request()
                                : await Permission.location.request();
                            if (!status.isGranted) {
                              setState(() {
                                _bgText = 'Permission is not granted.';
                              });
                              return;
                            }
                            await BackgroundTask.instance.start(
                              isEnabledEvenIfKilled: _isEnabledEvenIfKilled,
                            );
                            setState(() {
                              _bgText = 'start';
                            });
                          },
                          child: const Text('Start'),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FilledButton(
                          onPressed: () async {
                            await BackgroundTask.instance.stop();
                            setState(() {
                              _bgText = 'stop';
                            });
                          },
                          child: const Text('Stop'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Builder(
                          builder: (context) {
                            return FilledButton(
                              onPressed: () async {
                                final isRunning =
                                await BackgroundTask.instance.isRunning;
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('isRunning: $isRunning'),
                                      action: SnackBarAction(
                                        label: 'close',
                                        onPressed: () {
                                          ScaffoldMessenger.of(context)
                                              .clearSnackBars();
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('isRunning'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}







Future<void> scheduleNotification(String input) async {
  //var time = Time(23, 50, 0);
  // var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //   'your_channel_id', // channel ID
  //   'Scheduled Notification', // channel name
  //  // 'Play sound at 11:50 PM', // channel description
  //   sound: RawResourceAndroidNotificationSound('noti.mp3'), // sound
  // );
  var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
    'you_can_name_it_whatever',
    'flutterfcm',
    playSound: true,
    sound: RawResourceAndroidNotificationSound('noti'),
    importance: Importance.max,
    priority: Priority.high,
  );

  // final DarwinInitializationSettings iOSPlatformChannelSpecifics =
  // DarwinInitializationSettings(
  //     requestSoundPermission: true,
  //     requestBadgePermission: true,
  //     requestAlertPermission: true,
  //     onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {});

  var darwinNotificationDetails = const DarwinNotificationDetails();
  var platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: darwinNotificationDetails,
  );
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    '$input',
    'at ${getCurrentTime()}',
    tzz.TZDateTime.now(tzz.local).add(const Duration(seconds: 5)),
    platformChannelSpecifics,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

Future<void> initializeNotifications() async {
  // Initialize the plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Android initialization
  final AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/launcher_icon');

  // iOS initialization
  final DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings();

  // Initialization settings for both platforms
  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

  // Initialize the plugin with the initialization settings
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

String getCurrentTime() {
  DateTime now = DateTime.now();
  String period = now.hour >= 12 ? 'PM' : 'AM';
  int hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  String minute = now.minute.toString().padLeft(2, '0');
  String second = now.second.toString().padLeft(2, '0');
  String month;
  switch (now.month) {
    case 1:
      month = 'January';
      break;
    case 2:
      month = 'February';
      break;
    case 3:
      month = 'March';
      break;
    case 4:
      month = 'April';
      break;
    case 5:
      month = 'May';
      break;
    case 6:
      month = 'June';
      break;
    case 7:
      month = 'July';
      break;
    case 8:
      month = 'August';
      break;
    case 9:
      month = 'September';
      break;
    case 10:
      month = 'October';
      break;
    case 11:
      month = 'November';
      break;
    case 12:
      month = 'December';
      break;
    default:
      month = '';
  }
  String day = now.day.toString();
  String year = now.year.toString();

  return '$hour:$minute:$second $period @ $month $day, $year';
}


class SavedTimesController extends GetxController {
  List<String> savedTimes = [];

  void loadSavedTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    savedTimes = prefs.getStringList('savedTimes') ?? [];
    update();
  }

  void saveCurrentTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime currentTime = DateTime.now();
    savedTimes.add(currentTime.toString());
    await prefs.setStringList('savedTimes', savedTimes);
    update();
  }
}

void requestLocationPermission() async {
  LocationPermission lp = await Geolocator.checkPermission();
  if(lp == LocationPermission.always){
    //initializeService();
  }else{
    await Geolocator.requestPermission();
    requestLocationPermission();
  }
}
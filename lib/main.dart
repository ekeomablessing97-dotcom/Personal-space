import 'package:flutter/material.dart';
import 'app.dart';
import 'services/app_state_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppStateController();
  await controller.initialize();
  runApp(PersonalSpaceApp(controller: controller));
}

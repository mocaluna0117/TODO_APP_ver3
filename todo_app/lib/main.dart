import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'app_settings.dart';
import 'settings_page.dart';
import 'notification_service.dart';

part 'models/todo_item.dart';
part 'app/my_app.dart';
part 'pages/todo_home_page.dart';
part 'pages/todo_home_data.dart';
part 'pages/todo_home_queries.dart';
part 'pages/todo_home_task_actions.dart';
part 'pages/todo_home_due_date_actions.dart';
part 'pages/todo_home_tag_actions.dart';
part 'pages/todo_home_export.dart';
part 'pages/todo_home_dialogs.dart';
part 'pages/todo_home_add_dialog_content.dart';
part 'pages/todo_home_task_dialogs.dart';
part 'pages/todo_home_task_tag_dialogs.dart';
part 'pages/todo_home_delete_dialogs.dart';
part 'pages/todo_home_move_dialogs.dart';
part 'pages/todo_home_move_to_todo_dialog.dart';
part 'pages/todo_home_move_to_future_dialog.dart';
part 'pages/todo_home_edit_dialog.dart';
part 'pages/todo_home_media.dart';
part 'pages/todo_home_form_fields.dart';
part 'pages/todo_home_settings.dart';
part 'pages/todo_home_list.dart';

const String allTaskCategoriesLabel = 'すべて';
const String noTaskTagLabel = 'タグなし';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // runappの前にFlutterの機能やプラグインを使うために必要
  runApp(const MyApp());
}

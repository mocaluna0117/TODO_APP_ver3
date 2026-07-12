import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'app_settings.dart';
import 'settings_page.dart';
import 'notification_service.dart';
import 'notification_offset.dart';
import 'firebase_options.dart';

part 'models/todo_item.dart';
part 'app/my_app.dart';
part 'app/auth_gate.dart';
part 'pages/sign_in/sign_in_page.dart';
part 'pages/todo_home/core/todo_home_page.dart';
part 'pages/todo_home/core/todo_home_data.dart';
part 'pages/todo_home/core/todo_home_queries.dart';
part 'pages/todo_home/core/todo_home_settings.dart';
part 'pages/todo_home/actions/todo_home_task_actions.dart';
part 'pages/todo_home/actions/todo_home_bulk_delete_actions.dart';
part 'pages/todo_home/actions/todo_home_tag_actions.dart';
part 'pages/todo_home/actions/todo_home_export.dart';
part 'pages/todo_home/actions/todo_home_import.dart';
part 'pages/todo_home/core/todo_home_app_bar_actions.dart';
part 'pages/todo_home/dialogs/todo_home_dialogs.dart';
part 'pages/todo_home/dialogs/add/todo_home_add_dialog_content.dart';
part 'pages/todo_home/dialogs/add/todo_home_add_dialog_draft.dart';
part 'pages/todo_home/dialogs/add/todo_home_add_dialog_fields.dart';
part 'pages/todo_home/dialogs/add/todo_home_add_dialog_text_fields.dart';
part 'pages/todo_home/dialogs/todo_home_task_dialogs.dart';
part 'pages/todo_home/dialogs/task_tag/todo_home_task_tag_dialogs.dart';
part 'pages/todo_home/dialogs/task_tag/todo_home_add_task_tag_dialog.dart';
part 'pages/todo_home/dialogs/task_tag/todo_home_task_tag_actions_sheet.dart';
part 'pages/todo_home/dialogs/task_tag/todo_home_rename_task_tag_dialog.dart';
part 'pages/todo_home/dialogs/task_tag/todo_home_delete_task_tag_dialog.dart';
part 'pages/todo_home/dialogs/todo_home_delete_dialogs.dart';
part 'pages/todo_home/dialogs/todo_home_bulk_delete_dialog.dart';
part 'pages/todo_home/dialogs/edit/todo_home_edit_dialog.dart';
part 'pages/todo_home/dialogs/edit/todo_home_edit_dialog_draft.dart';
part 'pages/todo_home/dialogs/edit/todo_home_edit_dialog_content.dart';
part 'pages/todo_home/dialogs/edit/todo_home_edit_dialog_fields.dart';
part 'pages/todo_home/dialogs/edit/todo_home_edit_dialog_text_fields.dart';
part 'pages/todo_home/media/todo_home_media.dart';
part 'pages/todo_home/form_fields/todo_home_form_fields.dart';
part 'pages/todo_home/form_fields/todo_home_date_picker_row.dart';
part 'pages/todo_home/form_fields/todo_home_time_picker_row.dart';
part 'pages/todo_home/form_fields/todo_home_due_time_picker.dart';
part 'pages/todo_home/form_fields/todo_home_image_picker_row.dart';
part 'pages/todo_home/form_fields/todo_home_links_field.dart';
part 'pages/todo_home/form_fields/todo_home_select_fields.dart';
part 'pages/todo_home/form_fields/todo_home_priority_picker.dart';
part 'pages/todo_home/form_fields/todo_home_notification_picker.dart';
part 'pages/todo_home/list/todo_home_list.dart';
part 'pages/todo_home/list/todo_home_todo_list.dart';
part 'pages/todo_home/list/todo_home_task_tag_filter.dart';
part 'pages/todo_home/list/todo_home_empty_list_message.dart';
part 'pages/todo_home/list/todo_home_todo_card.dart';
part 'pages/todo_home/list/todo_home_todo_card_actions.dart';
part 'pages/todo_home/dialogs/todo_home_restore_todo_dialog.dart';
part 'pages/todo_home/list/todo_home_todo_subtitle.dart';
part 'pages/todo_home/list/todo_home_task_labels.dart';

const String allTaskCategoriesLabel = 'すべて';
const String noTaskTagLabel = 'タグなし';

// 広い画面（PC等）でコンテンツを中央寄せする際の最大幅
const double kMaxContentWidth = 720;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // runappの前にFlutterの機能やプラグインを使うために必要
  // Firebaseの初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

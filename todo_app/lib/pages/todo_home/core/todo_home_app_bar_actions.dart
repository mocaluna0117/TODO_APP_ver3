part of '../../../main.dart';

extension _TodoHomeAppBarActions on _TodoHomePageState {
  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: _openSettings,
        tooltip: '設定',
      ),
    ];
  }
}

part of '../../../main.dart';

extension _TodoHomeSearch on _TodoHomePageState {
  // AppBar に出す検索欄。開いたらすぐ入力できるようにフォーカスを当てる。
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: Colors.white,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'タイトル・概要・タグを検索',
        hintStyle: TextStyle(color: Color(0xAAFFFFFF)),
        border: InputBorder.none,
        isDense: true,
      ),
      onChanged: (value) => _updateState(() => _searchQuery = value),
    );
  }

  // 検索の開始／終了。終了時は絞り込みも解除する。
  void _toggleSearch() {
    _updateState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  // 検索語に一致するか。タイトル・概要・タグ・リンクを対象にする。
  bool _matchesSearch(TodoItem item) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (item.title.toLowerCase().contains(query)) return true;
    final description = item.description;
    if (description != null && description.toLowerCase().contains(query)) {
      return true;
    }
    final tag = item.taskTag;
    if (tag != null && tag.toLowerCase().contains(query)) return true;
    return item.links.any((link) => link.toLowerCase().contains(query));
  }

  // いま見ているタブ以外に一致するタスクが何件あるか。
  // 「このタブには無いが他のタブにある」ことを伝えるために使う。
  int _searchMatchesInOtherTabs(String category) {
    var count = 0;
    for (final key in _activeTabKeys) {
      if (key == category) continue;
      count += _itemsByCategory(key).length;
    }
    return count;
  }
}

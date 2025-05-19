import 'package:flutter/material.dart';

/// SelectSinger 화면
/// - 가수 이름 검색
/// - 기존에 선택한 가수 리스트 다이얼로그
class SelectSingerScreen extends StatefulWidget {
  const SelectSingerScreen({Key? key}) : super(key: key);

  @override
  State<SelectSingerScreen> createState() => _SelectSingerScreenState();
}

class _SelectSingerScreenState extends State<SelectSingerScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 예시 데이터 (TODO: 반응형으로)
  final List<String> allSingers = [
    '아이유',
    '방탄소년단',
    '블랙핑크',
    '임영웅',
    '뉴진스',
    '세븐틴',
    '르세라핌',
  ];
  List<String> filteredSingers = [];
  List<String> selectedSingers = [];

  @override
  void initState() {
    super.initState();
    filteredSingers = List.from(allSingers);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      filteredSingers =
          allSingers
              .where((singer) => singer.contains(_searchController.text))
              .toList();
    });
  }

  void _onSingerTap(String singer) {
    setState(() {
      if (!selectedSingers.contains(singer)) {
        selectedSingers.add(singer);
      }
    });
    // TODO: 가수 선택 후 추가 동작
  }

  void _showSelectedSingersDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('기존에 선택한 가수'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children:
                    selectedSingers
                        .map(
                          (singer) => ListTile(
                            title: Text(singer),
                            onTap: () {
                              Navigator.pop(context);
                              _onSingerTap(singer);
                            },
                          ),
                        )
                        .toList(),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('닫기'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가수 선택'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: '기존에 선택한 가수 보기',
            onPressed: _showSelectedSingersDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '가수 이름 검색',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredSingers.length,
              itemBuilder: (context, index) {
                final singer = filteredSingers[index];
                return ListTile(
                  title: Text(singer),
                  trailing:
                      selectedSingers.contains(singer)
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                  onTap: () => _onSingerTap(singer),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

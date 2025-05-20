import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MealIngredientInputScreen extends StatefulWidget {
  final List<Map<String, String>>? initialIngredients;
  final void Function(List<Map<String, String>>) onNext;

  const MealIngredientInputScreen({
    Key? key,
    this.initialIngredients,
    required this.onNext,
  }) : super(key: key);

  @override
  State<MealIngredientInputScreen> createState() => _MealIngredientInputScreenState();
}

class _MealIngredientInputScreenState extends State<MealIngredientInputScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _ingredientList = [];
  String _ingredientInput = '';
  static const String _prefsKey = 'ingredient_list_v1';

  @override
  void initState() {
    super.initState();
    _loadIngredients();
    // initialIngredients가 있으면 SharedPreferences와 동기화
    if (widget.initialIngredients != null && widget.initialIngredients!.isNotEmpty) {
      _ingredientList = List<Map<String, String>>.from(widget.initialIngredients!);
      _saveIngredients();
    }
  }

  @override
  void dispose() {
    _saveIngredients();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final List list = jsonDecode(raw);
      setState(() {
        _ingredientList = list.map<Map<String, String>>((e) => Map<String, String>.from(e as Map)).toList();
      });
    }
  }

  Future<void> _saveIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_ingredientList));
  }

  void _addIngredient() {
    final name = _ingredientInput.trim();
    if (name.isEmpty || _ingredientList.any((e) => e['name'] == name)) return;
    setState(() {
      _ingredientList.add({'name': name});
      _ingredientInput = '';
      _controller.clear();
    });
    _saveIngredients();
  }

  void _removeIngredient(int idx) {
    setState(() {
      _ingredientList.removeAt(idx);
    });
    _saveIngredients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 완전 흰색 배경
      appBar: AppBar(
        title: const Text('식재료 입력'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '가지고 있는 식재료를 입력해 주세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '식재료를 입력하세요 (예: 토마토)',
                    ),
                    onChanged: (value) => setState(() => _ingredientInput = value),
                    onSubmitted: (_) => _addIngredient(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _ingredientInput.trim().isEmpty ? null : _addIngredient,
                  child: const Text('등록'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ingredientList.isEmpty
                  ? const Center(child: Text('아직 등록된 식재료가 없습니다.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: _ingredientList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final item = _ingredientList[idx];
                        return Card(
                          color: Colors.yellow[100],
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          margin: EdgeInsets.zero,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => _removeIngredient(idx),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _ingredientList.isNotEmpty
                    ? () async {
                        await _saveIngredients();
                        widget.onNext(_ingredientList);
                      }
                    : null,
                child: const Text('다음'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

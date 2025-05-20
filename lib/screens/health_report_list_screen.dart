import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'health_report_detail_screen_fixed.dart';

class HealthReportListScreen extends StatefulWidget {
  const HealthReportListScreen({Key? key}) : super(key: key);

  @override
  State<HealthReportListScreen> createState() => _HealthReportListScreenState();
}

class _HealthReportListScreenState extends State<HealthReportListScreen> {
  List<Map<String, dynamic>> _reportList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReportList();
  }

  // 보고서 목록 가져오기
  Future<void> _loadReportList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? reportListRaw = prefs.getString('health_report_list');
      
      if (reportListRaw != null && mounted) {
        final List<dynamic> reportData = json.decode(reportListRaw);
        setState(() {
          _reportList = reportData.map<Map<String, dynamic>>((item) => 
            Map<String, dynamic>.from(item)).toList();
          
          // 정렬: 최신 보고서가 맨 위로
          _reportList.sort((a, b) => 
            DateTime.parse(b['date'] as String).compareTo(DateTime.parse(a['date'] as String)));
        });
      }
    } catch (e) {
      print('보고서 목록 로딩 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보고서 목록을 불러오는 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 새 보고서 생성
  void _createNewReport() {
    Navigator.pushNamed(
      context,
      '/health-report-detail',
      arguments: '',
    ).then((_) => _loadReportList()); // 돌아왔을 때 목록 새로고침
  }
  
  // 보고서 삭제
  Future<void> _deleteReport(String reportId, int index) async {
    // 삭제 확인 다이얼로그
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('보고서 삭제'),
        content: const Text('이 건강 보고서를 삭제하시겠습니까?\n삭제한 보고서는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      // SharedPreferences에서 보고서 데이터 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('health_report_$reportId');
      
      // 보고서 목록에서 해당 보고서 제거
      setState(() {
        _reportList.removeAt(index);
      });
      
      // 업데이트된 목록 저장
      await prefs.setString('health_report_list', json.encode(_reportList));
      
      // 삭제 완료 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보고서가 삭제되었습니다.')),
        );
      }
    } catch (e) {
      print('보고서 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보고서 삭제 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '건강 보고서',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF3C4452),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'health_report_fab',
        onPressed: _createNewReport,
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assessment_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '건강 보고서가 없습니다',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '우측 하단의 + 버튼을 눌러 새 보고서를 생성하세요',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reportList.length,
                  itemBuilder: (context, index) {
                    final report = _reportList[index];
                    final reportDate = DateTime.parse(report['date'] as String);
                    final reportId = report['id'].toString();
                    
                    // 스와이프로 삭제 가능하게 설정
                    return Dismissible(
                      key: Key(reportId),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('보고서 삭제'),
                            content: const Text('이 건강 보고서를 삭제하시겠습니까?\n삭제한 보고서는 복구할 수 없습니다.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('삭제', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        _deleteReport(reportId, index);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        color: Colors.white, // 배경색 흰색으로 고정
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/health-report-detail',
                              arguments: reportId,
                            ).then((_) => _loadReportList()); // 돌아왔을 때 목록 새로고침
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.article, color: Colors.blue[700]),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        report['title'] as String? ?? '건강 보고서',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    // 삭제 버튼 추가
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                      onPressed: () => _deleteReport(reportId, index),
                                      tooltip: '보고서 삭제',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '생성일: ${reportDate.year}년 ${reportDate.month}월 ${reportDate.day}일',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios, 
                                      size: 16, color: Colors.grey[400]),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

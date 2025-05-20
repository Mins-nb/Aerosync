import 'package:flutter/material.dart';
import 'home_main_widget.dart';
import 'calendar_screen.dart';
import 'record_screen.dart';
import 'health_report_screen.dart';
import 'countdown_screen.dart';
import 'running_screen.dart';
import 'test_select_screen.dart';
import '../models/run_type.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    HomeMainWidget(),
    CalendarScreen(), // Calendar 탭
    RecordScreen(),
    HealthReportScreen(),
  ]; // 4개 탭으로 축소

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 0.0), // 더 아래로 내림
        child: SizedBox(
          width: 90, // 1.5배 크기
          height: 90,
          child: FloatingActionButton(
            heroTag: 'home_go_fab',
            backgroundColor: Colors.yellow.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 8,
            child: const Text('Go!', style: TextStyle(fontSize: 32, color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.yellow.shade600,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                          MaterialPageRoute(
                          builder: (context) => CountDownScreen(
                          onCountdownEnd: () {
                          try {
                          Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const RunningScreen()),
                          );
                          } catch (e) {
                          print('화면 전환 오류: $e');
                          // 오류 발생 시 안전하게 수동으로 이동
                          Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const RunningScreen()),
                          (route) => false,
                          );
                          }
                          },
                          ),
                          ),
                          );
                          },
                          child: const Text('Start running!',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CountDownScreen(
                                      onCountdownEnd: () {
                                        try {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(builder: (context) => RunningScreen(
                                              runGoal: RunGoal.testWalk1_6km(),
                                            )),
                                          );
                                        } catch (e) {
                                          print('화면 전환 오류: $e');
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(builder: (context) => RunningScreen(
                                              runGoal: RunGoal.testWalk1_6km(),
                                            )),
                                            (route) => false,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Walk 1.6km'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CountDownScreen(
                                      onCountdownEnd: () {
                                        try {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(builder: (context) => RunningScreen(
                                              runGoal: RunGoal.test1_5Mile(),
                                            )),
                                          );
                                        } catch (e) {
                                          print('화면 전환 오류: $e');
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(builder: (context) => RunningScreen(
                                              runGoal: RunGoal.test1_5Mile(),
                                            )),
                                            (route) => false,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Run 2.4km'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CountDownScreen(
                                      onCountdownEnd: () {
                                        try {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(builder: (context) => RunningScreen(
                                              runGoal: RunGoal.test5Min(),
                                            )),
                                          );
                                        } catch (e) {
                                          print('화면 전환 오류: $e');
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(builder: (context) => RunningScreen(
                                              runGoal: RunGoal.test5Min(),
                                            )),
                                            (route) => false,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Run 5 min'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CountDownScreen(
                                      onCountdownEnd: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (_) => const RunningScreen()),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Run 12 min'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home, color: _selectedIndex == 0 ? Colors.black : Colors.grey),
                      const SizedBox(height: 2),
                      Text('Home', style: TextStyle(fontSize: 12, color: _selectedIndex == 0 ? Colors.black : Colors.grey)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month, color: _selectedIndex == 1 ? Colors.black : Colors.grey),
                      const SizedBox(height: 2),
                      Text('Calendar', style: TextStyle(fontSize: 12, color: _selectedIndex == 1 ? Colors.black : Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 72), // 플로팅 버튼 영역 확보 (크기 키움)
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, color: _selectedIndex == 2 ? Colors.black : Colors.grey),
                      const SizedBox(height: 2),
                      Text('Record', style: TextStyle(fontSize: 12, color: _selectedIndex == 2 ? Colors.black : Colors.grey)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assessment, color: _selectedIndex == 3 ? Colors.black : Colors.grey),
                      const SizedBox(height: 2),
                      Text('Report', style: TextStyle(fontSize: 12, color: _selectedIndex == 3 ? Colors.black : Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

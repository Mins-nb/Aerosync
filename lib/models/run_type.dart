// 달리기 유형을 정의하는 enum
enum RunType {
  freeRun,         // 자유 달리기 (제한 없음)
  distance,        // 거리 기반 달리기 (예: 1.5마일)
  time,            // 시간 기반 달리기 (예: 5분, 12분)
  walk,            // 걷기 테스트 (예: 1마일 걷기)
}

// 달리기 목표 데이터를 담는 클래스
class RunGoal {
  final RunType type;
  final double? targetDistance; // 킬로미터 단위
  final Duration? targetDuration; // 시간 단위
  final String label; // 표시 이름 (예: "1.5 mile run")
  final bool isTest; // 테스트 여부

  RunGoal({
    required this.type,
    this.targetDistance,
    this.targetDuration,
    required this.label,
    this.isTest = false,
  });

  // 자유 달리기 생성 팩토리 메서드
  factory RunGoal.freeRun() {
    return RunGoal(
      type: RunType.freeRun,
      label: "Free Run",
    );
  }

  // 거리 기반 달리기 생성 팩토리 메서드
  factory RunGoal.distance(double distanceKm, String label, {bool isTest = false}) {
    return RunGoal(
      type: RunType.distance,
      targetDistance: distanceKm,
      label: label,
      isTest: isTest,
    );
  }

  // 시간 기반 달리기 생성 팩토리 메서드
  factory RunGoal.time(Duration duration, String label, {bool isTest = false}) {
    return RunGoal(
      type: RunType.time,
      targetDuration: duration,
      label: label,
      isTest: isTest,
    );
  }

  // 1.5마일(2.4km) 달리기 테스트 생성 편의 메서드
  factory RunGoal.test1_5Mile() {
    return RunGoal.distance(
      2.4, // 1.5마일 = 2.4km
      "Run 2.4km",
      isTest: true,
    );
  }

  // 5분 테스트 생성 편의 메서드
  factory RunGoal.test5Min() {
    return RunGoal.time(
      const Duration(minutes: 5),
      "5 Min Test",
      isTest: true,
    );
  }

  // 12분 테스트 생성 편의 메서드
  factory RunGoal.test12Min() {
    return RunGoal.time(
      const Duration(minutes: 12),
      "12 Min Test",
      isTest: true,
    );
  }
  
  // 1마일(1.6km) 걷기 테스트 생성 편의 메서드
  factory RunGoal.testWalk1_6km() {
    return RunGoal(
      type: RunType.walk,
      targetDistance: 1.6, // 1마일 걷기 (1.6km)
      label: "Walk 1.6km",
      isTest: true, // 테스트 여부
    );
  }

  // 목표 달성 확인 메서드
  bool isGoalReached({required double distance, required Duration duration}) {
    switch (type) {
      case RunType.freeRun:
        return false; // 자유 달리기는 자동 종료 없음
      case RunType.distance:
      case RunType.walk:
        return distance >= (targetDistance ?? 0);
      case RunType.time:
        return duration >= (targetDuration ?? Duration.zero);
    }
  }
  
  // VO2max 계산 메서드
  double calculateVO2max({required double distance, required Duration duration, double? heartRate, int? age, double? weight, int? gender}) {
    // 테스트가 아닌 경우 계산하지 않음
    if (!isTest) return 0;
    
    switch (type) {
      case RunType.distance:
        if (targetDistance != null && targetDistance! >= 2.4) { // 1.5마일 테스트
          // VO2max = 483 / 시간(분) + 3.5
          final min = duration.inSeconds / 60.0;
          if (min <= 0) return 0;
          return 483 / min + 3.5;
        }
        return 0;
        
      case RunType.time:
        if (targetDuration?.inMinutes == 5) { // 5분 테스트
          // VO2max = (달린 거리(m) / 5) * 0.2 + 3.5
          final distanceInMeters = distance * 1000;
          return (distanceInMeters / 5.0) * 0.2 + 3.5;
        } else if (targetDuration?.inMinutes == 12) { // 12분 테스트
          // VO2max = (달린 거리(m) - 504.9) / 44.73
          final distanceInMeters = distance * 1000;
          return (distanceInMeters - 504.9) / 44.73;
        }
        return 0;
        
      case RunType.walk:
        // 1마일 걷기 공식: 132.853 - (0.0769 * 체중(파운드)) - (0.3877 * 나이) + (6.315 * 성별) - (3.2649 * 소요시간(분)) - (0.1565 * 심박수)
        if (heartRate != null && age != null && weight != null && gender != null) {
          final weightLb = weight * 2.20462; // kg을 파운드로 변환
          final timeMin = duration.inSeconds / 60.0;
          return 132.853 - (0.0769 * weightLb) - (0.3877 * age) + (6.315 * gender) - (3.2649 * timeMin) - (0.1565 * heartRate);
        }
        return 0;
        
      default:
        return 0;
    }
  }
  
  // VO2max 기반 체력 레벨 내역 가져오기
  String getVO2maxLevel(double vo2max) {
    if (vo2max <= 0) return '-';
    if (vo2max < 30) return '체력 수준: 낮음';
    if (vo2max < 40) return '체력 수준: 보통';
    if (vo2max < 50) return '체력 수준: 양호';
    return '체력 수준: 우수';
  }
}

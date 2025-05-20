# Aerosync
### 냉장고를 열면 운동이 시작된다 : AI Healthcare coach

## 프로젝트 소개
Aerosync는 운동과 식이 관리를 위한 올인원 건강 관리 애플리케이션입니다. 사용자의 일상 활동을 추적하고, 개인화된 건강 보고서와 식단 추천을 제공합니다.

## 주요 기능
- **운동 추적**: 달리기, 걷기 등 다양한 운동 활동을 기록하고 분석
- **BMI 계산**: 사용자의 신체 데이터를 기반으로 건강 상태 분석
- **캘린더 기능**: 운동 및 식단 스케줄 관리
- **식단 관리**: AI 기반 식단 추천 및 칼로리 추적
- **건강 보고서**: 종합적인 건강 상태 분석 제공

## 기술 스택
- **Frontend**: Flutter
- **Backend**: FastAPI, Python
- **Database**: SQLite, Hive
- **AI/ML**: OpenAI GPT-4 Turbo, Llama Index

## 설치 방법

### 요구 사항
- Flutter 3.16.0 이상
- Python 3.9 이상
- OpenAI API 키

### 프론트엔드 설치
```bash
# 리포지토리 클론
git clone https://github.com/Mins-nb/aerosync.git
cd aerosync

# 의존성 설치
flutter pub get

# 환경 설정
# .env.example 파일을 .env로 복사하고 API 키 추가
cp .env.example .env
# .env 파일 편집하여 API 키 추가

# 앱 실행
flutter run
```

### 백엔드 설치
```bash
# 백엔드 디렉토리로 이동
cd meal_backend

# 가상 환경 생성 및 활성화
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 의존성 설치
pip install -r requirements.txt

# 환경 설정
# .env.example 파일을 .env로 복사하고 API 키 추가
cp .env.example .env
# .env 파일 편집하여 API 키 추가

# 서버 실행
python backend_main.py
```

## 프로젝트 구조
```
aerosync/
├── lib/               # Flutter 앱 소스 코드
│   ├── core/          # 핵심 기능 (테마, 라우팅 등)
│   ├── models/        # 데이터 모델
│   ├── screens/       # UI 화면
│   ├── services/      # 비즈니스 로직 및 API 통신
│   ├── utils/         # 유틸리티 함수
│   └── widgets/       # 재사용 가능한 위젯
├── meal_backend/      # 백엔드 서버 코드
│   ├── storage/       # 인덱스 저장소
│   └── venv/          # Python 가상 환경
└── assets/            # 앱 에셋 (이미지 등)
```

## 라이센스
이 프로젝트는 MIT 라이센스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 기여 방법
1. 이 레포지토리를 포크합니다.
2. 새 기능 브랜치를 생성합니다: `git checkout -b feature/amazing-feature`
3. 변경 사항을 커밋합니다: `git commit -m 'Add some amazing feature'`
4. 브랜치에 푸시합니다: `git push origin feature/amazing-feature`
5. Pull Request를 제출합니다.

## 팀원
- 양건우 (@github.com/AI-rephyx)
- 강민성 (@github.com/Mins-nb)
- 백승호 (@github.com/snow-white2024)

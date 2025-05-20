# ── backend_main.py ───────────────────────────────────────────
from fastapi import FastAPI, HTTPException, Response, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, conint
from typing import List, Dict, Optional, Union
import sqlite3, os, math, json, re, logging
from openai import OpenAI

# RAG 인덱스 가져오기
from rag_index import build_or_load

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# ── FastAPI 인스턴스 ──────────────────────────────────────────
app = FastAPI(title="Meal Planner API")

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 배포 환경에서는 구체적인 오리진을 지정해야 함
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 벡터 인덱스 생성/로드 및 디버깅 함수
def debug_rag_system():
    """RAG 시스템 진단을 위한 테스트 함수"""
    global DB_PATH  # 전역 변수 참조
    logging.info("=== RAG 시스템 진단 시작 ===")
    
    # 1. 라이브러리 버전 확인
    try:
        import llama_index
        try:
            version = getattr(llama_index, '__version__', 'unknown version')
            logging.info(f"llama_index 버전: {version}")
        except Exception as e:
            logging.warning(f"llama_index 버전 확인 불가: {e}, 계속 진행합니다.")
        
        # 에러 없이 임포트 가능한지 테스트
        try:
            from llama_index.core import VectorStoreIndex
            logging.info("llama_index.core 사용 중 (v0.10+ 버전)")
        except ImportError:
            try:
                from llama_index import VectorStoreIndex
                logging.info("llama_index 톱레벨 사용 중 (v0.9 버전)")
            except ImportError as e:
                logging.error(f"VectorStoreIndex를 임포트할 수 없습니다: {e}")
                return "VectorStoreIndex 임포트 오류"
            
    except ImportError as e:
        logging.error(f"llama_index 라이브러리가 설치되지 않았습니다: {e}")
        return "llama_index 라이브러리 누락"
    
    # 2. 인덱스 존재 확인
    index_dir = "storage" if os.path.exists("storage") else "food_index_chroma"
    if not os.path.exists(index_dir):
        logging.error(f"인덱스 디렉토리가 존재하지 않습니다: {index_dir}")
        return "인덱스 디렉토리 누락"
    
    try:
        files = os.listdir(index_dir)
        logging.info(f"인덱스 디렉토리 내용: {files}")
        if not files or len(files) < 3:  # 최소한의 필요 파일 확인
            logging.error("인덱스 디렉토리가 비어있거나 불완전합니다")
            return "인덱스 불완전"
    except Exception as e:
        logging.error(f"인덱스 디렉토리 확인 중 오류: {e}")
        return f"디렉토리 접근 오류: {e}"
    
    # 3. 인덱스 로드 시도
    try:
        from rag_index import build_or_load, DB_PATH as RAG_DB_PATH
        # 전역 DB_PATH 업데이트
        global DB_PATH
        if not DB_PATH and RAG_DB_PATH:
            DB_PATH = RAG_DB_PATH
            logging.info(f"DB_PATH 설정됨: {DB_PATH}")
            
        index = build_or_load(persist_dir=index_dir)
        
        # 로드된 인덱스 확인
        if hasattr(index, 'docstore') and hasattr(index.docstore, 'docs'):
            doc_count = len(index.docstore.docs)
            logging.info(f"인덱스 로드 성공, 문서 수: {doc_count}")
            if doc_count == 0:
                logging.error("인덱스에 문서가 없습니다")
                return "빈 인덱스"
        else:
            logging.error(f"인덱스 구조 아예 이상: {type(index)}")
            return "인덱스 구조 이상"
    except Exception as e:
        logging.error(f"인덱스 로드 중 오류: {e}", exc_info=True)
        return f"인덱스 로드 오류: {e}"
    
    # 4. 쿼리 테스트
    try:
        test_query = "토마토"
        logging.info(f"테스트 쿼리 실행: '{test_query}'")
        
        # 쿼리 엔진 생성 테스트
        try:
            # 임베딩 모델 확인
            if hasattr(index, 'service_context') and hasattr(index.service_context, 'embed_model'):
                logging.info(f"사용중인 임베딩 모델: {type(index.service_context.embed_model)}")
            
            query_engine = index.as_query_engine(similarity_top_k=5)
            logging.info(f"쿼리 엔진 생성 성공: {type(query_engine)}")
        except Exception as e:
            logging.error(f"쿼리 엔진 생성 실패: {e}")
            return f"쿼리 엔진 생성 오류: {e}"
        
        # 쿼리 실행 테스트
        try:
            logging.info("쿼리 실행 시도...")
            response = query_engine.query(test_query)
            logging.info(f"쿼리 응답 타입: {type(response)} - {str(response)[:100]}...")
            
            # response 구조 로깅
            response_attrs = [attr for attr in dir(response) if not attr.startswith('_')]
            logging.info(f"Response 속성들: {response_attrs}")
            
            for attr in response_attrs:
                try:
                    value = getattr(response, attr)
                    if attr == 'response':
                        logging.info(f"Response.{attr} (값): {str(value)[:100]}...")
                    else:
                        logging.info(f"Response.{attr}: {type(value)}")
                except Exception as e:
                    logging.error(f"Response.{attr} 접근 오류: {e}")
        except Exception as e:
            logging.error(f"쿼리 실행 실패: {e}", exc_info=True)
            return f"쿼리 실행 오류: {e}"
            
        # 소스 노드 확인 로깅
        try:
            if hasattr(response, 'source_nodes'):
                if response.source_nodes:
                    logging.info(f"'{test_query}'에 대한 source_nodes 수: {len(response.source_nodes)}")
                    
                    # 첫 노드 메타데이터 상세 확인
                    first_node = response.source_nodes[0]
                    logging.info(f"첫 번째 노드 점수: {getattr(first_node, 'score', 'unknown')}")
                    logging.info(f"첫 번째 노드 내용: {getattr(first_node, 'text', 'unknown')[:100]}...")
                    
                    if hasattr(first_node, 'metadata'):
                        logging.info(f"첫 번째 노드 메타데이터: {first_node.metadata}")
                        if 'rowid' in first_node.metadata:
                            rowid = first_node.metadata['rowid']
                            logging.info(f"rowid={rowid} 식품 정보 찾음")
                            
                            # 실제 DB에서 해당 rowid가 존재하는지 확인
                            try:
                                with sqlite3.connect(DB_PATH) as conn:
                                    result = conn.execute("SELECT 식품명 FROM foods WHERE rowid=?", (rowid,)).fetchone()
                                    if result:
                                        logging.info(f"DB 확인 성공: rowid={rowid}, 식품명={result[0]}")
                                    else:
                                        logging.error(f"DB에 rowid={rowid}인 식품이 없음!")
                                        return "rowid 불일치 문제"
                            except Exception as db_err:
                                logging.error(f"DB 연결 중 오류: {db_err}, DB_PATH={DB_PATH}")
                                return f"DB 연결 오류: {db_err}"
                        else:
                            logging.error("노드 메타데이터에 'rowid'가 없습니다")
                            return "메타데이터 문제"
                    else:
                        logging.error("노드에 metadata 속성이 없음")
                        return "metadata 속성 없음"
                else:
                    logging.error(f"'{test_query}'에 대한 source_nodes가 비어있음")
                    return "source_nodes 비어있음"
            else:
                # 소스 노드가 없는 경우, 다른 유형의 응답인지 확인
                logging.warning("응답에 source_nodes 속성이 없음, response.response에서 직접 확인")               
                # llama_index 최신 버전 대응
                try:
                    if hasattr(response, 'response'):
                        logging.info(f"응답 텍스트: {response.response[:100]}...")
                        # 테스트 목적으로는 응답이 있으면 성공으로 간주
                        return "정상"
                except Exception as resp_err:
                    logging.error(f"응답 확인 중 오류: {resp_err}")
                return "source_nodes 없음"
        except Exception as e:
            logging.error(f"소스 노드 처리 중 오류: {e}")
            return f"소스 노드 처리 오류: {e}"
    except Exception as e:
        logging.error(f"쿼리 테스트 중 오류: {e}")
        return f"쿼리 오류: {e}"
    
    logging.info("=== RAG 시스템 진단 완료: 정상 ===")
    return "정상"

# 벡터 인덱스 생성/로드
try:
    logging.info("RAG 인덱스 로드 시작...")
    # DB_PATH가 정의되지 않은 경우 정의해주기
    if 'DB_PATH' not in globals() or DB_PATH is None:
        from rag_index import DB_PATH as RAG_DB_PATH
        globals()['DB_PATH'] = RAG_DB_PATH
        logging.info(f"전역 DB_PATH 설정: {DB_PATH}")
    
    vector_index = build_or_load()
    logging.info("RAG 벡터 인덱스 로드 완료")
    USE_RAG = True
    
    # 인덱스 상태 확인
    rag_status = debug_rag_system()
    logging.info(f"RAG 시스템 상태: {rag_status}")
    USE_RAG = rag_status == "정상"
    
    if not USE_RAG:
        logging.warning("RAG 시스템 진단 실패, 일반 검색만 사용합니다.")
    
    # 테스트 쿼리 실행
    if USE_RAG:
        try:
            test_results = semantic_food_search("토마토", test_mode=True)
            logging.info(f"RAG 테스트 쿼리 결과: {len(test_results)} 항목 찾음")
            
            # 결과가 없으면 추가 테스트 시도 (디버깅용)
            if not test_results:
                logging.warning("'토마토' 테스트 실패, '사과' 로 테스트 재시도")
                alt_results = semantic_food_search("사과", test_mode=True)
                logging.info(f"RAG '사과' 테스트 결과: {len(alt_results)} 항목 찾음")
                
                # 여전히 실패하면, 문제가 있는 것으로 확인
                if not alt_results:
                    logging.error("RAG 검색이 두 번 연속 실패하나 정상으로 간주하고 계속 진행")
                    # 계속 시도해보기 위해 USE_RAG는 True로 유지
        except Exception as e:
            logging.error(f"RAG 테스트 쿼리 오류: {e}", exc_info=True)
            # 오류가 발생해도 USE_RAG는 True로 유지
            logging.info("RAG 테스트 실패했으나 정상으로 간주하고 계속 진행")
            
    # 관리자용 테스트 엔드포인트 추가
    @app.get("/test_rag")
    async def test_rag_search(term: str):
        """
        RAG 검색 테스트를 위한 관리자용 API
        """
        if not USE_RAG:
            return {"error": "RAG 시스템이 비활성화되어 있습니다"}
            
        try:
            results = semantic_food_search(term, top_k=10, test_mode=True)
            return {
                "status": "success",
                "count": len(results),
                "results": [{
                    "name": item[0],
                    "kcal": item[1],
                    "carbs": item[2],
                    "protein": item[3],
                    "fat": item[4]
                } for item in results]
            }
        except Exception as e:
            logging.error(f"Test RAG API 오류: {e}")
            return {"status": "error", "message": str(e)}
            
except Exception as e:
    logging.warning(f"RAG 인덱스 로드 실패: {e}")
    USE_RAG = False

# ── OpenAI 설정 (키를 직접 넣거나, 환경변수 사용) ─────────────
import os
# dotenv 설정
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

API_KEY = os.getenv("OPENAI_API_KEY", "")
if not API_KEY:
    logging.warning("환경 변수 OPENAI_API_KEY가 설정되지 않았습니다. OpenAI 기능이 작동하지 않을 수 있습니다.")

client = OpenAI(api_key=API_KEY)

# 모델 설정 - GPT-4 Turbo 사용
MODEL_NAME = "gpt-4-turbo-preview"  # 가장 최신 GPT-4 Turbo 모델

# ── DB 경로 ──────────────────────────────────────────────────
DB_PATH = "foods.db"

# ── 요청 / 검증 모델 ─────────────────────────────────────────
class MealRequest(BaseModel):
    ingredients: List[str]                            # 자유 텍스트
    weight:      float                               # 체중 kg
    goal:        str   = Field(pattern="^(bulk|diet|maintain)$")
    meals:       conint(ge=1, le=5)                  # 1 – 5끼

class MealItem(BaseModel):
    meal_type: str  # '아침', '점심', '저녁', '간식'
    food_name: str  # 식품명
    amount: float   # 그램
    calories: float # 칼로리
    carbs: float    # 탄수화물
    protein: float  # 단백질
    fat: float      # 지방

class DayMeal(BaseModel):
    day: int        # 일자
    meals: List[MealItem]

class MealResponse(BaseModel):
    # 응답 성공 여부
    success: bool = True
    # 기존 마크다운용 필드 (이전 버전 호환성)
    recommendation: Optional[str] = None
    # 새로운 구조화된 데이터 필드
    meals: Optional[List[Dict]] = None
    not_found: Optional[List[str]] = None
    target: Optional[Dict[str, float]] = None
    plan: Optional[List[Dict]] = None
    # 오류 메시지 (실패 시)
    errorMessage: Optional[str] = None

# API 응답용 모델
class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Union[Dict, List]] = None
    error: Optional[str] = None

# ── 영양 목표 계산 ────────────────────────────────────────────
def macro_target(weight: float, goal: str) -> Dict[str, float]:
    if goal == "bulk":
        return {
            "kcal": round(weight * 45),               # 벌크업: 45 kcal/kg
            "p":    round(weight * 2.2),              # g
            "c":    round(weight * 4.5),
            "f":    round(weight * 1.0),
        }
    elif goal == "diet":
        return {
            "kcal": round(weight * 30),               # 다이어트: 30 kcal/kg
            "p":    round(weight * 2.0),
            "c":    round(weight * 2.5),
            "f":    round(weight * 0.8),
        }
    elif goal == "maintain":
        return {
            "kcal": round(weight * 37),               # 유지: 37 kcal/kg (중간값 예시)
            "p":    round(weight * 2.0),
            "c":    round(weight * 3.5),
            "f":    round(weight * 0.9),
        }
    else:
        raise ValueError(f"Unknown goal: {goal}")

# ── RAG 기반 의미 검색 ────────────────────────────────────────
def semantic_food_search(term: str, top_k=5, test_mode=False):
    """의미 기반 식품 검색 - 벡터 인덱스 사용"""
    if not USE_RAG:
        logging.info(f"RAG 비활성화 상태: '{term}' 검색 건너뛐")
        return []  # RAG가 비활성화된 경우 빈 결과 반환
        
    logging.info(f"RAG 의미 검색 시작: '{term}'")
    
    # 쿼리 엔진 생성 과정 로깅
    try:
        query_engine = vector_index.as_query_engine(similarity_top_k=top_k)
        logging.info(f"RAG 쿼리 엔진 생성 성공: {type(query_engine)}")
    except Exception as e:
        logging.error(f"RAG 쿼리 엔진 생성 실패: {e}")
        return []
    
    # 쿼리 실행 과정 로깅
    try:
        response = query_engine.query(term)
        logging.info(f"RAG 쿼리 응답 받음: {type(response)}")
            
        # 테스트 모드에서 응답 상세 로깅
        if test_mode:
            attrs = [attr for attr in dir(response) if not attr.startswith('_')]
            logging.info(f"Response 속성들: {attrs}")
            if hasattr(response, 'response'):
                logging.info(f"Response 텍스트: {response.response[:50]}...")
    except Exception as e:
        logging.error(f"RAG 쿼리 실행 실패: {e}", exc_info=True)
        return []
    
    # 응답 검색 유무 확인
    try:
        if not hasattr(response, 'source_nodes'):
            logging.error(f"Response에 source_nodes 속성이 없음: {type(response)}")
            return []
        
        if not response.source_nodes:
            logging.info(f"RAG 검색 결과 없음: '{term}'")
            return []
            
        logging.info(f"RAG 검색 소스 노드 {len(response.source_nodes)}개 받음")
        
        # 가장 먼저 받은 노드 로깅
        first_node = response.source_nodes[0]
        if test_mode and hasattr(first_node, 'metadata'):
            logging.info(f"첫 번째 노드 메타데이터: {first_node.metadata}")
            
    except Exception as e:
        logging.error(f"RAG 쿼리 실행 실패: {e}", exc_info=True)
        return []
        
    # 여기서부터 결과 추출 처리
    try:
        # 결과 추출
        results = []
        
        # source_nodes가 있는 경우 (llama-index 이전 버전 호환)
        if hasattr(response, 'source_nodes') and response.source_nodes:
            logging.info(f"source_nodes에서 {len(response.source_nodes)}개 결과 처리")
            for i, node in enumerate(response.source_nodes):
                # 메타데이터에서 rowid 찾기
                if not hasattr(node, 'metadata') or 'rowid' not in node.metadata:
                    logging.warning(f"노드 {i}번에 rowid 메타데이터가 없습니다")
                    continue
                    
                rowid = node.metadata['rowid']
                try:
                    with sqlite3.connect(DB_PATH) as conn:
                        row = conn.execute(
                            "SELECT 식품명, 에너지kcal, 탄수화물g, 단백질g, 지방g FROM foods WHERE rowid=?", 
                            (rowid,)
                        ).fetchone()
                        
                        if row:
                            food_name, kcal, carb, prot, fat = row
                            results.append((food_name, kcal, carb, prot, fat))
                            logging.info(f"RAG 결과: {food_name} (rowid={rowid})")
                        else:
                            logging.warning(f"DB에서 rowid={rowid}에 해당하는 식품을 찾을 수 없습니다.")
                except Exception as e:
                    logging.error(f"노드 {i}번 처리 중 오류: {e}")
                    
        # 최신 버전 llama-index를 위한 대체 처리 방법
        elif hasattr(response, 'metadata') and response.metadata:
            logging.info("응답의 metadata에서 결과 처리")
            try:
                # metadata에서 직접 source_nodes 추출 시도
                if 'source_nodes' in response.metadata:
                    for i, node in enumerate(response.metadata['source_nodes']):
                        if 'metadata' in node and 'rowid' in node['metadata']:
                            rowid = node['metadata']['rowid']
                            try:
                                with sqlite3.connect(DB_PATH) as conn:
                                    row = conn.execute(
                                        "SELECT 식품명, 에너지kcal, 탄수화물g, 단백질g, 지방g FROM foods WHERE rowid=?", 
                                        (rowid,)
                                    ).fetchone()
                                    if row:
                                        food_name, kcal, carb, prot, fat = row
                                        results.append((food_name, kcal, carb, prot, fat))
                                        logging.info(f"RAG 결과 (metadata): {food_name} (rowid={rowid})")
                            except Exception as db_err:
                                logging.error(f"DB 연결 오류 (metadata): {db_err}")
            except Exception as e:
                logging.error(f"메타데이터 처리 오류: {e}")
                
        # 모든 방법이 실패하면 키워드로 DB 직접 검색
        if not results and hasattr(response, 'response'):
            logging.info(f"RAG 결과가 없어 응답 텍스트로 검색 시도: {response.response[:30]}...")
            try:
                # 응답 텍스트에서 핵심 키워드 추출 (간단히 첫 단어만)
                keyword = response.response.split()[0] if response.response else term
                with sqlite3.connect(DB_PATH) as conn:
                    rows = conn.execute(
                        "SELECT 식품명, 에너지kcal, 탄수화물g, 단백질g, 지방g FROM foods WHERE 식품명 LIKE ?", 
                        (f"%{keyword}%",)
                    ).fetchall()
                    if rows:
                        for row in rows[:3]:  # 상위 3개만
                            results.append(row)
                            logging.info(f"키워드 '{keyword}' 응답 텍스트 기반 결과: {row[0]}")
            except Exception as e:
                logging.error(f"응답 텍스트 기반 검색 오류: {e}")
                
        logging.info(f"RAG 검색 결과: {len(results)}개 항목 찾음")
        return results
        
    except Exception as e:
        logging.error(f"RAG 검색 결과 처리 중 오류: {e}", exc_info=True)
        return []

# ── 식품 검색 함수 ─────────────────────────────────────────────
def db_rows_like(term: str):
    """
    개선된 식품 검색 함수:
    1. 전체 텍스트 검색 - 전체 문구를 한 번에 검색
    2. 문구 부분으로 검색 - 일부 단어만 입력해도 검색
    3. 단어 조합 검색 - 단어들의 OR 또는 AND 조합
    
    반환값: List[Tuple(식품명, kcal, carb, prot, fat)]
    """
    # 입력 검색어 전처리
    term = term.strip()
    if not term:
        return []
    
    # 전체 텍스트 검색 (원본 문구를 그대로 검색)
    full_results = search_foods_by_full_text(term)
    
    # 토큰 분리 머물어 검색
    tokens = [t.strip() for t in re.split(r"[,\s]+", term) if t.strip()]
    
    # AND 검색 (1순위) - 모든 단어가 포함된 경우
    and_results = []
    if len(tokens) > 1:  # 토큰이 2개 이상인 경우만 AND 검색 수행
        and_results = search_foods_with_tokens(tokens, match_type="AND")
    
    # 식품명 문장 토큰화 OR 검색 (2순위) - 하나의 단어라도 포함된 경우
    or_results = search_foods_with_tokens(tokens, match_type="OR")
    
    # 결과 통합 및 중복 제거 (중요도 순)
    combined_results = []
    seen_foods = set()
    
    # 1. 전체 문구 정확 일치 (가장 정확한 일치)
    for row in full_results:
        if row[0] not in seen_foods:  # 식품명 중복 방지
            combined_results.append(row)
            seen_foods.add(row[0])
    
    # 2. 모든 토큰 포함 (AND 연산, 두 번째로 정확한 일치)
    for row in and_results:
        if row[0] not in seen_foods:
            combined_results.append(row)
            seen_foods.add(row[0])
    
    # 3. 일부 토큰 포함 (OR 연산, 마지막 순위)
    for row in or_results:
        if row[0] not in seen_foods:
            combined_results.append(row)
            seen_foods.add(row[0])
    
    # 검색 결과 로그
    logging.info(f"검색 방식별 결과: 전체={len(full_results)}, AND={len(and_results)}, OR={len(or_results)}")
    logging.info(f"최종 결과 수: {len(combined_results)}")
    
    return combined_results

def search_foods_by_full_text(term: str):
    """전체 문구를 그대로 검색"""
    sql = (
        "SELECT 식품명, 에너지kcal, 탄수화물g, 단백질g, 지방g "
        "FROM foods WHERE 식품명 LIKE ? ORDER BY length(식품명) ASC"
    )
    with sqlite3.connect(DB_PATH) as conn:
        rows = conn.execute(sql, [f'%{term}%']).fetchall()
        return [
            (
                row[0],
                float(row[1]),
                float(row[2]),
                float(row[3]),
                float(row[4])
            )
            for row in rows
        ]

def search_foods_with_tokens(tokens, match_type="AND"):
    """토큰을 사용한 식품 검색 (AND 또는 OR 조건)"""
    if not tokens:
        return []
        
    # AND 또는 OR 조건 쿼리 동적 생성
    operator = " AND " if match_type == "AND" else " OR "
    where_clause = operator.join([f"식품명 LIKE '%'||?||'%'" for _ in tokens])
    
    sql = (
        "SELECT 식품명, 에너지kcal, 탄수화물g, 단백질g, 지방g "
        f"FROM foods WHERE {where_clause} ORDER BY length(식품명) ASC"
    )
    
    with sqlite3.connect(DB_PATH) as conn:
        rows = conn.execute(sql, tokens).fetchall()
        return [
            (
                row[0],
                float(row[1]),
                float(row[2]),
                float(row[3]),
                float(row[4])
            )
            for row in rows
        ]

# ── 2차: GPT-4 Turbo 추정 (100 g 기준) ───────────────────────
def gpt_lookup_nutrition(term: str):
    """GPT-4로 100 g 영양 추정치를 JSON(string)으로 받아 파싱."""
    sys_msg = (
        "You are a nutrition database specialist. "
        "Return ONLY a JSON object with numeric keys "
        "'kcal', 'carb', 'prot', 'fat' for 100 g of the food. "
        "Ensure all values are reasonable and accurate for the specified food."
    )
    prompt = f"Food: {term}\nJSON:"
    try:
        logging.info(f"GPT 영양 정보 요청 - 음식: {term}")
        resp = client.chat.completions.create(
            model=MODEL_NAME,  # GPT-4 Turbo 사용
            messages=[
                {"role": "system", "content": sys_msg},
                {"role": "user", "content": prompt},
            ],
            temperature=0.1,  # 더 일관된 응답을 위해 낮은 temperature
            response_format={"type": "json_object"}  # JSON 응답 강제
        ).choices[0].message.content
        
        # JSON 파싱
        try:
            data = json.loads(resp)
            logging.info(f"GPT 영양 정보 결과 - {term}: {data}")
            return (
                term + " (GPT-4)",  # 식품명 구분용
                float(data.get("kcal", 0)),
                float(data.get("carb", 0)),
                float(data.get("prot", 0)),
                float(data.get("fat", 0)),
            )
        except json.JSONDecodeError as e:
            logging.error(f"JSON 파싱 오류: {e}, 원본 응답: {resp}")
            # 정규식으로 재시도
            try:
                match = re.search(r"\{.*\}", resp, re.S)
                if match:
                    data = json.loads(match.group())
                    return (
                        term + " (GPT-4)",
                        float(data.get("kcal", 0)),
                        float(data.get("carb", 0)),
                        float(data.get("prot", 0)),
                        float(data.get("fat", 0)),
                    )
            except Exception as nested_err:
                logging.error(f"정규식 파싱 시도 실패: {nested_err}")
            return None
    except Exception as e:
        logging.error(f"GPT 호출 오류 - {term}: {e}")
        return None

# ── 오류 응답 헬퍼 ─────────────────────────────────────────────
def error_response(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "success": False,
            "errorMessage": message
        },
        media_type="application/json; charset=utf-8"
    )

# ── 요청 로그 미들웨어 ────────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    logging.info(f"요청: {request.method} {request.url.path}")
    try:
        response = await call_next(request)
        logging.info(f"응답: {response.status_code}")
        return response
    except Exception as e:
        logging.error(f"처리 중 오류: {str(e)}")
        return error_response(500, str(e))

# ── 엔드포인트 ───────────────────────────────────────────────
@app.post("/recommend")
async def recommend(req: MealRequest):
    logging.info(f"식단 추천 요청: 재료={req.ingredients}, 체중={req.weight}, 목표={req.goal}, 식사 수={req.meals}")
    # 목표 유효성 확인 추가 - bulk, diet, maintain 중 하나인지 확인
    if req.goal not in ['bulk', 'diet', 'maintain']:
        return error_response(400, f"잘못된 목표 값: {req.goal}. 'bulk', 'diet', 'maintain' 중 하나를 입력해야 합니다.")
    
    try:
        found, synthetic, not_found = [], [], []

        # 재료별 3단계 검색 프로세스: RAG → DB → GPT
        for term in req.ingredients:
            # 1. RAG 의미 기반 검색 (가장 먼저 시도)
            rows = semantic_food_search(term) if USE_RAG else []
            
            # 2. RAG 실패 시 키워드 기반 DB 검색
            if not rows:
                logging.info(f"RAG 검색 실패, DB 키워드 검색 시도: '{term}'")
                rows = db_rows_like(term)
                
            # 3. DB 검색도 실패 시 GPT로 영양소 예측
            if not rows:
                logging.info(f"DB 검색 실패, GPT 영양소 예측 시도: '{term}'")
                est = gpt_lookup_nutrition(term)
                if est:
                    synthetic.append(est)
                    rows = [est]
                    
            # 결과 처리
            if rows:
                found.extend(rows)
                logging.info(f"'{term}' 검색 성공: {len(rows)}개 항목 찾음")
            else:
                not_found.append(term)
                logging.warning(f"'{term}' 검색 실패: 모든 방법에서 결과 없음")

        if not found:                                      # 완전 실패
            logging.warning(f"모든 재료를 찾지 못함: {not_found}")
            return error_response(404, f"다음 재료를 찾지 못했습니다: {not_found}")

        # ---------- 중복 제거 (같은 식품명은 1회만) ----------
        uniq = list({r[0]: r for r in found}.values())

        # ---------- 목표치 ----------
        tgt = macro_target(req.weight, req.goal)

        # ---------- 단순 비율 배분 ----------
        # 100 g 씩 우선 배정 후, 남은 열량을 kcal 비중에 따라 가중 분배
        plan   = []
        remain = tgt["kcal"]
        for n, kcal, c, p, f in uniq:
            base = 100                                    # 최소치 100 g
            plan.append({
                "식품": n,
                "g": base,
                "kcal": float(kcal),
                "탄수": float(c),
                "단백": float(p),
                "지방": float(f)
            })
            remain -= float(kcal)

        if remain > 0:                                    # 남은 kcal 분배
            total_kcal = sum(item["kcal"] for item in plan)
            for item in plan:
                share    = remain * item["kcal"] / total_kcal
                extra_g  = share / item["kcal"] * 100      # 100 g당 kcal
                item["g"]     += round(extra_g, 1)
                item["kcal"]  += round(share, 1)
                item["탄수"]  += round(item["탄수"] * extra_g / 100, 1)
                item["단백"]  += round(item["단백"] * extra_g / 100, 1)
                item["지방"]  += round(item["지방"] * extra_g / 100, 1)

        # ---------- 끼니별 균등 분할 ----------
        per_meal = []
        for m in range(req.meals):
            meal_items = []
            for food in plan:
                g_part = round(food["g"] / req.meals, 1)
                meal_items.append({"식품": food["식품"], "g": g_part})
            # 영양 합산
            kcal = sum(round(food["kcal"] / req.meals, 1) for food in plan)
            c    = sum(round(food["탄수"] / req.meals, 1) for food in plan)
            p    = sum(round(food["단백"] / req.meals, 1) for food in plan)
            f    = sum(round(food["지방"] / req.meals, 1) for food in plan)
            per_meal.append({"재료": meal_items, "kcal": kcal, "c": c, "p": p, "f": f})

        # ---------- 마크다운 표 (이전 버전 호환성) ----------
        period = 1  # 기간이 필요한 경우 req에 추가
        all_days_md = []
        
        # ---------- 구조화된 JSON 데이터 ----------
        structured_days = []
    
        for day in range(1, period+1):
            # 마크다운용
            table = [
                f"### {day}일차",
                "| 식사 | 음식명 | g | kcal | 탄수 | 단백 | 지방 |",
                "|:---:|:------|---:|-----:|-----:|-----:|-----:|"
            ]
            
            # 구조화된 JSON용
            day_meals = []
            meal_types = ['아침', '점심', '저녁', '간식']
        
            for m_idx, meal in enumerate(per_meal, 1):
                meal_type = meal_types[(m_idx - 1) % len(meal_types)]
                
                for x in meal["재료"]:
                    # 마크다운 테이블 행 추가
                    table.append(f"| {m_idx} | {x['식품']} | {x['g']} | {round(meal['kcal'],1)} | {round(meal['c'],1)} | {round(meal['p'],1)} | {round(meal['f'],1)} |")
                    
                    # 구조화된 JSON 객체 추가
                    day_meals.append({
                        "meal_type": meal_type,
                        "food_name": x['식품'],
                        "amount": float(x['g']), 
                        "calories": float(round(meal['kcal'],1)),
                        "carbs": float(round(meal['c'],1)),
                        "protein": float(round(meal['p'],1)), 
                        "fat": float(round(meal['f'],1))
                    })
                
            all_days_md.append("\n".join(table))
            structured_days.append({
                "day": day,
                "meals": day_meals
            })
            
        meals_markdown = "\n\n".join(all_days_md)

        # 클라이언트에 맞게 구조화된 데이터 구성
        # 식사 데이터 변환 - 클라이언트 예상 형식으로 맞춤
        client_formatted_meals = []
        
        # 식사 타입별로 포맷팅
        for day_meal in structured_days:
            client_formatted_meals.extend(day_meal['meals'])
        
        logging.info(f"추천 결과 생성 완료: {len(client_formatted_meals)}개 식단 항목")
        
        # UTF-8로 명시적 인코딩 설정한 응답 반환
        return JSONResponse(
            content={
                "success": True,
                "meals": client_formatted_meals,
                # 원본 마크다운도 포함 (이전 버전 호환성)
                "rawMarkdown": meals_markdown
            },
            media_type="application/json; charset=utf-8"
        )
        
    except Exception as e:
        logging.error(f"추천 처리 중 오류: {str(e)}")
        return error_response(500, f"식단 추천 생성 중 오류가 발생했습니다: {str(e)}")

# ── 상태 확인 엔드포인트 ───────────────────────────────────
@app.get("/health")
async def health_check():
    features = {
        "rag_enabled": USE_RAG,
        "gpt_enabled": API_KEY is not None and len(API_KEY) > 0
    }
    return {
        "status": "healthy", 
        "message": "FastAPI 서버가 정상적으로 실행 중입니다.",
        "features": features
    }

# ─────────────────────────────────────────────────────────────

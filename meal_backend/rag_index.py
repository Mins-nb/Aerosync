# ─── 1) llama‑index 버전별 import 자동 처리 ──────────────────────────────────
import os

# OpenAI API 키 설정
# dotenv 설정
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

# OpenAI API 키 설정
api_key = os.getenv("OPENAI_API_KEY", "")
if api_key:
    os.environ["OPENAI_API_KEY"] = api_key
else:
    print("\u26a0️ 경고: OPENAI_API_KEY가 설정되지 않았습니다. OpenAI 기능이 작동하지 않을 수 있습니다.")

try:               # v0.12 (core 하위 모듈)
    from llama_index.core import (
        VectorStoreIndex,
        Document,
        StorageContext,
        load_index_from_storage,
        Settings,
    )
    from llama_index.embeddings.openai import OpenAIEmbedding
except ImportError:          # v0.10 (top‑level)
    from llama_index import (
        VectorStoreIndex,
        Document,
        StorageContext,
        load_index_from_storage,
        Settings,
    )
    from llama_index.embeddings.openai import OpenAIEmbedding

import sqlite3
import pandas as pd

# ─── 2) 공용 상수 ────────────────────────────────────────────────────────
DB_PATH      = "foods.db"
PERSIST_DIR  = "storage"

# ─── 3) 공용 진입 함수 ────────────────────────────────────────────────────
def build_or_load(
    db_path: str = DB_PATH,
    persist_dir: str = PERSIST_DIR,
) -> "VectorStoreIndex":
    """
    Returns
    -------
    VectorStoreIndex
        • snapshot 폴더가 있으면 → 로드  
        • 없으면 → DB → 문서 → 인덱스 생성 후 snapshot 저장
    """

    # ① 이미 스냅샷이 존재 → 로드
    if os.path.exists(persist_dir):
        print(f"🗂️  Loading vector index from  '{persist_dir}'")
        storage_ctx = StorageContext.from_defaults(persist_dir=persist_dir)
        return load_index_from_storage(storage_ctx)

    # ② 새로 빌드
    print("🔨  Building vector index from foods.db …")
    with sqlite3.connect(db_path) as conn:
        df = pd.read_sql(
            "SELECT rowid, 식품명, 에너지kcal, 탄수화물g, 단백질g, 지방g FROM foods",
            conn,
        )

    # OpenAI 임베딩 모델 설정
    try:
        # OpenAI 임베딩 사용 - text-embedding-ada-002
        embed_model = OpenAIEmbedding(model="text-embedding-ada-002")
        print("🔥 OpenAI 임베딩 사용 (text-embedding-ada-002)")
    except Exception as e:
        print(f"Error: OpenAI 임베딩 모델 로드 실패: {e}")
        raise  # 임베딩 모델이 중요하기 때문에 오류 발생시 중단
    
    # 전역 임베딩 설정 적용
    try:
        # v0.10+ 버전 호환
        Settings.embed_model = embed_model
        print("✅ OpenAI 임베딩 모델 적용 성공 (Settings API)")
    except Exception as e:
        # 예전 버전 호환성
        print(f"Warning: Settings API 사용 실패: {e}")
     
    docs = [
        Document(
            text=(
                f"{row.식품명} (100 g) → "
                f"{row.에너지kcal} kcal | C {row.탄수화물g} g | "
                f"P {row.단백질g} g | F {row.지방g} g"
            ),
            metadata={
                "rowid": int(row.rowid),   # fast SQLite lookup
                "식품명": row.식품명,
            },
        )
        for row in df.itertuples()
    ]

    # OpenAI 임베딩 모델을 사용하여 인덱스 생성
    print(f"📚 문서 {len(docs)}개로 인덱스 생성 중 (OpenAI 임베딩 사용)...")
    try:
        # v0.10+ 버전 호환
        index = VectorStoreIndex.from_documents(
            docs, 
            embed_model=embed_model
        )
    except TypeError:
        # 이전 버전 호환성
        index = VectorStoreIndex.from_documents(docs)
        
    index.storage_context.persist(persist_dir=persist_dir)
    print(f"✅  Saved vector snapshot → '{persist_dir}'  ({len(df)} docs)")
    return index
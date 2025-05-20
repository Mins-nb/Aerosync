import pandas as pd, sqlite3, pathlib

DB_PATH = pathlib.Path("foods.db")
EXCEL    = pathlib.Path("Food_DB.xlsx")

df = pd.read_excel(EXCEL, engine="openpyxl")

# 필요한 열만 미리 얇게 만들어 두면 추후 속도 ↑
keep_cols = ["식품명", "식품군", "에너지kcal", "탄수화물g", "단백질g", "지방g"]
df = df[keep_cols]

with sqlite3.connect(DB_PATH) as conn:
    df.to_sql("foods", conn, if_exists="replace", index=False)

print("✅ foods.db 작성 완료, 행 수:", len(df))
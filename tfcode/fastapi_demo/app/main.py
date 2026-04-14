import os
from fastapi import FastAPI
import psycopg
from psycopg.rows import dict_row


DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")


app = FastAPI(
    name="FastAPI ECS Demo",
    description="A simple FastAPI application to demonstrate connectivity with PostgreSQL on ECS",
    version="1.0.0",
)


@app.get("/")
def root():
    return {"message": "helloooooooo from ecs"}

@app.get("/healthz")
def healthz():
    return {"status": "ok"}


def get_conn():
    missing = [k for k, v in {
        "DB_HOST": DB_HOST,
        "DB_NAME": DB_NAME,
        "DB_USER": DB_USER,
        "DB_PASSWORD": DB_PASSWORD,
    }.items() if not v]
    # crash early if any required environment variables are missing
    # add validation so the error message is clear about which variables are missing 
    # and why the app can't start without them 
    if missing:
        raise RuntimeError(f"Missing required environment variables: {', '.join(missing)}")

    return psycopg.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        row_factory=dict_row,
    )


@app.get("/db-check")
def db_check():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT now() AS now, current_database() AS db;")
            row = cur.fetchone()
            return {
                "connected": True,
                "database": row["db"],
                "time": str(row["now"]),
            }

@app.on_event("startup")
def startup():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS visits (
                    id SERIAL PRIMARY KEY,
                    created_at TIMESTAMPTZ DEFAULT now()
                );
            """)
            conn.commit()

@app.post("/visit")
def create_visit():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO visits DEFAULT VALUES RETURNING id, created_at;")
            row = cur.fetchone()
            conn.commit()
            return row

@app.get("/visits")
def list_visits():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, created_at FROM visits ORDER BY id DESC LIMIT 20;")
            rows = cur.fetchall()
            return rows

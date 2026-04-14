import os
import uuid
import mimetypes
import logging
from contextlib import asynccontextmanager

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.responses import JSONResponse
import psycopg
from psycopg.rows import dict_row


logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)


# --------------------------------------------------
# Environment
# --------------------------------------------------
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

S3_BUCKET = os.getenv("S3_BUCKET")
AWS_REGION = os.getenv("AWS_REGION", "eu-central-1")
S3_PREFIX = os.getenv("S3_PREFIX", "uploads")
PRESIGNED_URL_EXPIRES = int(os.getenv("PRESIGNED_URL_EXPIRES", "900"))  # 15 min
MAX_UPLOAD_SIZE = int(os.getenv("MAX_UPLOAD_SIZE", str(20 * 1024 * 1024)))  # 20 MB


def validate_required_env() -> None:
    required = {
        "DB_HOST": DB_HOST,
        "DB_NAME": DB_NAME,
        "DB_USER": DB_USER,
        "DB_PASSWORD": DB_PASSWORD,
        "S3_BUCKET": S3_BUCKET,
    }
    missing = [name for name, value in required.items() if not value]

    if missing:
        raise RuntimeError(
            "Application startup failed because required environment variables are missing: "
            f"{', '.join(missing)}. "
            "These values are required for PostgreSQL and S3 connectivity."
        )


# --------------------------------------------------
# App lifecycle
# --------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    validate_required_env()
    init_db()
    logger.info("Application started successfully")
    yield
    logger.info("Application shutting down")


app = FastAPI(
    title="FastAPI EKS Demo",
    description="FastAPI app using PostgreSQL and S3 on EKS",
    version="2.0.0",
    lifespan=lifespan,
)


# --------------------------------------------------
# Helpers
# --------------------------------------------------
def get_conn():
    return psycopg.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        row_factory=dict_row,
    )


def get_s3_client():
    # On EKS, boto3 can pick up pod credentials from IRSA automatically.
    return boto3.client("s3", region_name=AWS_REGION)


def init_db() -> None:
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS visits (
                    id SERIAL PRIMARY KEY,
                    created_at TIMESTAMPTZ DEFAULT now()
                );
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS files (
                    id BIGSERIAL PRIMARY KEY,
                    original_filename TEXT NOT NULL,
                    s3_key TEXT NOT NULL UNIQUE,
                    content_type TEXT,
                    size_bytes BIGINT NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                    deleted_at TIMESTAMPTZ
                );
                """
            )
            cur.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_files_created_at
                ON files (created_at DESC);
                """
            )
            cur.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_files_not_deleted
                ON files (deleted_at)
                WHERE deleted_at IS NULL;
                """
            )
            conn.commit()


def sanitize_filename(filename: str) -> str:
    # Keep only the basename to avoid path traversal-like input.
    return os.path.basename(filename).strip() or "file.bin"


def build_s3_key(filename: str) -> str:
    safe_name = sanitize_filename(filename)
    key = uuid.uuid4().hex[:8] + "-" + safe_name
    return f"{S3_PREFIX.rstrip('/')}/{key}"


def infer_content_type(filename: str, declared_content_type: str | None) -> str:
    if declared_content_type:
        return declared_content_type
    guessed, _ = mimetypes.guess_type(filename)
    return guessed or "application/octet-stream"


def upload_to_s3(file_obj, bucket: str, key: str, content_type: str) -> None:
    s3 = get_s3_client()
    s3.upload_fileobj(
        Fileobj=file_obj,
        Bucket=bucket,
        Key=key,
        ExtraArgs={"ContentType": content_type},
    )


def generate_download_url(bucket: str, key: str, expires_in: int) -> str:
    s3 = get_s3_client()
    return s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=expires_in,
    )


def head_bucket() -> None:
    s3 = get_s3_client()
    s3.head_bucket(Bucket=S3_BUCKET)


def delete_object(bucket: str, key: str) -> None:
    s3 = get_s3_client()
    s3.delete_object(Bucket=bucket, Key=key)


def get_file_record(file_id: int):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, original_filename, s3_key, content_type, size_bytes, created_at, deleted_at
                FROM files
                WHERE id = %s;
                """,
                (file_id,),
            )
            return cur.fetchone()


# --------------------------------------------------
# Error handling
# --------------------------------------------------
@app.exception_handler(RuntimeError)
def runtime_error_handler(_, exc: RuntimeError):
    logger.exception("Runtime error")
    return JSONResponse(status_code=500, content={"detail": str(exc)})


# --------------------------------------------------
# Basic routes
# --------------------------------------------------
@app.get("/")
def root():
    return {"message": "hello from eks"}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


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


@app.get("/s3-check")
def s3_check():
    try:
        head_bucket()
        return {
            "connected": True,
            "bucket": S3_BUCKET,
            "region": AWS_REGION,
        }
    except (ClientError, BotoCoreError) as exc:
        logger.exception("S3 check failed")
        raise HTTPException(status_code=500, detail=f"S3 check failed: {exc}")


# --------------------------------------------------
# Visit routes
# --------------------------------------------------
@app.post("/visit")
def create_visit():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO visits DEFAULT VALUES RETURNING id, created_at;"
            )
            row = cur.fetchone()
            conn.commit()
            return row


@app.get("/visits")
def list_visits():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, created_at FROM visits ORDER BY id DESC LIMIT 20;"
            )
            return cur.fetchall()


# --------------------------------------------------
# File routes
# --------------------------------------------------
@app.post("/upload")
def upload_file(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="Uploaded file must have a filename.")

    safe_name = sanitize_filename(file.filename)
    content_type = infer_content_type(safe_name, file.content_type)
    s3_key = build_s3_key(safe_name)

    try:
        # Measure file size without loading the whole thing into memory.
        file.file.seek(0, os.SEEK_END)
        size_bytes = file.file.tell()
        file.file.seek(0)

        if size_bytes <= 0:
            raise HTTPException(status_code=400, detail="Uploaded file is empty.")

        if size_bytes > MAX_UPLOAD_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"File too large. Max upload size is {MAX_UPLOAD_SIZE} bytes.",
            )

        upload_to_s3(file.file, S3_BUCKET, s3_key, content_type)

        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO files (original_filename, s3_key, content_type, size_bytes)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id, original_filename, s3_key, content_type, size_bytes, created_at;
                    """,
                    (safe_name, s3_key, content_type, size_bytes),
                )
                row = cur.fetchone()
                conn.commit()

        return {
            "uploaded": True,
            "file": row,
            "s3_uri": f"s3://{S3_BUCKET}/{s3_key}",
        }

    except HTTPException:
        raise
    except (ClientError, BotoCoreError) as exc:
        logger.exception("S3 upload failed")
        raise HTTPException(status_code=500, detail=f"S3 upload failed: {exc}")
    except Exception as exc:
        logger.exception("Unexpected upload failure")
        raise HTTPException(status_code=500, detail=f"Upload failed: {exc}")
    finally:
        file.file.close()


@app.get("/files")
def list_files(limit: int = Query(default=20, ge=1, le=100)):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, original_filename, s3_key, content_type, size_bytes, created_at
                FROM files
                WHERE deleted_at IS NULL
                ORDER BY id DESC
                LIMIT %s;
                """,
                (limit,),
            )
            return cur.fetchall()


@app.get("/files/{file_id}")
def get_file(file_id: int):
    row = get_file_record(file_id)
    if not row or row["deleted_at"] is not None:
        raise HTTPException(status_code=404, detail="File not found.")
    return row


@app.get("/files/{file_id}/download-url")
def get_download_url(
    file_id: int,
    expires_in: int = Query(default=PRESIGNED_URL_EXPIRES, ge=60, le=3600),
):
    row = get_file_record(file_id)
    if not row or row["deleted_at"] is not None:
        raise HTTPException(status_code=404, detail="File not found.")

    try:
        url = generate_download_url(S3_BUCKET, row["s3_key"], expires_in)
        return {
            "file_id": row["id"],
            "filename": row["original_filename"],
            "expires_in": expires_in,
            "download_url": url,
        }
    except (ClientError, BotoCoreError) as exc:
        logger.exception("Failed to create presigned URL")
        raise HTTPException(status_code=500, detail=f"Failed to create download URL: {exc}")


@app.delete("/files/{file_id}")
def delete_file(file_id: int, hard_delete: bool = Query(default=False)):
    row = get_file_record(file_id)
    if not row or row["deleted_at"] is not None:
        raise HTTPException(status_code=404, detail="File not found.")

    try:
        if hard_delete:
            delete_object(S3_BUCKET, row["s3_key"])

        with get_conn() as conn:
            with conn.cursor() as cur:
                if hard_delete:
                    cur.execute("DELETE FROM files WHERE id = %s;", (file_id,))
                else:
                    cur.execute(
                        """
                        UPDATE files
                        SET deleted_at = now()
                        WHERE id = %s
                        RETURNING id, deleted_at;
                        """,
                        (file_id,),
                    )
                result = cur.fetchone()
                conn.commit()

        return {
            "deleted": True,
            "hard_delete": hard_delete,
            "result": result,
        }

    except (ClientError, BotoCoreError) as exc:
        logger.exception("Failed to delete from S3")
        raise HTTPException(status_code=500, detail=f"Failed to delete file: {exc}")

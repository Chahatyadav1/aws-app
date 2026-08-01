import os
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "appdb")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "postgres")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_size=5, max_overflow=10)


def init_db():
    """Create the tasks table if it does not already exist."""
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS tasks (
                id SERIAL PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                is_done BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """))


@app.route("/api/health", methods=["GET"])
def health():
    """Health check used by the ALB target group."""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return jsonify({"status": "healthy", "database": "connected"}), 200
    except OperationalError as e:
        logger.error(f"DB health check failed: {e}")
        return jsonify({"status": "unhealthy", "database": "disconnected"}), 503


@app.route("/api/tasks", methods=["GET"])
def get_tasks():
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT id, title, is_done, created_at FROM tasks ORDER BY id DESC")).fetchall()
    tasks = [
        {"id": r[0], "title": r[1], "is_done": r[2], "created_at": r[3].isoformat() if r[3] else None}
        for r in rows
    ]
    return jsonify(tasks), 200


@app.route("/api/tasks", methods=["POST"])
def create_task():
    data = request.get_json(force=True)
    title = (data or {}).get("title", "").strip()
    if not title:
        return jsonify({"error": "title is required"}), 400
    with engine.begin() as conn:
        result = conn.execute(
            text("INSERT INTO tasks (title) VALUES (:title) RETURNING id"),
            {"title": title},
        )
        new_id = result.scalar()
    return jsonify({"id": new_id, "title": title, "is_done": False}), 201


@app.route("/api/tasks/<int:task_id>", methods=["PATCH"])
def update_task(task_id):
    data = request.get_json(force=True) or {}
    is_done = bool(data.get("is_done", False))
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE tasks SET is_done = :is_done WHERE id = :id"),
            {"is_done": is_done, "id": task_id},
        )
    return jsonify({"id": task_id, "is_done": is_done}), 200


@app.route("/api/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM tasks WHERE id = :id"), {"id": task_id})
    return "", 204


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

import React, { useEffect, useState, useCallback } from "react";

// Same-origin call: the ALB routes /api/* to the backend ECS service
// and everything else to the frontend ECS service, so no base URL is needed.
const API_BASE = "/api";

function App() {
  const [tasks, setTasks] = useState([]);
  const [title, setTitle] = useState("");
  const [health, setHealth] = useState(null);
  const [error, setError] = useState(null);

  const fetchTasks = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/tasks`);
      if (!res.ok) throw new Error("Failed to load tasks");
      setTasks(await res.json());
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);

  const fetchHealth = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/health`);
      const data = await res.json();
      setHealth(res.ok ? "ok" : "fail");
    } catch {
      setHealth("fail");
    }
  }, []);

  useEffect(() => {
    fetchTasks();
    fetchHealth();
  }, [fetchTasks, fetchHealth]);

  const addTask = async (e) => {
    e.preventDefault();
    if (!title.trim()) return;
    await fetch(`${API_BASE}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title }),
    });
    setTitle("");
    fetchTasks();
  };

  const toggleTask = async (task) => {
    await fetch(`${API_BASE}/tasks/${task.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ is_done: !task.is_done }),
    });
    fetchTasks();
  };

  const deleteTask = async (id) => {
    await fetch(`${API_BASE}/tasks/${id}`, { method: "DELETE" });
    fetchTasks();
  };

  return (
    <div className="container">
      <h1>Three-Tier Task App</h1>
      <p className="subtitle">
        React (ECS Fargate) → Flask API (ECS Fargate) → PostgreSQL (RDS)
        {health && (
          <span className={`status-badge ${health === "ok" ? "status-ok" : "status-fail"}`}>
            API: {health === "ok" ? "connected" : "unreachable"}
          </span>
        )}
      </p>

      <div className="card">
        <form onSubmit={addTask}>
          <input
            type="text"
            placeholder="Add a new task..."
            value={title}
            onChange={(e) => setTitle(e.target.value)}
          />
          <button type="submit">Add</button>
        </form>
      </div>

      <div className="card">
        {error && <p style={{ color: "#f87171" }}>{error}</p>}
        <ul>
          {tasks.map((t) => (
            <li key={t.id}>
              <span
                className={`task-title ${t.is_done ? "done" : ""}`}
                onClick={() => toggleTask(t)}
                style={{ cursor: "pointer" }}
              >
                {t.title}
              </span>
              <button className="delete-btn" onClick={() => deleteTask(t.id)}>✕</button>
            </li>
          ))}
          {tasks.length === 0 && !error && <p style={{ color: "#64748b" }}>No tasks yet.</p>}
        </ul>
      </div>
    </div>
  );
}

export default App;

CREATE TABLE IF NOT EXISTS publish_jobs (
 request_id TEXT PRIMARY KEY,
 skill TEXT NOT NULL,
 version TEXT NOT NULL,
 digest TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('publishing','published','failed')),
 created_at TEXT NOT NULL,
 receipt_json TEXT,
 error_code TEXT,
 UNIQUE(skill,version)
);

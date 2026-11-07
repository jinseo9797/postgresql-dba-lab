-- STEP 7: 세션 및 잠금 상태 점검
-- 현재 세션 상태별 건수 조회 (자기 세션 제외)
SELECT state, COUNT(*) AS sessions
FROM pg_stat_activity
WHERE datname = current_database() AND pid <> pg_backend_pid()
GROUP BY state ORDER BY sessions DESC;

-- 장기 미종료 트랜잭션 조회 (1분 초과)
-- idle in transaction 상태 지속 시간 확인
SELECT pid, usename, application_name, now()-xact_start AS transaction_age,
       wait_event_type, wait_event
FROM pg_stat_activity
WHERE datname=current_database()
  AND state='idle in transaction'
  AND xact_start < now() - interval '1 minute'
ORDER BY xact_start;

-- 잠금 대기 중인 쿼리 조회
-- 차단 세션 PID 확인
SELECT pid, usename, state, wait_event_type, wait_event,
       pg_blocking_pids(pid) AS blocking_pids,
       left(query, 160) AS query_preview
FROM pg_stat_activity
WHERE datname=current_database()
  AND cardinality(pg_blocking_pids(pid)) > 0;

"""PostgreSQL 세션·장기 트랜잭션·잠금 대기 점검."""
import os
import sys
import argparse

import psycopg


def main() -> int:
    """DB 접속 및 세션 상태 점검."""
    parser = argparse.ArgumentParser(description="PostgreSQL 세션 상태 점검")
    parser.add_argument("--idle-seconds", type=int, default=60,
                        help="idle in transaction 경고 기준(초, 기본 60)")
    args = parser.parse_args()
    if args.idle_seconds < 0:
        parser.error("--idle-seconds는 0 이상이어야 합니다.")

    # 비밀번호 환경변수에서 조회
    password = os.getenv("DB_PASSWORD")
    if not password:
        print("[ERROR] DB_PASSWORD 환경변수를 먼저 설정하세요.", file=sys.stderr)
        return 2

    try:
        # 점검 후 DB 연결 자동 정리
        with psycopg.connect(
            host=os.getenv("DB_HOST", "127.0.0.1"),
            port=int(os.getenv("DB_PORT", "5433")),
            dbname=os.getenv("DB_NAME", "dba_lab"),
            user=os.getenv("DB_USER", "dba_admin"),
            password=password,
            connect_timeout=5,
            application_name="dba_health_check",
            autocommit=True,
        ) as conn:
            with conn.cursor() as cur:
                # 세션 상태별 건수 집계
                cur.execute("""
                    SELECT count(*) FILTER (WHERE state = 'active') AS active,
                           count(*) FILTER (WHERE state = 'idle') AS idle,
                           count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_tx,
                           count(*) FILTER (WHERE cardinality(pg_blocking_pids(pid)) > 0) AS blocked
                    FROM pg_stat_activity
                    WHERE datname = current_database() AND pid <> pg_backend_pid()
                """)
                active, idle, idle_in_tx, blocked = cur.fetchone()
                print("=== PostgreSQL Health Check ===")
                print(f"Active: {active} | Idle: {idle} | Idle in transaction: {idle_in_tx} | Blocked: {blocked}")

                # 장기 idle in transaction 세션 조회
                cur.execute("""
                    SELECT pid, usename, now()-xact_start AS tx_age,
                           wait_event_type, wait_event
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND pid <> pg_backend_pid()
                      AND state = 'idle in transaction'
                      AND xact_start < now() - make_interval(secs => %s)
                    ORDER BY xact_start LIMIT 20
                """, (args.idle_seconds,))
                rows = cur.fetchall()
                if rows:
                    print(f"[WARN] {args.idle_seconds}초 초과 idle in transaction: {len(rows)}건 (최대 20건 출력)")
                    for pid, user, age, wait_type, event in rows:
                        print(f"  PID={pid} USER={user} TX_AGE={age} WAIT={wait_type}/{event}")
                else:
                    print(f"[OK] {args.idle_seconds}초 초과 idle in transaction 없음")

                # 잠금 대기 세션 확인
                cur.execute("""
                    SELECT pid, usename, pg_blocking_pids(pid)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND cardinality(pg_blocking_pids(pid)) > 0
                    ORDER BY pid LIMIT 20
                """)
                waiting = cur.fetchall()
                if waiting:
                    print(f"[WARN] Lock 대기 세션 {len(waiting)}건 (최대 20건 출력)")
                    for pid, user, blockers in waiting:
                        print(f"  WAITING PID={pid}, USER={user}, BLOCKED BY={blockers}")
                else:
                    print("[OK] Lock 대기 세션 없음")
        return 0
    # DB 접속 오류 처리
    except (psycopg.Error, ValueError) as exc:
        print(f"[ERROR] DB 상태 확인 실패: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

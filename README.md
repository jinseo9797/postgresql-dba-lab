# PostgreSQL DBA Lab

> **PostgreSQL 데이터 설계·트랜잭션·JOIN 성능 비교·상태 점검 실습**

PostgreSQL 16 환경에서 데이터 제약조건, 트랜잭션 롤백, 인덱스 튜닝, 장기 트랜잭션 점검을 실습한 개인 프로젝트입니다. 이커머스 예제 및 가상 데이터를 사용했습니다.

## 주요 결과

| 항목 | 실습 결과 |
|---|---|
| 데이터 무결성 | PK·FK·UNIQUE·CHECK 적용 및 오류 테스트 |
| 트랜잭션 | 잘못된 주문 입력 후 ROLLBACK 검증 |
| JOIN 성능 분석 | 가상 데이터 311,000건 사용 |
| 인덱스 적용 전후 | 단회 측정 17.621ms → 1.111ms |
| 상태 점검 | 약 3분 유지된 장기 트랜잭션 1건 감지 |

> 실행 시간은 로컬 실습의 측정값입니다. 다른 환경에서 같은 결과가 보장되지는 않습니다.

## 상세 실습 보고서

| 보고서 | 주요 내용 |
|---|---|
| [01. 데이터베이스 설계](docs/01_database_design.md) | 테이블 관계 및 제약조건 검증 |
| [02. 트랜잭션 및 롤백](docs/02_transaction.md) | 오류 발생 후 변경 취소 확인 |
| [03. JOIN·인덱스 비교](docs/03_index_tuning.md) | 실행 계획, 측정값 및 한계 |
| [04. PostgreSQL 상태 점검](docs/04_health_check.md) | 세션 및 장기 트랜잭션 확인 |
| [성능 측정 원자료](docs/performance_results.md) | 5회 반복 측정값과 상세 분석 |

## 사용 기술

**PostgreSQL 16** · Docker · pgAdmin · SQL · Python 3 · psycopg 3

성능 확인: `EXPLAIN (ANALYZE, BUFFERS)`  
상태 확인: `pg_stat_activity`, `pg_blocking_pids()`

## 프로젝트 구성

```text
postgresql-dba-lab/
├── README.md
├── docs/
│   ├── 01_database_design.md
│   ├── 02_transaction.md
│   ├── 03_index_tuning.md
│   ├── 04_health_check.md
│   ├── performance_results.md
│   └── screenshots/          # 실행 결과 3장
├── sql/                      # 설계·트랜잭션·튜닝·검증 SQL
├── db_health_check.py        # DB 상태 점검
├── requirements.txt
├── .env.example
└── .gitignore
```

## 실습 환경 및 실행 순서

- 데이터베이스: `dba_lab`
- 스키마: `ecommerce`, `ecommerce_bench`
- 로컬 연결 예시: `127.0.0.1:5433`

새로운 PostgreSQL 16 실습 DB를 준비한 뒤 아래 순서로 진행합니다.

1. [01_schema.sql](sql/01_schema.sql) → [02_seed_data.sql](sql/02_seed_data.sql) 실행
2. [03_transaction_test.sql](sql/03_transaction_test.sql)로 롤백 확인
3. [03b_failed_order_test.sql](sql/03b_failed_order_test.sql)에서 오류 INSERT와 ROLLBACK을 **단계별 실행**
4. [04_benchmark_schema.sql](sql/04_benchmark_schema.sql) → [05_benchmark_data.sql](sql/05_benchmark_data.sql) 실행
5. [08_benchmark_query.sql](sql/08_benchmark_query.sql)로 인덱스 적용 전 측정
6. [06_index_optimization.sql](sql/06_index_optimization.sql)로 인덱스 생성 후 동일 조회 재측정
7. [09_validation.sql](sql/09_validation.sql)로 데이터 건수 및 관계 확인

`03b_failed_order_test.sql`에서 오류 코드 `23514`가 발생하는 것은 의도한 결과입니다. 오류 후 `ROLLBACK`을 실행해야 합니다. 벤치마크 데이터 생성 SQL은 기존 데이터가 있을 때 중단되므로 새 실습 환경에서 실행합니다.

### Python 점검 실행

PowerShell에서 Python 패키지 설치 후 접속 비밀번호를 환경변수로 전달합니다.

```powershell
python -m pip install -r requirements.txt
$secure = Read-Host "PostgreSQL 비밀번호" -AsSecureString
$env:DB_PASSWORD = [System.Net.NetworkCredential]::new("", $secure).Password
python db_health_check.py
```

접속 주소·포트·DB명·계정은 [환경변수 예시](.env.example)를 참고합니다. 비밀번호는 GitHub에 올리지 않습니다.

## 실습 범위

- 가상 데이터 기반의 로컬 프로젝트로, 실제 서비스 성능을 대표하지 않습니다.
- 인덱스 스캔 제한 실험은 기존 PK 인덱스 사용에도 영향을 줍니다.
- 상태 점검은 실행 시점의 정보만 출력하며 자동 알림 기능은 없습니다.
- 백업·복원과 사용자 권한 관련 실습은 별도 경험이 있지만, **현재 저장소에 재현 자료가 없어 완료 항목에 포함하지 않았습니다.**

**배운 점:** 데이터 입력부터 오류 복구, 실행 계획 비교, 장기 트랜잭션 점검까지 결과를 직접 확인하는 과정을 학습했습니다.

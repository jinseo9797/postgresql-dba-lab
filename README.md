# PostgreSQL DBA Lab

### 데이터가 정확하게 저장되고, 빠르게 조회되며, 안정적으로 운영되는지 검증하는 프로젝트

PostgreSQL 16 환경에서 **데이터 무결성 검증, 트랜잭션 제어, JOIN 쿼리 최적화, 데이터베이스 상태 모니터링**을 직접 실습한 개인 프로젝트입니다.

게임 QA 업무에서 SQL을 활용해 데이터 정합성을 검증했던 경험을 바탕으로, 데이터를 사용하는 입장에서 나아가 **데이터베이스가 데이터를 어떻게 관리하고 처리하는지** 이해하기 위해 프로젝트를 진행했습니다.

단순히 SQL 쿼리를 실행하는 데 그치지 않고, 문제가 발생하는 상황을 재현하고 실행계획과 모니터링 결과를 통해 검증하는 과정에 집중했습니다.

---

## 1. 프로젝트 핵심 성과

| 구분 | 주요 성과 |
|---|---|
| 데이터 무결성 | PK, FK, UNIQUE, CHECK 제약조건을 통한 데이터 검증 |
| 트랜잭션 | 재고 차감 및 오류 발생 후 ROLLBACK 검증 |
| 성능 최적화 | 311,000건의 합성 데이터 기반 JOIN 실행계획 분석 |
| 인덱스 설계 | 검색 조건과 JOIN 키에 맞는 인덱스 2개 추가 |
| 실행 시간 | 인덱스 적용 전후 단회 측정 17.621ms → 1.111ms |
| DB 모니터링 | Python을 이용해 60초 초과 장기 트랜잭션 탐지 |

> 성능 측정은 로컬 실습 환경에서 진행했습니다. 실행 시간은 캐시 및 환경에 영향을 받으며, 측정 결과를 운영 환경의 성능으로 일반화하지 않았습니다.

## 2. 기술 스택

| 구분 | 기술 |
|---|---|
| Database | PostgreSQL 16 |
| Environment | Docker, pgAdmin |
| Language | SQL, Python 3 |
| Python Library | psycopg 3 |
| Monitoring | pg_stat_activity, pg_blocking_pids |
| Performance Analysis | EXPLAIN ANALYZE, BUFFERS |

## 3. 주요 구현 및 문제 해결 경험

### 3-1. 데이터 무결성 — 잘못된 데이터의 저장을 어떻게 방지할까?

**문제 상황**

고객, 주문, 상품, 재고처럼 서로 관계가 있는 데이터는 잘못된 값이 저장되거나 참조 관계가 깨지면 서비스 운영에 영향을 줄 수 있습니다.

이를 검증하기 위해 고객, 상품, 주문, 주문상세, 재고 테이블로 구성된 이커머스 데이터베이스를 설계했습니다.

**구현 및 검증**

- PK와 FK를 통해 테이블 간 참조 관계 구성
- UNIQUE 제약조건을 통한 중복 이메일 방지
- CHECK 제약조건을 통한 음수 재고와 잘못된 주문 수량 방지
- JOIN 쿼리를 통한 주문과 주문상세의 관계 검증

예를 들어 주문 수량에 음수를 입력하면 CHECK 제약조건 오류가 발생하도록 구성했습니다.

```sql
-- 주문 수량에 0 이하의 값이 입력되는 것을 방지
quantity INT NOT NULL CHECK (quantity > 0)
```

**트랜잭션 오류 복구 검증**

재고 수량을 차감한 다음, 의도적으로 잘못된 주문상세 데이터를 입력하는 상황을 재현했습니다.

1. BEGIN으로 트랜잭션 시작
2. UPDATE로 재고 1개 차감
3. 음수 주문 수량 INSERT 시도
4. CHECK 제약조건 오류 발생 (SQLSTATE 23514)
5. ROLLBACK으로 전체 변경 취소
6. 재고 수량과 잘못된 주문상세 저장 여부 확인

**결과**

오류가 발생한 트랜잭션을 ROLLBACK했을 때 재고 변경이 취소되고 잘못된 주문상세가 저장되지 않는 것을 검증했습니다.

이를 통해 데이터베이스 제약조건과 트랜잭션 제어가 데이터 정합성을 유지하는 데 어떤 역할을 하는지 확인했습니다.

관련 코드: [`01_schema.sql`](sql/01_schema.sql) · [`03_transaction_test.sql`](sql/03_transaction_test.sql) · [`03b_failed_order_test.sql`](sql/03b_failed_order_test.sql)

---

### 3-2. JOIN 성능 최적화 — 필요한 데이터는 적은데 왜 많은 데이터를 탐색할까?

**문제 상황**

고객별 주문 금액을 조회하기 위해 고객, 주문, 주문상세 테이블을 JOIN하는 쿼리를 작성했습니다.

실제 조회 대상은 특정 고객의 주문 10건이었지만, 전체 주문 100,000건과 주문상세 200,000건을 대상으로 탐색이 발생하는 실행계획을 확인했습니다.

**테스트 데이터 구성**

| 테이블 | 데이터 건수 |
|---|---:|
| customers | 10,000 |
| products | 1,000 |
| orders | 100,000 |
| order_items | 200,000 |
| **합계** | **311,000** |

데이터는 PostgreSQL의 `generate_series()`를 활용해 생성했습니다.

**원인 분석**

`EXPLAIN (ANALYZE, BUFFERS)`를 통해 실제 실행계획을 분석했습니다.

인덱스 적용 전에는 주문과 주문상세 테이블에서 Seq Scan 및 Parallel Seq Scan이 발생했습니다.

특히 WHERE 조건으로 특정 고객을 조회하고, 주문 ID를 기준으로 주문상세를 JOIN하는 과정에서 인덱스 활용을 검토할 필요가 있다고 판단했습니다.

**개선 방법**

조회 조건 및 JOIN 키를 고려해 다음 두 개의 인덱스를 추가했습니다.

```sql
-- 고객 ID 검색과 최신 주문 순 조회를 고려한 복합 인덱스
CREATE INDEX idx_orders_customer_date
ON ecommerce_bench.orders (customer_id, ordered_at DESC);

-- 주문 ID 기반 주문상세 조회용 인덱스
CREATE INDEX idx_order_items_order_id
ON ecommerce_bench.order_items (order_id);
```

**성능 측정 결과**

| 측정 조건 | 실행 시간 |
|---|---:|
| 신규 인덱스 적용 전 단회 | 17.621ms |
| 신규 인덱스 적용 직후 단회 | 1.111ms |
| 인덱스 사용 5회 평균 (2차) | 0.1818ms |
| 인덱스 스캔 제한 5회 평균 (최종) | 18.9172ms |

신규 인덱스 적용 전후 단회 측정에서는 실행 시간이 약 93.7% 감소했습니다.

다만 단회 측정은 캐시 및 시스템 상태의 영향을 받을 수 있으므로, 반복 측정과 별도로 구분했습니다.

**실행계획 비교**

인덱스를 사용한 실행계획과 인덱스 스캔을 제한한 실행계획을 추가로 비교했습니다.

#### 인덱스 스캔 제한 조건

인덱스 기반 탐색을 제한한 상태에서 동일한 JOIN 쿼리를 실행했습니다.

![인덱스 스캔 제한 실행계획](docs/screenshots/plan_before.png)

**결과:** `orders`에서는 Seq Scan, `order_items`에서는 Parallel Seq Scan이 발생했습니다. 해당 캡처의 실행 시간은 40.971ms였습니다.

이 실험에서는 기존 PK 인덱스 사용도 제한되므로, 실제 인덱스 생성 전 환경과는 구분해야 합니다.

#### 인덱스 사용 조건

인덱스 스캔이 허용된 상태에서 동일한 JOIN 쿼리를 실행했습니다.

![인덱스 사용 실행계획](docs/screenshots/plan_after.png)

**결과:** `orders`에서는 Bitmap Index Scan과 Bitmap Heap Scan이, `order_items`에서는 Index Scan이 사용되었습니다. 해당 캡처의 실행 시간은 4.306ms였습니다.

두 캡처는 인덱스 스캔 허용 여부에 따른 실행계획 비교 자료이며, 신규 인덱스 2개의 독립적인 성능 개선 효과를 측정한 결과는 아닙니다.

**배운 점**

인덱스를 생성했다고 반드시 성능이 개선되는 것은 아닙니다. 조회 조건, 데이터 분포, 통계 정보, 실행계획 및 버퍼 사용량을 함께 확인해야 한다는 점을 학습했습니다.

상세 측정 결과: [`performance_results.md`](docs/performance_results.md)

관련 코드: [`05_benchmark_data.sql`](sql/05_benchmark_data.sql) · [`06_index_optimization.sql`](sql/06_index_optimization.sql) · [`08_benchmark_query.sql`](sql/08_benchmark_query.sql)

---

### 3-3. DB 모니터링 — 장시간 종료되지 않은 트랜잭션을 어떻게 발견할까?

**문제 상황**

데이터베이스 운영에서는 실행 시간이 긴 쿼리뿐만 아니라, 트랜잭션을 종료하지 않은 채 연결이 유지되는 세션도 점검해야 합니다.

특히 `idle in transaction` 상태가 장시간 지속되면 잠금 유지나 VACUUM 작업 등에 영향을 줄 수 있습니다.

이러한 상태를 확인하기 위해 Python 기반의 간단한 모니터링 프로그램을 구현했습니다.

**구현 내용**

PostgreSQL 시스템 뷰 및 함수를 활용해 다음 항목을 조회했습니다.

- Active / Idle 세션 수
- Idle in transaction 세션 수
- 60초 이상 유지된 장기 트랜잭션
- 다른 세션에 의해 차단된 잠금 대기 세션

**이상 상태 재현**

모니터링 기능을 검증하기 위해 테스트 세션에서 트랜잭션을 시작한 후 COMMIT 또는 ROLLBACK을 실행하지 않고 유지했습니다.

이후 Python 프로그램을 실행해 장기 트랜잭션 탐지 여부를 확인했습니다.

![Python DB 장기 트랜잭션 탐지](docs/screenshots/health_check.png)

**결과**

약 3분 동안 유지된 `idle in transaction` 세션 1건을 탐지했으며, 해당 세션의 PID와 트랜잭션 경과 시간이 경고 메시지로 출력되는 것을 확인했습니다.

잠금 대기 세션은 발견되지 않았습니다.

테스트 종료 후 ROLLBACK으로 실습 트랜잭션을 정리했습니다.

**배운 점**

데이터베이스 관리에서는 문제가 발생한 후 복구하는 것뿐 아니라, 세션 및 트랜잭션 상태를 지속적으로 점검할 수 있는 기반을 마련하는 것도 중요하다는 점을 학습했습니다.

현재 프로그램은 실행 시점의 상태를 점검하는 도구이며, 자동 알림 및 장애 복구 기능은 포함하지 않습니다.

관련 코드: [`db_health_check.py`](db_health_check.py) · [`07_health_queries.sql`](sql/07_health_queries.sql)

---

## 4. 프로젝트 파일 구성

```text
postgresql-dba-lab/
├── README.md
├── db_health_check.py
├── requirements.txt
├── .env.example
├── .gitignore
├── sql/
│   ├── 01_schema.sql
│   ├── 02_seed_data.sql
│   ├── 03_transaction_test.sql
│   ├── 03b_failed_order_test.sql
│   ├── 04_benchmark_schema.sql
│   ├── 05_benchmark_data.sql
│   ├── 06_index_optimization.sql
│   ├── 07_health_queries.sql
│   ├── 08_benchmark_query.sql
│   └── 09_validation.sql
└── docs/
    ├── performance_results.md
    └── screenshots/
        ├── plan_before.png
        ├── plan_after.png
        └── health_check.png
```

## 5. 실행 환경 및 재현 방법

### 실행 환경

- PostgreSQL 16
- Docker 및 pgAdmin
- Python 3 / psycopg 3
- 데이터베이스: `dba_lab`
- 스키마: `ecommerce`, `ecommerce_bench`
- 로컬 연결 예시: `127.0.0.1:5433`

### SQL 실행 순서

새로 생성한 실습 데이터베이스에서 다음 순서로 실행합니다.

1. `01_schema.sql` → `02_seed_data.sql` → `03_transaction_test.sql`
2. `03b_failed_order_test.sql` — BEGIN/UPDATE, 오류 INSERT, ROLLBACK을 각각 실행
3. `04_benchmark_schema.sql` → `05_benchmark_data.sql`
4. `08_benchmark_query.sql` — 인덱스 적용 전 측정
5. `06_index_optimization.sql` — 인덱스 생성
6. `08_benchmark_query.sql` — 인덱스 적용 후 측정
7. `09_validation.sql` — 데이터 정합성 검증

`03b_failed_order_test.sql` 실행 중 SQLSTATE `23514` 오류가 발생하는 것은 의도된 테스트 결과입니다. 오류가 발생한 뒤에는 ROLLBACK을 별도로 실행해야 합니다.

기존 데이터가 있는 환경에서는 SQL 파일을 처음부터 재실행하지 않는 것을 권장합니다. 특히 `05_benchmark_data.sql`은 벤치마크 데이터가 이미 존재하면 중단하도록 구성했습니다.

### Python 모니터링 실행

Windows PowerShell 5.1 기준입니다.

```powershell
python -m pip install -r requirements.txt

$secure = Read-Host "PostgreSQL 비밀번호" -AsSecureString
$env:DB_PASSWORD = [System.Net.NetworkCredential]::new("", $secure).Password

python db_health_check.py
```

경고 기준 시간을 변경할 수도 있습니다.

```powershell
python db_health_check.py --idle-seconds 30
```

접속 정보는 `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` 환경변수로 변경할 수 있습니다.

비밀번호는 환경변수로 전달하며 저장소에 포함하지 않습니다.

---

## 6. 프로젝트 한계 및 향후 개선 방향

본 프로젝트는 PostgreSQL의 핵심 관리 기능을 이해하기 위한 개인 로컬 실습입니다.

**현재 프로젝트의 한계**

- 실서비스가 아닌 합성 데이터를 활용한 성능 실험
- 캐시 및 시스템 부하를 엄격하게 통제하지 않은 측정 환경
- 인덱스 스캔 제한 실험에서 기존 PK 인덱스 사용도 영향을 받음
- 실시간 대시보드, 자동 경고 및 장애 복구 기능 미구현

**향후 개선 방향**

- 다양한 데이터 분포와 조회 조건에 따른 인덱스 효과 비교
- 잠금 대기 및 Deadlock 상황에 대한 재현 코드 보강
- 백업 및 복원 검증 절차 문서화
- 모니터링 결과의 기록 및 추이 분석 기능 검토

사용자 권한 설정, 백업·복원, Deadlock 실습도 진행했지만, 현재 저장소에는 해당 실습의 재현 코드가 모두 포함되어 있지 않으므로 완성된 구현 기능으로 소개하지 않았습니다.

## 7. 프로젝트 회고

이번 프로젝트를 통해 데이터베이스를 다룰 때 단순히 SQL을 정확하게 작성하는 것만으로는 충분하지 않다는 점을 배웠습니다.

데이터가 올바르게 저장되는지, 특정 조회 쿼리가 불필요한 데이터를 탐색하지 않는지, 트랜잭션이 예상치 못한 상태로 유지되고 있지는 않은지 등을 함께 고려해야 했습니다.

특히 인덱스 최적화 실습에서 **실행계획을 분석하고, 가설을 세워 인덱스를 생성한 뒤, 실제 측정값으로 결과를 검증하는 과정**이 가장 의미 있었습니다.

앞으로도 데이터 무결성과 쿼리 성능에 대한 이해를 바탕으로, 안정적인 데이터베이스 운영 역량을 발전시키고자 합니다.

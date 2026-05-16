-- ═════════════════════════════════════════════════════════════
-- TABLE: performance | NovaBridge Solutions v2
-- OBJECTIVE: Audit → Clean → Validate → Export
-- ═════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- Verify row count
-- RESULT: 861 rows confirmed
-- ─────────────────────────────────────────────────────────────
SELECT COUNT(*) FROM performance;
DESCRIBE performance;

-- ─────────────────────────────────────────────────────────────
-- NULL check across all columns
-- RESULT:  null_emp_id: 31| null_agent: 22| null_manager: 29| null_team: 24
-- 			null_month: 25| null_aht: 43| null_nice: 40| null_adherence: 48
-- ─────────────────────────────────────────────────────────────
SELECT
  SUM(CASE WHEN employee_id IS NULL THEN 1 ELSE 0 END)                AS null_emp_id,
  SUM(CASE WHEN agent_name IS NULL THEN 1 ELSE 0 END)                 AS null_agent,
  SUM(CASE WHEN manager_name IS NULL THEN 1 ELSE 0 END)               AS null_manager,
  SUM(CASE WHEN team_name IS NULL THEN 1 ELSE 0 END)                  AS null_team,
  SUM(CASE WHEN month IS NULL THEN 1 ELSE 0 END)                      AS null_month,
  SUM(CASE WHEN aht_seconds IS NULL THEN 1 ELSE 0 END)                AS null_aht,
  SUM(CASE WHEN nice_evaluation_score IS NULL THEN 1 ELSE 0 END)      AS null_nice,
  SUM(CASE WHEN schedule_adherence_pct IS NULL THEN 1 ELSE 0 END)     AS null_adherence
FROM performance;

-- ─────────────────────────────────────────────────────────────
-- Check distinct month formats
-- RESULT: 
-- 1. Mixed formats — MM-YYYY, Mon YYYY, YYYY-MM detected, Total 85 rows
-- 2. Spacing issue in Team_name, Manager_name & Agent_name
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT month        FROM performance;
SELECT DISTINCT team_name    FROM performance;
SELECT DISTINCT manager_name FROM performance;
SELECT DISTINCT agent_name   FROM performance;

-- ─────────────────────────────────────────────────────────────
-- Score range check — catch negatives and out-of-range values
-- ─────────────────────────────────────────────────────────────
SELECT
  MIN(comms_audit_score),      MAX(comms_audit_score),
  MIN(nice_evaluation_score),  MAX(nice_evaluation_score),
  MIN(kc_quiz_score),          MAX(kc_quiz_score),
  MIN(schedule_adherence_pct), MAX(schedule_adherence_pct),
  MIN(aht_seconds),            MAX(aht_seconds)
FROM performance;

-- ─────────────────────────────────────────────────────────────
-- CREATE cleaned performance table
-- CLEANING APPLIED:
--   a. TRIM on employee_id
--   b. agent_name NULL → pulled from interaction_clean by agent_id
--      fallback realistic names if still not found
--   c. manager_name NULL → pulled from interaction_clean by agent_id
--      fallback → 'Avinash Maurya'
--   d. team_name NULL → 'Team Eta'
--   e. month → standardised to YYYY-MM | NULL rows dropped
--   f. % columns renamed to pct
--   g. Negative/NULL scores → team-based realistic fill
--   h. Out-of-range scores → capped at 100
--   i. AHT = 9999 or NULL → team-based realistic fill
--   j. Cast all numeric columns to DECIMAL(10,2)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE performance_clean AS
WITH cleaned AS (
  SELECT
    TRIM(p.employee_id)                                                AS employee_id,

    -- agent_name: NULL → match from interaction_clean by agent_id
    -- fallback to 'Alex Smith' if still not found
    COALESCE(
      NULLIF(TRIM(p.agent_name), ''),
      (SELECT TRIM(i.agent_name)
       FROM interaction_clean i
       WHERE TRIM(i.agent_id) = TRIM(p.employee_id)
       LIMIT 1),
      'Alex Smith'
    )                                                                  AS agent_name,

    -- manager_name: NULL → match from interaction_clean by agent_id
    -- fallback → 'Avinash Maurya'
    COALESCE(
      NULLIF(CONCAT(
        UPPER(SUBSTRING(TRIM(p.manager_name), 1, 1)),
        LOWER(SUBSTRING(TRIM(p.manager_name), 2))
      ), ''),
      (SELECT TRIM(i.manager_name)
       FROM interaction_clean i
       WHERE TRIM(i.agent_id) = TRIM(p.employee_id)
       LIMIT 1),
      'Avinash Maurya'
    )                                                                  AS manager_name,

    -- team_name: NULL → match from interaction_clean
    -- fallback → 'Team Eta'
    COALESCE(
      NULLIF(CONCAT(
        UPPER(SUBSTRING(TRIM(p.team_name), 1, 1)),
        LOWER(SUBSTRING(TRIM(p.team_name), 2))
      ), ''),
      (SELECT TRIM(i.team_name)
       FROM interaction_clean i
       WHERE TRIM(i.agent_id) = TRIM(p.employee_id)
       LIMIT 1),
      'Team Eta'
    )                                                                  AS team_name,

    -- Month standardisation → YYYY-MM
    DATE_FORMAT(
      CASE
        WHEN p.month REGEXP '^[0-9]{2}-[0-9]{4}$'
          THEN STR_TO_DATE(CONCAT('01-', p.month), '%d-%m-%Y')
        WHEN p.month REGEXP '^[0-9]{4}-[0-9]{2}$'
          THEN STR_TO_DATE(CONCAT('01-', p.month), '%d-%Y-%m')
        WHEN p.month REGEXP '^[A-Za-z]{3} [0-9]{4}$'
          THEN STR_TO_DATE(CONCAT('01 ', p.month), '%d %b %Y')
        ELSE NULL
      END,
    '%Y-%m')                                                           AS month,

    -- Schedule Adherence pct (renamed from %)
    -- Team ranges: Alpha:85-97 | Beta:78-92 | Gamma:68-84 | Delta:82-95
    CASE
      WHEN p.schedule_adherence_pct IS NULL OR p.schedule_adherence_pct < 0
        THEN CASE
          WHEN UPPER(TRIM(p.team_name)) LIKE '%ALPHA%' THEN ROUND(85 + RAND()*12, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%BETA%'  THEN ROUND(78 + RAND()*14, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%GAMMA%' THEN ROUND(68 + RAND()*16, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%DELTA%' THEN ROUND(82 + RAND()*13, 2)
          ELSE ROUND(75 + RAND()*15, 2)
        END
      WHEN p.schedule_adherence_pct > 100 THEN 100
      ELSE ROUND(CAST(p.schedule_adherence_pct AS DECIMAL(10,2)), 2)
    END                                                                AS schedule_adherence_pct,

    -- Resource Utilization pct (renamed from %)
    -- Alpha:80-93 | Beta:72-88 | Gamma:62-80 | Delta:78-92
    CASE
      WHEN p.resource_utilization_pct IS NULL OR p.resource_utilization_pct < 0
        THEN CASE
          WHEN UPPER(TRIM(p.team_name)) LIKE '%ALPHA%' THEN ROUND(80 + RAND()*13, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%BETA%'  THEN ROUND(72 + RAND()*16, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%GAMMA%' THEN ROUND(62 + RAND()*18, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%DELTA%' THEN ROUND(78 + RAND()*14, 2)
          ELSE ROUND(70 + RAND()*15, 2)
        END
      WHEN p.resource_utilization_pct > 100 THEN 100
      ELSE ROUND(CAST(p.resource_utilization_pct AS DECIMAL(10,2)), 2)
    END                                                                AS resource_utilization_pct,

    -- Comms Audit Score
    -- Alpha:80-98 | Beta:68-85 | Gamma:55-75 | Delta:72-90
    CASE
      WHEN p.comms_audit_score IS NULL OR p.comms_audit_score < 0
        THEN CASE
          WHEN UPPER(TRIM(p.team_name)) LIKE '%ALPHA%' THEN ROUND(80 + RAND()*18, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%BETA%'  THEN ROUND(68 + RAND()*17, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%GAMMA%' THEN ROUND(55 + RAND()*20, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%DELTA%' THEN ROUND(72 + RAND()*18, 2)
          ELSE ROUND(60 + RAND()*20, 2)
        END
      WHEN p.comms_audit_score > 100 THEN 100
      ELSE ROUND(CAST(p.comms_audit_score AS DECIMAL(10,2)), 2)
    END                                                                AS comms_audit_score,

    -- NICE Evaluation Score
    -- Alpha:78-96 | Beta:65-84 | Gamma:52-74 | Delta:70-90
    CASE
      WHEN p.nice_evaluation_score IS NULL OR p.nice_evaluation_score < 0
        THEN CASE
          WHEN UPPER(TRIM(p.team_name)) LIKE '%ALPHA%' THEN ROUND(78 + RAND()*18, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%BETA%'  THEN ROUND(65 + RAND()*19, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%GAMMA%' THEN ROUND(52 + RAND()*22, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%DELTA%' THEN ROUND(70 + RAND()*20, 2)
          ELSE ROUND(60 + RAND()*20, 2)
        END
      WHEN p.nice_evaluation_score > 100 THEN 100
      ELSE ROUND(CAST(p.nice_evaluation_score AS DECIMAL(10,2)), 2)
    END                                                                AS nice_evaluation_score,

    -- KC Quiz Score
    -- Alpha:75-95 | Beta:62-82 | Gamma:48-70 | Delta:68-88
    CASE
      WHEN p.kc_quiz_score IS NULL OR p.kc_quiz_score < 0
        THEN CASE
          WHEN UPPER(TRIM(p.team_name)) LIKE '%ALPHA%' THEN ROUND(75 + RAND()*20, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%BETA%'  THEN ROUND(62 + RAND()*20, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%GAMMA%' THEN ROUND(48 + RAND()*22, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%DELTA%' THEN ROUND(68 + RAND()*20, 2)
          ELSE ROUND(55 + RAND()*20, 2)
        END
      WHEN p.kc_quiz_score > 100 THEN 100
      ELSE ROUND(CAST(p.kc_quiz_score AS DECIMAL(10,2)), 2)
    END                                                                AS kc_quiz_score,

    -- AHT — team-based | 9999 and NULL replaced
    -- Alpha:300-700 | Beta:500-1000 | Gamma:800-1800 | Delta:400-900
    CASE
      WHEN p.aht_seconds IS NULL
        OR p.aht_seconds < 0
        OR p.aht_seconds = 9999
        THEN CASE
          WHEN UPPER(TRIM(p.team_name)) LIKE '%ALPHA%' THEN ROUND(300 + RAND()*400,  2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%BETA%'  THEN ROUND(500 + RAND()*500,  2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%GAMMA%' THEN ROUND(800 + RAND()*1000, 2)
          WHEN UPPER(TRIM(p.team_name)) LIKE '%DELTA%' THEN ROUND(400 + RAND()*500,  2)
          ELSE ROUND(500 + RAND()*600, 2)
        END
      ELSE ROUND(CAST(p.aht_seconds AS DECIMAL(10,2)), 2)
    END                                                                AS aht_seconds,

    ROUND(CAST(p.total_callbacks AS DECIMAL(10,2)), 0)                 AS total_callbacks,

    -- Callback Rate pct (renamed from %)
    CASE
      WHEN p.callback_rate_pct IS NULL OR p.callback_rate_pct < 0
        THEN ROUND(2 + RAND()*10, 2)
      ELSE ROUND(CAST(p.callback_rate_pct AS DECIMAL(10,2)), 2)
    END                                                                AS callback_rate_pct,

    -- Average Hold Time — NULL/negative → realistic fill
    CASE
      WHEN p.average_hold_time_seconds IS NULL
        OR p.average_hold_time_seconds < 0
        THEN ROUND(60 + RAND()*240, 2)
      ELSE ROUND(CAST(p.average_hold_time_seconds AS DECIMAL(10,2)), 2)
    END                                                                AS average_hold_time_seconds

  FROM performance p
  WHERE p.employee_id IS NOT NULL
    AND p.agent_name  IS NOT NULL
),
-- Drop NULL months after standardisation
filtered AS (
  SELECT * FROM cleaned
  WHERE month IS NOT NULL
)
SELECT * FROM filtered;

-- ─────────────────────────────────────────────────────────────
-- Sanity check after cleaning
-- RESULT: 787 rows
-- ─────────────────────────────────────────────────────────────
SELECT COUNT(*)              FROM performance_clean;
SELECT DISTINCT month        FROM performance_clean ORDER BY month; -- 28 rows
SELECT DISTINCT team_name    FROM performance_clean; -- 5 rows
SELECT DISTINCT manager_name FROM performance_clean; -- 4 rows

-- Verify no NULLs remain
SELECT
  SUM(CASE WHEN agent_name IS NULL THEN 1 ELSE 0 END)    AS null_agent,
  SUM(CASE WHEN manager_name IS NULL THEN 1 ELSE 0 END)  AS null_manager,
  SUM(CASE WHEN team_name IS NULL THEN 1 ELSE 0 END)     AS null_team,
  SUM(CASE WHEN month IS NULL THEN 1 ELSE 0 END)         AS null_month
FROM performance_clean;

-- Verify score ranges — all between 0 and 100
SELECT
  MIN(comms_audit_score),      MAX(comms_audit_score),
  MIN(nice_evaluation_score),  MAX(nice_evaluation_score),
  MIN(kc_quiz_score),          MAX(kc_quiz_score),
  MIN(schedule_adherence_pct), MAX(schedule_adherence_pct),
  MIN(aht_seconds),            MAX(aht_seconds)
FROM performance_clean;

-- Team-level averages — verify visible variance between teams
-- Expected: Alpha > Delta > Beta > Gamma
SELECT
  team_name,
  ROUND(AVG(schedule_adherence_pct),2)   AS avg_adherence,
  ROUND(AVG(resource_utilization_pct),2) AS avg_utilization,
  ROUND(AVG(nice_evaluation_score),2)    AS avg_nice,
  ROUND(AVG(kc_quiz_score),2)            AS avg_kc,
  ROUND(AVG(comms_audit_score),2)        AS avg_comms,
  ROUND(AVG(aht_seconds),2)              AS avg_aht
FROM performance_clean
GROUP BY team_name
ORDER BY avg_adherence DESC;

-- ─────────────────────────────────────────────────────────────
-- Exported them to the SQL directory
-- ─────────────────────────────────────────────────────────────
SELECT * FROM performance_clean
INTO OUTFILE 'Type_your_destinaiton_path_Here/performance_clean.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';

-- =====================================================
-- THE END
-- =====================================================
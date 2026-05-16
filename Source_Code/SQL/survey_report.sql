-- ═════════════════════════════════════════════════════════════
-- TABLE: survey_report | NovaBridge Solutions v2
-- OBJECTIVE: Audit → Deduplicate → Clean → Export
-- DATE RANGE: Jan 2024 → Apr 2026
-- ═════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- Verify row count matches Python-generated dataset
-- RESULT: 209,510 rows confirmed — matches source file
-- ─────────────────────────────────────────────────────────────
SELECT COUNT(*) FROM survey_report;
SELECT * FROM survey_report LIMIT 100;

-- ─────────────────────────────────────────────────────────────
-- Check datatypes assigned by MySQL on import
-- RESULT: survey_id, interaction_id, agent_id, agent_name,
--         channel, survey_date, dsat_flag, country,
--         manager_name → TEXT
--         employee_id, csat_score → DOUBLE
-- ACTION: Cast employee_id → BIGINT | csat_score → DECIMAL
-- ─────────────────────────────────────────────────────────────
DESCRIBE survey_report;

-- ─────────────────────────────────────────────────────────────
-- NULL check across critical columns
-- RESULT: null_survey_id:0 | null_interaction_id:0 |
--         null_employee_id:14,579 | null_agent_id:10,394 |
--         null_csat:14,773 | null_date:8,382 | null_country:12,543
-- ACTION: Drop rows where employee_id, agent_id, csat_score NULL
--         survey_date NULL → filled with random date in range
--         country NULL → Other | channel NULL → Portal
--         manager_name NULL → Joseph Shankar
-- ─────────────────────────────────────────────────────────────
SELECT
  SUM(CASE WHEN survey_id IS NULL THEN 1 ELSE 0 END)        AS null_survey_id,
  SUM(CASE WHEN interaction_id IS NULL THEN 1 ELSE 0 END)   AS null_interaction_id,
  SUM(CASE WHEN employee_id IS NULL THEN 1 ELSE 0 END)      AS null_employee_id,
  SUM(CASE WHEN agent_id IS NULL THEN 1 ELSE 0 END)         AS null_agent_id,
  SUM(CASE WHEN csat_score IS NULL THEN 1 ELSE 0 END)       AS null_csat,
  SUM(CASE WHEN survey_date IS NULL THEN 1 ELSE 0 END)      AS null_date,
  SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END)          AS null_country
FROM survey_report;

-- ─────────────────────────────────────────────────────────────
-- Duplicate check on survey_id
-- RESULT: Each survey_id appears exactly twice — 4,510 rows
-- ACTION: ROW_NUMBER() PARTITION BY survey_id — keep first
-- ─────────────────────────────────────────────────────────────
SELECT survey_id, COUNT(*) AS cnt
FROM survey_report
GROUP BY survey_id
HAVING cnt > 1
LIMIT 20;

-- ─────────────────────────────────────────────────────────────
-- Date format check
-- RESULT: Mixed formats — YYYY-MM-DD, DD-MM-YYYY,
--         MM/DD/YYYY, Mon DD YYYY | 3,405 distinct values
-- ACTION: Parse all formats | unparseable → filled with random date
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT survey_date FROM survey_report LIMIT 20;

-- ─────────────────────────────────────────────────────────────
-- CSAT score range check
-- RESULT: Min: 1 | Max: 6 ✅ — valid range
-- ACTION: No changes needed — score of 0 dropped in WHERE clause
-- ─────────────────────────────────────────────────────────────
SELECT MIN(csat_score), MAX(csat_score) FROM survey_report;

-- ─────────────────────────────────────────────────────────────
-- Categorical check
-- RESULT: dsat_flag — Yes, No, NULL → NULL filled with No
--         channel — Chat, Call, NULL → NULL filled with Portal
--         country — US variants, Canada variants, NULL → Other
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT dsat_flag  FROM survey_report;
SELECT DISTINCT channel    FROM survey_report;
SELECT DISTINCT country    FROM survey_report;

-- ─────────────────────────────────────────────────────────────
-- employee_id format check
-- RESULT: DOUBLE on import — no decimals, cast to BIGINT
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT employee_id FROM survey_report LIMIT 10;

-- ─────────────────────────────────────────────────────────────
-- CREATE cleaned survey table
-- CLEANING APPLIED:
--   a. Deduplicate on survey_id — keep first occurrence
--   b. Drop rows where employee_id, agent_id, csat_score NULL
--   c. survey_date NULL/unparseable → filled with random date
--   d. agent_name + employee_name — NULL handled per case
--   e. channel NULL/Unknown → Portal
--   f. country NULL/Unknown → Other
--   g. dsat_flag NULL → No
--   h. manager_name NULL → Joseph Shankar
--   i. CSAT score of 0 dropped in WHERE clause
--   j. Cast employee_id → BIGINT | csat_score → DECIMAL(5,2)
--   k. No post-insert deletes — all handled in CTE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE survey_clean AS
WITH deduped AS (
  -- Remove duplicate survey_ids — keep first occurrence
  -- RESULT: ~209K → ~163K rows after dedup + NULL filter
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY survey_id
      ORDER BY survey_id
    ) AS rn
  FROM survey_report
  WHERE employee_id IS NOT NULL
    AND agent_id    IS NOT NULL
    AND csat_score  IS NOT NULL
    AND csat_score  != 0
),
cleaned AS (
  SELECT
    TRIM(survey_id)                                             AS survey_id,
    TRIM(interaction_id)                                        AS interaction_id,
    CAST(employee_id AS UNSIGNED)                               AS employee_id,

    -- employee_name: NULL/empty → realistic fallback
    CASE
      WHEN employee_name IS NULL OR TRIM(employee_name) = ''
        THEN 'Maria Johnson'
      ELSE CONCAT(
        UPPER(SUBSTRING(TRIM(employee_name),1,1)),
        LOWER(SUBSTRING(TRIM(employee_name),2)))
    END                                                         AS employee_name,

    TRIM(agent_id)                                              AS agent_id,

    -- agent_name: NULL/empty → match from interaction_clean
    -- fallback → 'Alex Smith'
    COALESCE(
      NULLIF(CONCAT(
        UPPER(SUBSTRING(TRIM(agent_name),1,1)),
        LOWER(SUBSTRING(TRIM(agent_name),2))
      ),''),
      (SELECT TRIM(i.agent_name)
       FROM interaction_clean i
       WHERE TRIM(i.agent_id) = TRIM(agent_id)
       LIMIT 1),
      'Alex Smith'
    )                                                           AS agent_name,

    -- Channel — NULL/Unknown → Portal
    CASE
      WHEN LOWER(TRIM(channel)) = 'chat' THEN 'Chat'
      WHEN LOWER(TRIM(channel)) = 'call' THEN 'Call'
      ELSE 'Portal'
    END                                                         AS channel,

    -- Date parsing — all formats unified to DATE
    -- NULL/unparseable → filled with random date Jan 2024–Apr 2026
    COALESCE(
      CASE
        WHEN survey_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
          THEN STR_TO_DATE(survey_date, '%Y-%m-%d')
        WHEN survey_date REGEXP '^[0-9]{1,2}-[0-9]{2}-[0-9]{4}$'
          THEN STR_TO_DATE(survey_date, '%d-%m-%Y')
        WHEN survey_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
          THEN STR_TO_DATE(survey_date, '%m/%d/%Y')
        WHEN survey_date REGEXP '^[A-Za-z]{3} [0-9]{2} [0-9]{4}$'
          THEN STR_TO_DATE(survey_date, '%b %d %Y')
        ELSE NULL
      END,
      DATE_ADD('2024-01-01', INTERVAL FLOOR(RAND() * 851) DAY)
    )                                                           AS survey_date,

    -- CSAT: valid range 1–6 ✅
    ROUND(CAST(csat_score AS DECIMAL(5,2)), 2)                  AS csat_score,

    -- DSAT flag: NULL → No
    CASE
      WHEN LOWER(TRIM(dsat_flag)) = 'yes' THEN 'Yes'
      ELSE 'No'
    END                                                         AS dsat_flag,

    TRIM(verbatim_comment)                                      AS verbatim_comment,

    -- Country: all US variants → United States
    --          all Canada variants → Canada
    --          NULL/Unknown/Other → Other
    CASE
      WHEN UPPER(TRIM(country)) IN
           ('USA','UNITED STATES','U.S.','US','U.S.A') THEN 'United States'
      WHEN UPPER(TRIM(country)) IN
           ('CANADA','CAN','CA')                        THEN 'Canada'
      ELSE 'Other'
    END                                                         AS country,

    -- manager_name: NULL/empty → Joseph Shankar
    COALESCE(
      NULLIF(CONCAT(
        UPPER(SUBSTRING(TRIM(manager_name),1,1)),
        LOWER(SUBSTRING(TRIM(manager_name),2))
      ),''),
      (SELECT TRIM(i.manager_name)
       FROM interaction_clean i
       WHERE TRIM(i.agent_id) = TRIM(agent_id)
       LIMIT 1),
      'Joseph Shankar'
    )                                                           AS manager_name

  FROM deduped
  WHERE rn = 1
)
SELECT * FROM cleaned;

select distinct survey_id, count(*)
from survey_clean
group by survey_id;
-- ─────────────────────────────────────────────────────────────
-- Sanity check after cleaning
-- RESULT: update after new data load
-- Expected: 168515 clean rows
-- ─────────────────────────────────────────────────────────────
SELECT COUNT(*)                        FROM survey_clean;
SELECT MIN(csat_score), MAX(csat_score) FROM survey_clean;
SELECT DISTINCT dsat_flag              FROM survey_clean;
SELECT DISTINCT country                FROM survey_clean;
SELECT DISTINCT channel                FROM survey_clean;
select distinct manager_name from survey_clean ;

-- Verify no NULLs remain
SELECT
  SUM(CASE WHEN survey_id IS NULL THEN 1 ELSE 0 END)      AS null_survey_id,
  SUM(CASE WHEN agent_id IS NULL THEN 1 ELSE 0 END)       AS null_agent_id,
  SUM(CASE WHEN survey_date IS NULL THEN 1 ELSE 0 END)    AS null_date,
  SUM(CASE WHEN manager_name IS NULL THEN 1 ELSE 0 END)   AS null_manager,
  SUM(CASE WHEN agent_name IS NULL THEN 1 ELSE 0 END)     AS null_agent_name,
  SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END)        AS null_country,
  SUM(CASE WHEN channel IS NULL THEN 1 ELSE 0 END)        AS null_channel
FROM survey_clean;

-- Date coverage check — should cover all 28 months
SELECT
  MIN(survey_date)                                         AS earliest_date,
  MAX(survey_date)                                         AS latest_date,
  COUNT(DISTINCT DATE_FORMAT(survey_date, '%Y-%m'))        AS total_months
FROM survey_clean;

-- Manager distribution
SELECT manager_name, COUNT(*) AS total
FROM survey_clean
GROUP BY manager_name
ORDER BY total DESC;

-- CSAT by team/manager — verify visible variance
SELECT
  manager_name,
  ROUND(AVG(csat_score),2)                                 AS avg_csat,
  COUNT(*)                                                  AS total_surveys,
  SUM(CASE WHEN dsat_flag = 'Yes' THEN 1 ELSE 0 END)       AS dsat_count,
  ROUND(SUM(CASE WHEN dsat_flag = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 2)                                AS dsat_rate_pct
FROM survey_clean
GROUP BY manager_name
ORDER BY avg_csat DESC;

-- ───────────────────────────────────────────────────────────
-- Exported them to the SQL directory
-- ─────────────────────────────────────────────────────────────

SELECT * FROM survey_clean
INTO OUTFILE 'Type_your_destinaiton_path_Here/survey_clean.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';

-- ==============================================================
-- THE END
-- ==============================================================



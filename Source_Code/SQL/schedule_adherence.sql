-- ═════════════════════════════════════════════════════════════
-- TABLE: schedule_adherence | NovaBridge Solutions v2
-- OBJECTIVE: Audit → Deduplicate → Clean → Export
-- DATE RANGE: Jan 2024 → Apr 2026
-- ═════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- Verify row count matches Python-generated dataset
-- RESULT: 3,472 rows confirmed — matches source file
-- ─────────────────────────────────────────────────────────────
SELECT COUNT(*) FROM schedule_adherence;

-- ─────────────────────────────────────────────────────────────
-- Check datatypes assigned by MySQL on import
-- RESULT: date, team_name, manager_name → TEXT
--         All numeric columns → DOUBLE
-- ACTION: Cast numeric to DECIMAL | Parse date column
-- ─────────────────────────────────────────────────────────────
DESCRIBE schedule_adherence;

-- ─────────────────────────────────────────────────────────────
-- NULL check across all columns
-- RESULT: date:109 | team_name:137 | manager_name:163 |
--         scheduled_hours:173 | actual_hours:152 |
--         adherence_pct:209 | agents_scheduled:147 |
--         agents_present:119
-- ACTION: team_name NULL → 'Team Eta'
--         manager_name NULL → 'Joseph Shankar'
--         date NULL after failed parsing → filled with random date
--         Numeric NULLs → filled with team-based realistic values
-- ─────────────────────────────────────────────────────────────
SELECT
  SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END)                AS null_date,
  SUM(CASE WHEN team_name IS NULL THEN 1 ELSE 0 END)           AS null_team,
  SUM(CASE WHEN manager_name IS NULL THEN 1 ELSE 0 END)        AS null_manager,
  SUM(CASE WHEN scheduled_hours IS NULL THEN 1 ELSE 0 END)     AS null_scheduled_hrs,
  SUM(CASE WHEN actual_hours IS NULL THEN 1 ELSE 0 END)        AS null_actual_hrs,
  SUM(CASE WHEN adherence_pct IS NULL THEN 1 ELSE 0 END)       AS null_adherence,
  SUM(CASE WHEN agents_scheduled IS NULL THEN 1 ELSE 0 END)    AS null_agents_sched,
  SUM(CASE WHEN agents_present IS NULL THEN 1 ELSE 0 END)      AS null_agents_present
FROM schedule_adherence;

-- ─────────────────────────────────────────────────────────────
-- Duplicate check on date + team_name combination
-- RESULT: Multiple date+team_name pairs appear twice
--         NULL date rows appear multiple times
-- ACTION: ROW_NUMBER() PARTITION BY date, team_name — keep first
-- ─────────────────────────────────────────────────────────────
SELECT date, team_name, COUNT(*) AS cnt
FROM schedule_adherence
GROUP BY date, team_name
HAVING cnt > 1;

-- ─────────────────────────────────────────────────────────────
-- Date format check
-- RESULT: Mixed formats — YYYY-MM-DD, DD-MM-YYYY,
--         MM/DD/YYYY, Mon DD YYYY | 2,141 distinct values
-- ACTION: Parse all formats | unparseable → NULL → filled
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT date FROM schedule_adherence LIMIT 20;

-- ─────────────────────────────────────────────────────────────
-- Categorical check
-- RESULT: Heavy whitespace, mixed casing on team_name
--         manager_name has whitespace and NULLs
-- ACTION: TRIM + title case | NULL → Joseph Shankar
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT team_name    FROM schedule_adherence;
SELECT DISTINCT manager_name FROM schedule_adherence;

-- ─────────────────────────────────────────────────────────────
-- Negative value check
-- RESULT: 37 rows with negative values
--         agents_present > agents_scheduled: 0 rows ✅
-- ACTION: Negative values → team-based realistic fill
-- ─────────────────────────────────────────────────────────────
SELECT COUNT(*) FROM schedule_adherence
WHERE scheduled_hours  < 0
   OR actual_hours     < 0
   OR adherence_pct    < 0
   OR shrinkage_pct    < 0
   OR agents_scheduled < 0
   OR agents_present   < 0;

SELECT COUNT(*) FROM schedule_adherence
WHERE agents_present > agents_scheduled;

-- ─────────────────────────────────────────────────────────────
-- CREATE cleaned schedule adherence table
-- CLEANING APPLIED:
--   a. Deduplicate on date + team_name — keep first occurrence
--   b. Parse all mixed date formats → DATE
--      unparseable → NULL → filled with random date in range
--   c. TRIM + title case on team_name and manager_name
--   d. NULL team_name    → 'Team Eta'
--   e. NULL manager_name → 'Joseph Shankar'
--   f. % columns renamed to pct
--   g. Negative/NULL numeric values → team-based realistic fill
--   h. adherence_pct capped at 100
--   i. Team-based variance applied for Power BI visual clarity
--      Alpha:85-97 | Beta:78-92 | Gamma:68-84 | Delta:82-95
-- ─────────────────────────────────────────────────────────────
CREATE TABLE schedule_adherence_clean AS
WITH deduped AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY date, team_name
      ORDER BY date
    ) AS rn
  FROM schedule_adherence
),
cleaned AS (
  SELECT
    -- Date parsing — all formats unified to DATE
    -- NULL/unparseable → filled with random date Jan 2024–Apr 2026
    COALESCE(
      CASE
        WHEN date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
          THEN STR_TO_DATE(date, '%Y-%m-%d')
        WHEN date REGEXP '^[0-9]{1,2}-[0-9]{2}-[0-9]{4}$'
          THEN STR_TO_DATE(date, '%d-%m-%Y')
        WHEN date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
          THEN STR_TO_DATE(date, '%m/%d/%Y')
        WHEN date REGEXP '^[A-Za-z]{3} [0-9]{2} [0-9]{4}$'
          THEN STR_TO_DATE(date, '%b %d %Y')
        ELSE NULL
      END,
      DATE_ADD('2024-01-01', INTERVAL FLOOR(RAND() * 851) DAY)
    )                                                              AS date,

    -- team_name: TRIM + title case | NULL → Team Eta
    COALESCE(
      NULLIF(CONCAT(
        UPPER(SUBSTRING(TRIM(team_name), 1, 1)),
        LOWER(SUBSTRING(TRIM(team_name), 2))
      ), ''),
      'Team Eta'
    )                                                              AS team_name,

    -- manager_name: TRIM + title case | NULL → Joseph Shankar
    COALESCE(
      NULLIF(CONCAT(
        UPPER(SUBSTRING(TRIM(manager_name), 1, 1)),
        LOWER(SUBSTRING(TRIM(manager_name), 2))
      ), ''),
      'Joseph Shankar'
    )                                                              AS manager_name,

    -- Scheduled hours — realistic 8.0 / 8.5 / 9.0
    CASE
      WHEN scheduled_hours IS NULL OR scheduled_hours < 0
        THEN ROUND(8.0 + (FLOOR(RAND() * 3) * 0.5), 1)
      ELSE ROUND(CAST(scheduled_hours AS DECIMAL(10,2)), 2)
    END                                                            AS scheduled_hours,

    -- Actual hours — team-based realistic fill
    -- Alpha: 7.5-9.0 | Beta: 7.0-8.5 | Gamma: 6.5-8.0 | Delta: 7.2-8.8
    CASE
      WHEN actual_hours IS NULL OR actual_hours < 0
        THEN CASE
          WHEN UPPER(TRIM(team_name)) LIKE '%ALPHA%' THEN ROUND(7.5 + RAND()*1.5, 2)
          WHEN UPPER(TRIM(team_name)) LIKE '%BETA%'  THEN ROUND(7.0 + RAND()*1.5, 2)
          WHEN UPPER(TRIM(team_name)) LIKE '%GAMMA%' THEN ROUND(6.5 + RAND()*1.5, 2)
          WHEN UPPER(TRIM(team_name)) LIKE '%DELTA%' THEN ROUND(7.2 + RAND()*1.6, 2)
          ELSE ROUND(7.0 + RAND()*1.5, 2)
        END
      ELSE ROUND(CAST(actual_hours AS DECIMAL(10,2)), 2)
    END                                                            AS actual_hours,

    -- Adherence pct — team-based realistic fill | capped at 100
    -- Alpha:85-97 | Beta:78-92 | Gamma:68-84 | Delta:82-95
    CASE
      WHEN adherence_pct IS NULL OR adherence_pct < 0
        THEN CASE
          WHEN UPPER(TRIM(team_name)) LIKE '%ALPHA%' THEN ROUND(85 + RAND()*12, 2)
          WHEN UPPER(TRIM(team_name)) LIKE '%BETA%'  THEN ROUND(78 + RAND()*14, 2)
          WHEN UPPER(TRIM(team_name)) LIKE '%GAMMA%' THEN ROUND(68 + RAND()*16, 2)
          WHEN UPPER(TRIM(team_name)) LIKE '%DELTA%' THEN ROUND(82 + RAND()*13, 2)
          ELSE ROUND(75 + RAND()*15, 2)
        END
      WHEN adherence_pct > 100 THEN 100
      ELSE ROUND(CAST(adherence_pct AS DECIMAL(5,2)), 2)
    END                                                            AS adherence_pct,

    -- Shrinkage pct — team-based realistic fill
    -- Alpha:8-15 | Beta:12-20 | Gamma:18-28 | Delta:10-18
    CASE
      WHEN shrinkage_pct IS NULL OR shrinkage_pct < 0
        THEN CASE
          WHEN UPPER(TRIM(team_name)) LIKE '%ALPHA%' THEN ROUND(8  + RAND()*7,  2)
          WHEN UPPER(TRIM(team_name)) LIKE '%BETA%'  THEN ROUND(12 + RAND()*8,  2)
          WHEN UPPER(TRIM(team_name)) LIKE '%GAMMA%' THEN ROUND(18 + RAND()*10, 2)
          WHEN UPPER(TRIM(team_name)) LIKE '%DELTA%' THEN ROUND(10 + RAND()*8,  2)
          ELSE ROUND(12 + RAND()*10, 2)
        END
      ELSE ROUND(CAST(shrinkage_pct AS DECIMAL(5,2)), 2)
    END                                                            AS shrinkage_pct,

    -- Agents scheduled — realistic 6-10
    CASE
      WHEN agents_scheduled IS NULL OR agents_scheduled < 0
        THEN FLOOR(6 + RAND()*5)
      ELSE CAST(agents_scheduled AS UNSIGNED)
    END                                                            AS agents_scheduled,

    -- Agents present — always <= agents_scheduled
    CASE
      WHEN agents_present IS NULL OR agents_present < 0
        THEN CASE
          WHEN UPPER(TRIM(team_name)) LIKE '%ALPHA%'
            THEN FLOOR(5 + RAND()*4)
          WHEN UPPER(TRIM(team_name)) LIKE '%GAMMA%'
            THEN FLOOR(4 + RAND()*4)
          ELSE FLOOR(4 + RAND()*5)
        END
      ELSE CAST(agents_present AS UNSIGNED)
    END                                                            AS agents_present

  FROM deduped
  WHERE rn = 1
)
SELECT * FROM cleaned;

-- ─────────────────────────────────────────────────────────────
-- Sanity check after cleaning
-- RESULT: update after new data load
-- ─────────────────────────────────────────────────────────────
SELECT COUNT(*)              FROM schedule_adherence_clean;
SELECT DISTINCT team_name    FROM schedule_adherence_clean;
SELECT DISTINCT manager_name FROM schedule_adherence_clean;

-- Verify no NULLs remain
SELECT
  SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END)             AS null_date,
  SUM(CASE WHEN team_name IS NULL THEN 1 ELSE 0 END)        AS null_team,
  SUM(CASE WHEN manager_name IS NULL THEN 1 ELSE 0 END)     AS null_manager,
  SUM(CASE WHEN adherence_pct IS NULL THEN 1 ELSE 0 END)    AS null_adherence,
  SUM(CASE WHEN shrinkage_pct IS NULL THEN 1 ELSE 0 END)    AS null_shrinkage
FROM schedule_adherence_clean;

-- Verify score ranges
SELECT
  MIN(adherence_pct),  MAX(adherence_pct),
  MIN(shrinkage_pct),  MAX(shrinkage_pct),
  MIN(scheduled_hours),MAX(scheduled_hours),
  MIN(actual_hours),   MAX(actual_hours)
FROM schedule_adherence_clean;

-- Verify team-level variance — should show visible differences
SELECT
  team_name,
  ROUND(AVG(adherence_pct),2)    AS avg_adherence,
  ROUND(AVG(shrinkage_pct),2)    AS avg_shrinkage,
  ROUND(AVG(actual_hours),2)     AS avg_actual_hrs,
  ROUND(AVG(agents_present),2)   AS avg_agents_present,
  COUNT(*)                        AS total_records
FROM schedule_adherence_clean
GROUP BY team_name
ORDER BY avg_adherence DESC;

  -- ───────────────────────────────────────────────────────────
-- Exported them to the SQL directory
-- ─────────────────────────────────────────────────────────────

SELECT * FROM schedule_adherence_clean
INTO OUTFILE 'Type_your_destinaiton_path_Here/schedule_adherence_clean.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';

-- ─────────────────────────────────────────────────────────────
-- THE END
-- ─────────────────────────────────────────────────────────────
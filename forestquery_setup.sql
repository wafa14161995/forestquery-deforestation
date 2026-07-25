-- =====================================================================
-- ForestQuery / Deforestation Exploration -
--
-- =====================================================================

-- ---------------------------------------------------------------------
-- SECTION 1. Database
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS forestquery;
CREATE DATABASE forestquery;
USE forestquery;

SELECT DATABASE();   -- should return: forestquery


-- ---------------------------------------------------------------------
-- SECTION 2. Tables
-- Areas are DOUBLE and nullable - the source data has genuine gaps.
-- ---------------------------------------------------------------------
CREATE TABLE forest_area (
    country_code     VARCHAR(10),
    country_name     VARCHAR(100),
    year             INT,
    forest_area_sqkm DOUBLE NULL
);

CREATE TABLE land_area (
    country_code     VARCHAR(10),
    country_name     VARCHAR(100),
    year             INT,
    total_area_sq_mi DOUBLE NULL
);

CREATE TABLE regions (
    country_name  VARCHAR(100),
    country_code  VARCHAR(10),
    region        VARCHAR(100),
    income_group  VARCHAR(100)
);


-- ---------------------------------------------------------------------
-- SECTION 3. Enable local file loading
-- Server side. The client side is separate: connection settings ->
-- Advanced -> Others -> OPT_LOCAL_INFILE=1, then reconnect.
-- ---------------------------------------------------------------------
SET GLOBAL local_infile = 1;
SHOW GLOBAL VARIABLES LIKE 'local_infile';   -- Value should read ON


-- ---------------------------------------------------------------------
-- SECTION 4. Load the CSVs
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '/Users/wafa/Downloads/forest_area.csv'
INTO TABLE forest_area
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(country_code, country_name, year, @forest_area_sqkm)
SET forest_area_sqkm = NULLIF(@forest_area_sqkm, '');




LOAD DATA LOCAL INFILE '/Users/wafa/Downloads/land_area.csv'
INTO TABLE land_area
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(country_code, country_name, year, @total_area_sq_mi)
SET total_area_sq_mi = NULLIF(@total_area_sq_mi, '');

SHOW WARNINGS;


LOAD DATA LOCAL INFILE '/Users/wafa/Downloads/regions.csv'
INTO TABLE regions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(country_name, country_code, region, income_group);

SHOW WARNINGS;


-- ---------------------------------------------------------------------
-- SECTION 5. Sanity checks - do these before trusting any analysis
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS forest_rows FROM forest_area;   -- expect ~5900
SELECT COUNT(*) AS land_rows   FROM land_area;     -- expect ~5900
SELECT COUNT(*) AS region_rows FROM regions;       -- expect ~220

SELECT MIN(year) AS first_year, MAX(year) AS last_year FROM forest_area;

-- Eyeball a few rows: are the columns in the right places?
SELECT * FROM forest_area LIMIT 5;
SELECT * FROM regions     LIMIT 5;

-- How much data is genuinely missing?
SELECT SUM(forest_area_sqkm IS NULL) AS missing_forest FROM forest_area;
SELECT SUM(total_area_sq_mi IS NULL) AS missing_land   FROM land_area;

-- The World row must exist: you need it for global figures,
-- and you must EXCLUDE it when ranking regions.
SELECT * FROM regions WHERE country_name = 'World';



-- SECTION 7. Part 1 deliverable: the forestation view

-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW forestation AS
SELECT
    f.country_code,
    f.country_name,
    f.year,
    f.forest_area_sqkm,
    l.total_area_sq_mi,
    l.total_area_sq_mi * 2.59 AS total_area_sqkm,
    r.region,
    r.income_group,
    (f.forest_area_sqkm / (l.total_area_sq_mi * 2.59)) * 100 AS percent_forest
FROM forest_area AS f
JOIN land_area AS l
    ON f.country_code = l.country_code
   AND f.year         = l.year
JOIN regions AS r
    ON f.country_code = r.country_code;

SELECT * FROM forestation WHERE year = 2016 LIMIT 10;

-- SECTION 8.  GLOBAL SITUATION

-- ---------------------------------------------------------------------
/*1
a. What was the total forest area (in sq km) of the world in 1990?
   Please keep in mind that you can use the country record denoted as “World" in the region table.
   */

SELECT 
SUM(forest_area_sqkm)
FROM forestation 
WHERE year = 1990 AND region = 'World';
/*
1b. What was the total forest area (in sq km) of the world in 2016?
   Please keep in mind that you can use the country record in the table is denoted as “World.”

*/
SELECT 
SUM(forest_area_sqkm)
 FROM forestation 
WHERE year = 2016 AND region = 'World';
/*
1c. What was the change (in sq km) in the forest area of the world from 1990 to 2016?
*/
select 
(f1.forest_area_sqkm  - f2.forest_area_sqkm ) As  forest_area_change
from forestation f1
join forestation f2 
on
f1.country_name = f2.country_name  
Where f1.year ='1990' 
AND f2.year = '2016' 
AND f1.country_name ='World' ;
/*
1d. What was the percent change in forest area of the world between 1990 and 2016?
*/
select 
((f1.forest_area_sqkm  - f2.forest_area_sqkm )) *100/ (f1.forest_area_sqkm  )As  forest_area_prectentage 
from forestation f1
join forestation f2 
on
f1.country_name = f2.country_name  
Where f1.year ='1990' 
AND f2.year = '2016' 
AND f1.country_name ='World';
/*
1e. If you compare the amount of forest area lost between 1990 and 2016,
   to which country's total area in 2016 is it closest to?
*/

WITH loss AS (
    SELECT MAX(CASE WHEN year = 1990 THEN forest_area_sqkm END)
         - MAX(CASE WHEN year = 2016 THEN forest_area_sqkm END) AS forest_lost_sqkm
    FROM forestation
    WHERE country_name = 'World'
)
SELECT f.country_name,
       ROUND(f.total_area_sq_mi * 2.59, 2) AS total_area_sqkm,
       ROUND(ABS(f.total_area_sq_mi * 2.59 - l.forest_lost_sqkm), 2) AS diff_sqkm
FROM forestation f
CROSS JOIN loss l
WHERE f.year = 2016
  AND f.total_area_sq_mi IS NOT NULL
  AND f.region IS NOT NULL
  AND f.country_name != 'World'
ORDER BY diff_sqkm ASC
LIMIT 1;
-- SECTION 8.  REGIONAL OUTLOOK

-- ---------------------------------------------------------------------
/*2a. What was the percent forest of the entire world in 2016?
   Which region had the HIGHEST percent forest in 2016,
   and which had the LOWEST, to 2 decimal places?
*/
-- precent–-
SELECT forest_area_sqkm * 100 / total_area_sqkm
FROM forestation
WHERE year = 2016
AND country_name = 'World';

-- heighest–-
SELECT region,
ROUND(percent_forest , 2)
FROM
(SELECT region,
SUM(forest_area_sqkm)*100/SUM(total_area_sqkm) AS percent_forest
FROM forestation
WHERE year = 2016 and region != 'World'
GROUP BY 1 ) sub
ORDER BY 2 DESC 
LIMIT 1;
-- lowest–-
SELECT region,
ROUND(percent_forest , 2)
FROM
(SELECT region,
SUM(forest_area_sqkm)*100/SUM(total_area_sqkm) AS percent_forest
FROM forestation
WHERE year = 2016 and region != 'World'
GROUP BY 1 ) sub
ORDER BY 2 ASC 
LIMIT 1;
/*
2b. What was the percent forest of the entire world in 1990?
   Which region had the HIGHEST percent forest in 1990,
   and which had the LOWEST, to 2 decimal places?
   */
   
-- precent–-
SELECT forest_area_sqkm * 100 / total_area_sqkm
FROM forestation
WHERE year = 1990 
AND country_name = 'World';

-- heighest–-
SELECT region,
ROUND(percent_forest , 2)
FROM
(SELECT region,
SUM(forest_area_sqkm)*100/SUM(total_area_sqkm) AS percent_forest
FROM forestation
WHERE year = 1990 and region != 'World'
GROUP BY 1 ) sub
ORDER BY 2 DESC 
LIMIT 1;
-- lowest–-
SELECT region,
ROUND(percent_forest , 2)
FROM
(SELECT region,
SUM(forest_area_sqkm)*100/SUM(total_area_sqkm) AS percent_forest
FROM forestation
WHERE year = 1990 and region != 'World'
GROUP BY 1 ) sub
ORDER BY 2 ASC 
LIMIT 1;

/*2c. Based on the table you created, which regions of the world
    DECREASED in forest area from 1990 to 2016?
*/

WITH tb1 AS(SELECT 
region,
SUM(forest_area_sqkm) AS region_forest_sum_1990
FROM forestation
WHERE year = 1990 AND region != 'World'
GROUP BY region),
tb2 AS(SELECT 
region,
SUM(forest_area_sqkm) AS region_forest_sum_2016
FROM forestation
WHERE year = 2016  AND region !='World'
GROUP BY region)
SELECT 
tb1.region,
region_forest_sum_1990,
region_forest_sum_2016
from  tb1
join tb2
on tb1.region = tb2.region
where region_forest_sum_1990 > region_forest_sum_2016
;

-- Table --

WITH tb1 AS(
SELECT 
region,
SUM(forest_area_sqkm) AS region_forest_sum_1990,
SUM(total_area_sq_mi * 2.59) AS region_land_sum_1990
FROM forestation
WHERE year = 1990 
GROUP BY region),
tb2 AS(SELECT 
region,
SUM(forest_area_sqkm) AS region_forest_sum_2016,
SUM(total_area_sq_mi * 2.59) AS region_land_sum_2016
FROM forestation
WHERE year = 2016 
GROUP BY region)
SELECT 
tb1.region,
ROUND(region_forest_sum_1990 * 100.0 / region_land_sum_1990, 2) AS `1990 Forest Percentage`,
ROUND(region_forest_sum_2016 * 100.0 / region_land_sum_2016, 2) AS `2016 Forest Percentage`
from  tb1
join tb2
on tb1.region = tb2.region
order by `1990 Forest Percentage` desc
;
-- SECTION 9.  Country-Level Detail

/*
Which 5 countries saw the largest amount decrease in forest area from 1990 to 2016? What was the difference in forest area for each?

*/

WITH tb1 AS (
    SELECT country_name, region, forest_area_sqkm AS forest_1990
    FROM forestation
    WHERE year = 1990 AND region!= 'World'),
tb2 AS (
    SELECT country_name, forest_area_sqkm AS forest_2016
    FROM forestation
    WHERE year = 2016 AND region!= 'World')
SELECT DISTINCT tb1.country_name,
       tb1.region,
       ROUND(forest_1990 - forest_2016, 2) AS Absolute_Forest_Area_Change,
       ROUND(((forest_1990 - forest_2016)*100)/forest_1990, 2) AS decrese_precentage
FROM tb1
JOIN tb2 ON tb1.country_name = tb2.country_name
ORDER BY Absolute_Forest_Area_Change DESC
LIMIT 5;
/*
Which 5 countries saw the largest percent decrease in forest area from 1990 to 2016? What was the percent change to 2 decimal places for each?
*/

WITH tb1 AS (
    SELECT country_name, region, forest_area_sqkm AS forest_1990
    FROM forestation
    WHERE year = 1990 AND region!= 'World'),
tb2 AS (
    SELECT country_name, forest_area_sqkm AS forest_2016
    FROM forestation
    WHERE year = 2016 AND region!= 'World')
SELECT distinct tb1.country_name,
       tb1.region,
       ROUND(forest_1990 - forest_2016, 2) AS forest_loss_sqkm,
       ROUND(((forest_1990 - forest_2016)*100)/forest_1990, 2) AS decrese_precentage
FROM tb1
JOIN tb2 ON tb1.country_name = tb2.country_name
ORDER BY   decrese_precentage DESC
LIMIT 5;


/*
SUCCESS STORIES
*/

WITH tb1 AS(SELECT 
country_code,
country_name,
region,
forest_area_sqkm  AS forest_1990
FROM forestation
WHERE year = 1990 AND region !='World'),
tb2 AS (SELECT 
country_code,
forest_area_sqkm  AS forest_2016
FROM forestation
WHERE year = 2016  AND region !='World')
SELECT distinct
tb1.country_name,
ROUND(forest_1990,2) AS forest_1990,
ROUND(forest_2016,2) AS forest_2016,
ROUND(forest_2016 - forest_1990, 2) AS change_sqkm,
ROUND(((forest_2016 - forest_1990) / forest_1990) * 100, 2) AS pct_change
from tb1
join tb2
on tb1.country_code = tb2.country_code
where forest_1990 < forest_2016
order by change_sqkm desc
limit 5
;

/*
3b.Country with largest percent change in forest area from 1990 to 2016
*/
With tb1 AS
(SELECT country_name, year,forest_area_sqkm, total_area_sq_mi*2.59
  AS total_area_sqkm, percent_forest
FROM forestation
WHERE  (year='2016' AND region !='World'
        AND forest_area_sqkm !=0 AND total_area_sq_mi!=0)
ORDER BY percent_forest DESC),

tb2 AS
(SELECT tb1.country_name, tb1.year, tb1.percent_forest,
  CASE WHEN tb1.percent_forest > 75 THEN 4
  WHEN tb1.percent_forest <= 75 AND tb1.percent_forest > 50 THEN 3
  WHEN tb1.percent_forest <= 50 AND tb1.percent_forest > 25 THEN 2
  ELSE 1
  END AS percentile
  FROM tb1 
  ORDER BY 4 DESC)

SELECT 
tb2.percentile, COUNT(tb2.percentile) AS act
FROM tb2
GROUP BY tb2.percentile
ORDER BY act DESC;

/*
3c. If countries were grouped by percent forestation in quartiles,
which group had the most countries in it in 2016?
*/

SELECT  country_name, region, year,forest_area_sqkm, total_area_sq_mi*2.59 AS total_area_sqkm,
ROUND(percent_forest,2) AS percent
FROM forestation
WHERE  (year='2016' AND region!='World'
        AND forest_area_sqkm !=0 AND total_area_sq_mi!=0)
        AND percent_forest > 75
ORDER BY percent_forest DESC
limit 10;
/*
3e.How many countries had a percent forestation higher than the United States in 2016?
*/

With tb1 AS
(SELECT country_name, year,forest_area_sqkm, total_area_sq_mi*2.59
  AS total_area_sqkm, percent_forest
  FROM forestation
  WHERE  (year='2016' AND region!='World'
        AND forest_area_sqkm !=0 AND total_area_sq_mi!=0)
  ORDER BY percent_forest DESC)

SELECT COUNT(tb1.country_name)
FROM tb1
WHERE tb1.percent_forest > (SELECT tb1.percent_forest
  FROM tb1
  WHERE tb1.country_name = 'United States');


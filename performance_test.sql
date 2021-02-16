DROP TABLE IF EXISTS performance_test;

CREATE TABLE performance_test AS
SELECT
  subjects.subject,
  patterns.pattern,
  tests.is_match,
  tests.captured
FROM tests
JOIN subjects ON subjects.subject_id = tests.subject_id
JOIN patterns ON patterns.pattern_id = subjects.pattern_id
JOIN server_versions ON server_versions.server_version_num = tests.server_version_num
WHERE server_versions.server_version = current_setting('server_version')
AND tests.error IS NULL
;

\timing

SELECT now();

SELECT
  is_match <> (subject ~ pattern),
  captured IS DISTINCT FROM regexp_match(subject, pattern),
  COUNT(*)
FROM performance_test
GROUP BY 1,2
ORDER BY 1,2
;

SELECT now();

CREATE TABLE very_long_patterns AS
SELECT * FROM performance_test
WHERE pattern ~ '[a-zA-Z0-9_]{16,}';

SELECT
  is_match <> (subject ~ pattern),
  captured IS DISTINCT FROM regexp_match(subject, pattern),
  COUNT(*)
FROM very_long_patterns
GROUP BY 1,2
ORDER BY 1,2
;

/*

joel=# select version();
                                                       version
----------------------------------------------------------------------------------------------------------------------
 PostgreSQL 14devel on x86_64-apple-darwin20.2.0, compiled by Apple clang version 12.0.0 (clang-1200.0.32.29), 64-bit
(1 row)

 ?column? | ?column? |  count
----------+----------+---------
 f        | f        | 1448212
(1 row)

HEAD  570632.722 ms (09:30.633)
+0001 472938.857 ms (07:52.939) 17% better than HEAD
+0002 451638.049 ms (07:31.638) 20% better than HEAD
+0003 439377.813 ms (07:19.378) 23% better than HEAD
+0004 96447.038 ms (01:36.447) 83% better than HEAD

*/
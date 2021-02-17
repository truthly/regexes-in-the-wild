\timing
SELECT version();
SELECT
  is_match <> (subject ~ pattern) AS is_match_diff,
  captured IS DISTINCT FROM regexp_match(subject, pattern, flags) AS captured_diff,
  COUNT(*)
FROM performance_test
GROUP BY 1,2
ORDER BY 1,2
;

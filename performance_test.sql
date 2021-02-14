\timing

SELECT
  tests.is_match IS NOT DISTINCT FROM (subjects.subject ~ patterns.pattern),
  tests.captured IS NOT DISTINCT FROM regexp_match(subjects.subject, patterns.pattern),
  COUNT(*)
FROM tests
JOIN subjects ON subjects.subject_id = tests.subject_id
JOIN patterns ON patterns.pattern_id = subjects.pattern_id
JOIN server_versions ON server_versions.server_version_num = tests.server_version_num
WHERE server_versions.server_version = current_setting('server_version')
AND tests.error IS NULL
GROUP BY 1,2
ORDER BY 1,2;

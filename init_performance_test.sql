DROP TABLE IF EXISTS performance_test;

CREATE TABLE performance_test AS
SELECT
  subjects.subject,
  patterns.pattern,
  patterns.flags,
  tests.is_match,
  tests.captured
FROM tests
JOIN subjects ON subjects.subject_id = tests.subject_id
JOIN patterns ON patterns.pattern_id = subjects.pattern_id
WHERE tests.error IS NULL
;

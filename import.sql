BEGIN;

\COPY import_log FROM PSTDIN WITH DELIMITER ',' NULL '';

INSERT INTO decoded
  (pattern_bytes, subject_bytes, flags)
SELECT
  decode(pattern_base64,'base64'),
  decode(subject_base64,'base64'),
  COALESCE(flags,'')
FROM import_log
WHERE subject_base64 IS NOT NULL;

DELETE FROM decoded
WHERE (position('\xed' in pattern_bytes) > 0 AND pattern_bytes::text ~ '^\\x([0-9a-f]{2})*ed[^89]')
   OR (position('\xed' in subject_bytes) > 0 AND subject_bytes::text ~ '^\\x([0-9a-f]{2})*ed[^89]')
   OR (position('\xe0' in pattern_bytes) > 0 AND pattern_bytes::text ~ '^\\x([0-9a-f]{2})*e0[^ab]')
   OR (position('\xe0' in subject_bytes) > 0 AND subject_bytes::text ~ '^\\x([0-9a-f]{2})*e0[^ab]')
;

UPDATE decoded SET
  pattern = convert_from(pattern_bytes,'utf8'),
  subject = convert_from(subject_bytes,'utf8')
;

INSERT INTO agg_patterns
  (pattern, pattern_hash, flags, count)
  SELECT
      pattern,
      sha512(pattern_bytes) AS pattern_hash,
      flags,
      COUNT(*)
  FROM decoded
  GROUP BY 1,2,3
;

UPDATE patterns
SET count = patterns.count + agg_patterns.count
FROM agg_patterns
WHERE agg_patterns.pattern_hash = patterns.pattern_hash
  AND agg_patterns.flags        = patterns.flags;

INSERT INTO patterns (pattern, pattern_hash, flags, count)
SELECT pattern, pattern_hash, flags, count
FROM agg_patterns
WHERE NOT EXISTS
(
  SELECT 1 FROM patterns AS p
  WHERE p.pattern_hash = agg_patterns.pattern_hash
    AND p.flags        = agg_patterns.flags
);

INSERT INTO agg_subjects
  (pattern_id, subject, subject_hash, count)
SELECT
  patterns.pattern_id,
  decoded.subject,
  sha512(decoded.subject_bytes),
  COUNT(*)
FROM decoded
JOIN patterns
  ON patterns.pattern_hash = sha512(decoded.pattern_bytes)
 AND patterns.flags        = decoded.flags
GROUP BY 1,2,3;

UPDATE subjects
SET count = subjects.count + agg_subjects.count
FROM agg_subjects
WHERE subjects.pattern_id   = agg_subjects.pattern_id
  AND subjects.subject_hash = agg_subjects.subject_hash;

INSERT INTO subjects (pattern_id, subject, subject_hash, count)
SELECT
  agg_subjects.pattern_id,
  agg_subjects.subject,
  agg_subjects.subject_hash,
  agg_subjects.count
FROM agg_subjects
WHERE NOT EXISTS
(
  SELECT 1 FROM subjects AS s
  WHERE s.pattern_id   = agg_subjects.pattern_id
    AND s.subject_hash = agg_subjects.subject_hash
);

TRUNCATE import_log, decoded, agg_patterns, agg_subjects;

COMMIT;

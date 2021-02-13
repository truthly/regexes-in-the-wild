--
-- after init.sql has been run on HEAD,
-- recompile PostgreSQL with the patch to test,
-- then run this script to check if there are
-- any cases that gives a different result
--
\timing
\x
SELECT
  pattern,
  subject,
  is_match AS is_match_head,
  captured AS captured_head,
  subject ~ pattern AS is_match_patch,
  regexp_match(subject, pattern) AS captured_patch
FROM subjects
WHERE error IS NULL
AND (is_match <> (subject ~ pattern) OR captured IS DISTINCT FROM regexp_match(subject, pattern))
;

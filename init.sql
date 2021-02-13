\timing

DROP TABLE IF EXISTS import_log, patterns, subjects;

CREATE TABLE import_log (
source text NOT NULL,
pattern text NOT NULL,
subject text,
flags text
);

CREATE TABLE patterns (
pattern_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
pattern text NOT NULL,
flags text NOT NULL,
count bigint NOT NULL,
PRIMARY KEY (pattern_id)
);

CREATE TABLE subjects (
subject_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
pattern text NOT NULL,
subject text NOT NULL,
count bigint NOT NULL,
is_match boolean,
captured text[],
error text,
PRIMARY KEY (subject_id)
);

\COPY import_log FROM 'regex.csv' WITH DELIMITER ',' NULL '';

ALTER TABLE import_log ADD COLUMN pattern_bytes bytea;
ALTER TABLE import_log ADD COLUMN subject_bytes bytea;

UPDATE import_log SET
  pattern_bytes = decode(pattern,'base64'),
  subject_bytes = decode(subject,'base64')
;

DELETE FROM import_log
WHERE (position('\xed' in pattern_bytes) > 0 AND pattern_bytes::text ~ '^\\x([0-9a-f]{2})*ed[^89]')
   OR (position('\xed' in subject_bytes) > 0 AND subject_bytes::text ~ '^\\x([0-9a-f]{2})*ed[^89]')
;

DELETE FROM import_log
WHERE (position('\xe0' in pattern_bytes) > 0 AND pattern_bytes::text ~ '^\\x([0-9a-f]{2})*e0[^ab]')
   OR (position('\xe0' in subject_bytes) > 0 AND subject_bytes::text ~ '^\\x([0-9a-f]{2})*e0[^ab]')
;

UPDATE import_log SET
  pattern = convert_from(pattern_bytes,'utf8'),
  subject = convert_from(subject_bytes,'utf8'),
  flags = COALESCE(flags,'')
;

INSERT INTO patterns (pattern, flags, count)
SELECT
    pattern,
    flags,
    COUNT(*)
FROM import_log
GROUP BY pattern, flags;

INSERT INTO subjects (pattern, subject, count)
SELECT
    pattern,
    subject,
    COUNT(*)
FROM import_log
WHERE subject IS NOT NULL
GROUP BY pattern, subject;

CREATE OR REPLACE PROCEDURE process_regexes()
LANGUAGE plpgsql
AS $$
DECLARE
_count_subjects bigint;
_subject_id bigint;
_pattern text;
_subject text;
_is_match boolean;
_captured text[];
_i bigint := 0;
_t0 double precision;
BEGIN
_t0 := extract(epoch from clock_timestamp());
SELECT COUNT(*) INTO _count_subjects FROM subjects;
FOR
  _subject_id,
  _pattern,
  _subject
IN
SELECT
  subject_id,
  pattern,
  subject
FROM subjects
ORDER BY subject_id
LOOP
  BEGIN
    _is_match := _subject ~ _pattern;
    _captured := regexp_match(_subject, _pattern);
  EXCEPTION WHEN OTHERS THEN
    UPDATE subjects SET
      error = SQLERRM
    WHERE subject_id = _subject_id;
    CONTINUE;
  END;
  UPDATE subjects SET
    is_match = _is_match,
    captured = _captured
  WHERE subject_id = _subject_id;
  _i := _i + 1;
  IF _i % 1000 = 0 THEN
    RAISE NOTICE '% %% (%/%) ETA %',
      ROUND(_i::numeric/_count_subjects*100,2),
      _i,
      _count_subjects,
      format('%s s', (extract(epoch from clock_timestamp()) - _t0) * (1.0 / (_i::numeric / _count_subjects) - 1.0))::interval;
    COMMIT;
  END IF;
END LOOP;
RETURN;
END
$$;

CALL process_regexes();


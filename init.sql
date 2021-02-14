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
pattern_id bigint NOT NULL REFERENCES patterns,
subject text NOT NULL,
count bigint NOT NULL,
PRIMARY KEY (subject_id)
);

CREATE TABLE server_versions (
server_version_num integer NOT NULL,
server_version text NOT NULL,
PRIMARY KEY (server_version_num),
UNIQUE (server_version)
);

CREATE TABLE tests (
test_id uuid NOT NULL DEFAULT gen_random_uuid(),
subject_id bigint NOT NULL REFERENCES subjects,
server_version_num integer REFERENCES  server_versions,
duration interval NOT NULL,
is_match boolean,
captured text[],
error text,
PRIMARY KEY (test_id),
UNIQUE (subject_id, server_version_num)
);

ALTER TABLE tests RENAME COLUMN test_id TO test_id_bigint;
ALTER TABLE tests ADD COLUMN test_id uuid NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE tests DROP CONSTRAINT "tests_pkey";
ALTER TABLE tests ADD PRIMARY KEY (test_id);

CREATE TABLE deviations (
deviation_id uuid NOT NULL DEFAULT gen_random_uuid(),
test_id uuid NOT NULL REFERENCES tests,
duration interval NOT NULL,
is_match boolean,
captured text[],
error text,
PRIMARY KEY (deviation_id)
);

CREATE VIEW vtests AS
SELECT
tests.test_id,
tests.subject_id,
tests.duration,
tests.is_match,
cardinality(tests.captured) AS cardinality,
hash_array(tests.captured) AS hash,
tests.error,
ARRAY[length(patterns.pattern),length(subjects.subject)] AS lengths,
format('%L ~ %L',LEFT(subjects.subject,40), LEFT(patterns.pattern,40)) AS expr
FROM tests
JOIN subjects ON subjects.subject_id = tests.subject_id
JOIN patterns ON patterns.pattern_id = subjects.pattern_id
;


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

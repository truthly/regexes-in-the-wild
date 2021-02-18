\timing

--
-- polyfill for gen_random_uuid() for PostgreSQL versions <13
--
DO $_$
BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'gen_random_uuid') THEN
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  CREATE FUNCTION gen_random_uuid()
  RETURNS uuid
  LANGUAGE sql
  AS $$
  SELECT uuid_generate_v4()
  $$;
END IF;
END
$_$;

CREATE TABLE import_log (
source text NOT NULL,
pattern_base64 text NOT NULL,
subject_base64 text,
flags text
);

CREATE TABLE decoded (
pattern_bytes bytea NOT NULL,
subject_bytes bytea NOT NULL,
flags text NOT NULL,
pattern text,
subject text
);

CREATE TABLE agg_patterns (
pattern text NOT NULL,
pattern_hash bytea NOT NULL,
flags text NOT NULL,
count bigint NOT NULL,
PRIMARY KEY (pattern_hash, flags)
);

CREATE TABLE agg_subjects (
pattern_id bigint NOT NULL,
subject text NOT NULL,
subject_hash bytea NOT NULL,
count bigint NOT NULL,
PRIMARY KEY (subject_hash, pattern_id)
);

CREATE TABLE patterns (
pattern_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
pattern text NOT NULL,
pattern_hash bytea NOT NULL,
flags text NOT NULL,
count bigint NOT NULL,
PRIMARY KEY (pattern_id),
UNIQUE (pattern_hash, flags)
);

CREATE VIEW vpatterns AS
SELECT
pattern,
flags,
count
FROM patterns;

CREATE TABLE subjects (
subject_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
pattern_id bigint NOT NULL REFERENCES patterns,
subject text NOT NULL,
subject_hash bytea NOT NULL,
count bigint NOT NULL,
PRIMARY KEY (subject_id),
UNIQUE (subject_hash, pattern_id)
);

CREATE VIEW vsubjects AS
SELECT
patterns.pattern,
patterns.flags,
subjects.subject,
subjects.count
FROM patterns
JOIN subjects ON subjects.pattern_id = patterns.pattern_id;


CREATE TABLE server_versions (
server_version_num integer NOT NULL,
server_version text NOT NULL,
PRIMARY KEY (server_version_num),
UNIQUE (server_version)
);

CREATE TABLE tests (
test_id uuid NOT NULL DEFAULT gen_random_uuid(),
subject_id bigint NOT NULL REFERENCES subjects,
server_version_num integer REFERENCES server_versions,
duration interval NOT NULL,
is_match boolean,
captured text[],
error text,
PRIMARY KEY (test_id),
UNIQUE (subject_id, server_version_num)
);

CREATE VIEW vtests AS
SELECT
patterns.pattern,
patterns.flags,
subjects.subject,
subjects.count,
server_versions.server_version AS test_server_version,
tests.duration,
tests.is_match,
tests.captured,
tests.error
FROM tests
JOIN subjects ON subjects.subject_id = tests.subject_id
JOIN patterns ON patterns.pattern_id = subjects.pattern_id
JOIN server_versions ON server_versions.server_version_num = tests.server_version_num;

CREATE TABLE deviations (
deviation_id uuid NOT NULL DEFAULT gen_random_uuid(),
test_id uuid NOT NULL REFERENCES tests,
server_version_num integer REFERENCES server_versions,
duration interval NOT NULL,
is_match boolean,
captured text[],
error text,
PRIMARY KEY (deviation_id)
);

CREATE OR REPLACE FUNCTION shrink_text(text,integer) RETURNS text LANGUAGE sql AS $$
SELECT CASE WHEN length($1) < $2 THEN $1 ELSE
  format('%s ... %s chars ... %s', m[1], length(m[2]), m[3])
END
FROM (
  SELECT regexp_matches($1,format('^(.{1,%1$s})(.*?)(.{1,%1$s})$',$2/2)) AS m
) AS q
$$;

CREATE VIEW vdeviations AS
SELECT
shrink_text(patterns.pattern,80) AS pattern,
patterns.flags,
shrink_text(subjects.subject,80) AS subject,
subjects.count,
test_server_version.server_version AS a_server_version,
tests.duration AS a_duration,
tests.is_match AS a_is_match,
tests.captured AS a_captured,
tests.error AS a_error,
deviation_server_version.server_version AS b_server_version,
deviations.duration AS b_duration,
deviations.is_match AS b_is_match,
deviations.captured AS b_captured,
deviations.error AS b_error
FROM deviations
JOIN tests ON tests.test_id = deviations.test_id
JOIN subjects ON subjects.subject_id = tests.subject_id
JOIN patterns ON patterns.pattern_id = subjects.pattern_id
JOIN server_versions AS deviation_server_version ON deviation_server_version.server_version_num = deviations.server_version_num
JOIN server_versions AS test_server_version ON test_server_version.server_version_num = tests.server_version_num;

CREATE VIEW vstats AS
SELECT
  (SELECT COUNT(*) FROM patterns) AS patterns,
  (SELECT COUNT(*) FROM subjects) AS subjects
;

  
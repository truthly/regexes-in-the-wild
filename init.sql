\timing

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

CREATE TABLE subjects (
subject_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
pattern_id bigint NOT NULL REFERENCES patterns,
subject text NOT NULL,
subject_hash bytea NOT NULL,
count bigint NOT NULL,
PRIMARY KEY (subject_id),
UNIQUE (subject_hash, pattern_id)
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

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
PRIMARY KEY (subject_id)
);

COPY import_log FROM '/home/regex/regex.csv' WITH DELIMITER ',' NULL '';

UPDATE import_log SET
  pattern = convert_from(decode(pattern,'base64'),'utf8'),
  subject = convert_from(decode(subject,'base64'),'utf8'),
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

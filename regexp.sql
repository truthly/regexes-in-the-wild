CREATE TABLE import_log (
source text NOT NULL,
pattern text NOT NULL,
subject text,
flags text
);

CREATE TABLE regexes (
regex_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
domain_name text NOT NULL,
pattern text NOT NULL,
subject text,
flags text,
PRIMARY KEY (regex_id)
);

CREATE OR REPLACE FUNCTION process_regexes(domain_name text)
RETURNS void
LANGUAGE sql
AS $$
TRUNCATE import_log;
COPY import_log FROM '/tmp/regexes.csv' WITH DELIMITER ',' NULL '';
INSERT INTO regexes (domain_name, pattern, subject, flags)
SELECT DISTINCT
    $1,
    convert_from(decode(pattern,'base64'),'utf8'),
    convert_from(decode(subject,'base64'),'utf8'),
    Flags
FROM import_log;
TRUNCATE import_log;
$$;

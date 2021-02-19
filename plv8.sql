CREATE EXTENSION IF NOT EXISTS plv8;

CREATE OR REPLACE FUNCTION regexp_match_v8(subject text, pattern text, flags text)
RETURNS text[]
LANGUAGE plv8 AS
$$
return subject.match(new RegExp(pattern, flags));
$$;

CREATE OR REPLACE FUNCTION regexp_test_v8(subject text, pattern text, flags text)
RETURNS boolean
LANGUAGE plv8 AS
$$
let regex = new RegExp(pattern, flags);
return regex.test(subject);
$$;



CREATE OR REPLACE FUNCTION create_regexp_tests_v8()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
_count_subjects bigint;
_subject_id bigint;
_pattern text;
_subject text;
_flags text;
_is_match boolean;
_captured text[];
_error text;
_i bigint := 0;
_t0 constant double precision := extract(epoch from clock_timestamp());
_server_version_num constant integer := regexp_replace(plv8_version(),'[^0-9]+','','g')::integer;
_server_version constant text := format('PL/v8 version %s',plv8_version());
_t timestamptz;
_duration interval;
_test_id uuid;
_min_log_duration constant interval := '500 ms'::interval;
BEGIN
IF EXISTS
(
  SELECT 1 FROM server_versions
  WHERE server_version_num = _server_version_num
) THEN
  RAISE NOTICE 'Tests already created for server version %', _server_version USING HINT = 'CALL verify_regexes() instead';
  RETURN;
ELSE
  INSERT INTO server_versions
    (server_version_num, server_version)
  VALUES
    (_server_version_num, _server_version);
END IF;
SELECT COUNT(*) INTO _count_subjects FROM subjects;
FOR
  _subject_id,
  _pattern,
  _subject,
  _flags
IN
SELECT
  subjects.subject_id,
  patterns.pattern,
  subjects.subject,
  patterns.flags
FROM subjects
JOIN patterns ON patterns.pattern_id = subjects.pattern_id
ORDER BY subjects.subject_id
LOOP
  _is_match := NULL;
  _captured := NULL;
  _error    := NULL;
  _t        := clock_timestamp();
  BEGIN
    _is_match := regexp_test_v8(_subject, _pattern, '');
    _captured := regexp_match_v8(_subject, _pattern, _flags);
  EXCEPTION WHEN OTHERS THEN
    _error := SQLERRM;
  END;
  _duration := clock_timestamp() - _t;
  INSERT INTO tests
    (subject_id, server_version_num, duration, is_match, captured, error)
  VALUES
    (_subject_id, _server_version_num, _duration, _is_match, _captured, _error)
  RETURNING test_id INTO STRICT _test_id;
  IF _duration > _min_log_duration THEN
    RAISE NOTICE E'test_id % took %', _test_id, _duration;
  END IF;
  _i := _i + 1;
  IF _i % 10000 = 0 THEN
    RAISE NOTICE '% %% (%/%) ETA %',
      ROUND(_i::numeric/_count_subjects*100,2),
      _i,
      _count_subjects,
      format('%s s', (extract(epoch from clock_timestamp()) - _t0) * (1.0 / (_i::numeric / _count_subjects) - 1.0))::interval;
  END IF;
END LOOP;
RETURN;
END
$$;

CREATE OR REPLACE FUNCTION verify_regexp_tests_v8()
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
_subject_id bigint;
_pattern text;
_subject text;
_a_is_match boolean;
_a_captured text[];
_a_error text;
_b_is_match boolean;
_b_captured text[];
_b_error text;
_i bigint := 0;
_t0 constant double precision := extract(epoch from clock_timestamp());
_t timestamptz;
_duration interval;
_min_log_duration constant interval := '500 ms'::interval;
_deviations bigint := 0;
_count_subjects bigint;
BEGIN
SELECT COUNT(*) INTO _count_subjects FROM subjects;
FOR
  _subject_id,
  _pattern,
  _subject
IN
SELECT
  subjects.subject_id,
  patterns.pattern,
  subjects.subject
FROM subjects
JOIN patterns ON patterns.pattern_id = subjects.pattern_id
ORDER BY subjects.subject_id
LOOP
  _a_is_match := NULL;
  _a_captured := NULL;
  _a_error    := NULL;
  _b_is_match := NULL;
  _b_captured := NULL;
  _b_error    := NULL;
  _t          := clock_timestamp();
  BEGIN
    _a_is_match := _subject ~ _pattern;
    _a_captured := regexp_match(_subject, _pattern, '');
  EXCEPTION WHEN OTHERS THEN
    _a_error := SQLERRM;
  END;
  BEGIN
    _b_is_match := regexp_test_v8(_subject, _pattern, '');
    _b_captured := regexp_match_v8(_subject, _pattern, '');
  EXCEPTION WHEN OTHERS THEN
    _b_error := SQLERRM;
  END;
  --
  -- In Javascript, the matches string is always returned
  -- in the first element, whereas in PostgreSQL only
  -- when there are no capture groups.
  --
  -- Normalize by ignoring the first element if there is
  -- exactly one extra. This also gives the side-effect
  -- that a difference where Javascript for other reasons
  -- would produce an extra capture group will go undetected,
  -- but I cannot see any obvious other simple way to fix this.
  --
  IF cardinality(_b_captured) = cardinality(_a_captured)+1 THEN
    _b_captured := _b_captured[2:];
  END IF;
  _duration := clock_timestamp() - _t;
  IF _a_is_match IS DISTINCT FROM _b_is_match
  OR _a_captured IS DISTINCT FROM _b_captured
  OR (_a_error IS NULL) <> (_b_error IS NULL)
  THEN
    RAISE WARNING E'deviation detected, subject_id %\nsubject: %\npattern: %\nis_match % => %\ncaptured % => %\nerror % => %',
      _subject_id, _subject, _pattern, _a_is_match, _b_is_match, _a_captured, _b_captured, _a_error, _b_error;
    _deviations := _deviations + 1;
  END IF;
  IF _duration > _min_log_duration THEN
    RAISE NOTICE E'subject_id % took %', _subject_id, _duration;
  END IF;
  _i := _i + 1;
  IF _i % 10000 = 0 THEN
    RAISE NOTICE '% %% (%/%) ETA %, % deviations',
      ROUND(_i::numeric/_count_subjects*100,2),
      _i,
      _count_subjects,
      format('%s s', (extract(epoch from clock_timestamp()) - _t0) * (1.0 / (_i::numeric / _count_subjects) - 1.0))::interval,
      _deviations;
  END IF;
END LOOP;
RETURN _deviations = 0;
END
$$;

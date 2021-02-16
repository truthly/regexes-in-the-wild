CREATE OR REPLACE FUNCTION create_regexp_tests()
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
_server_version_num constant integer := current_setting('server_version_num')::integer;
_server_version constant text := current_setting('server_version');
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
    _is_match := _subject ~ _pattern;
    _captured := regexp_match(_subject, _pattern, _flags);
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

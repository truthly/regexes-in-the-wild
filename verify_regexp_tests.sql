CREATE OR REPLACE FUNCTION verify_regexp_tests(_server_version text DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
_count_tests bigint;
_subject_id bigint;
_pattern text;
_subject text;
_flags text;
_is_match boolean;
_captured text[];
_error text;
_expected_is_match boolean;
_expected_captured text[];
_expected_error text;
_i bigint := 0;
_t0 constant double precision := extract(epoch from clock_timestamp());
_t timestamptz;
_duration interval;
_test_id uuid;
_min_log_duration constant interval := '500 ms'::interval;
_server_version_num integer;
_current_server_version_num constant integer := current_setting('server_version_num')::integer;
_deviations bigint := 0;
BEGIN
IF _server_version IS NULL THEN
  _server_version := current_setting('server_version');
ELSE
  RAISE NOTICE 'Comparing PostgreSQL version % with %', _server_version, current_setting('server_version');
END IF;
SELECT server_version_num
INTO _server_version_num
FROM server_versions
WHERE server_version = _server_version;
IF NOT FOUND THEN
  RAISE NOTICE 'Tests not yet created for server version %', _server_version USING HINT = 'CALL create_regexp_tests() instead';
  RETURN FALSE;
END IF;

IF NOT EXISTS
(
  SELECT 1 FROM server_versions
  WHERE server_version_num = _current_server_version_num
) THEN
  INSERT INTO server_versions
    (server_version_num, server_version)
  VALUES
    (_current_server_version_num, current_setting('server_version'));
END IF;

SELECT COUNT(*) INTO _count_tests FROM tests WHERE server_version_num = _server_version_num;
FOR
  _test_id,
  _pattern,
  _subject,
  _flags,
  _expected_is_match,
  _expected_captured,
  _expected_error
IN
SELECT
  tests.test_id,
  patterns.pattern,
  subjects.subject,
  patterns.flags,
  tests.is_match,
  tests.captured,
  tests.error
FROM tests
JOIN subjects ON subjects.subject_id = tests.subject_id
JOIN patterns ON patterns.pattern_id = subjects.pattern_id
WHERE tests.server_version_num = _server_version_num
ORDER BY tests.test_id
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
  IF _is_match IS DISTINCT FROM _expected_is_match
  OR _captured IS DISTINCT FROM _expected_captured
  OR (_error IS NULL) <> (_expected_error IS NULL)
  THEN
    RAISE WARNING E'deviation detected, test_id %\nis_match % => %\ncaptured % => %\nerror % => %',
      _test_id, _expected_is_match, _is_match, _expected_captured, _captured, _expected_error, _error;
    INSERT INTO deviations
      (test_id, server_version_num, duration, is_match, captured, error)
    VALUES
      (_test_id, _current_server_version_num, _duration, _is_match, _captured, _error);
    _deviations := _deviations + 1;
  END IF;
  IF _duration > _min_log_duration THEN
    RAISE NOTICE E'test_id % took %', _test_id, _duration;
  END IF;
  _i := _i + 1;
  IF _i % 10000 = 0 THEN
    RAISE NOTICE '% %% (%/%) ETA %, % deviations',
      ROUND(_i::numeric/_count_tests*100,2),
      _i,
      _count_tests,
      format('%s s', (extract(epoch from clock_timestamp()) - _t0) * (1.0 / (_i::numeric / _count_tests) - 1.0))::interval,
      _deviations;
  END IF;
END LOOP;
RETURN _deviations = 0;
END
$$;

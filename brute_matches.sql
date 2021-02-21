CREATE OR REPLACE FUNCTION r(from_byte bit(8), to_byte bit(8))
RETURNS text
LANGUAGE sql AS $$
SELECT lpad(to_hex(from_byte::integer + floor(random() * (to_byte::integer - from_byte::integer + 1))::integer),2,'0')
$$;

CREATE OR REPLACE FUNCTION rand_char()
RETURNS text
LANGUAGE sql
AS $$
-- Valid UTF-8 byte ranges copied from:
-- https://lemire.me/blog/2018/05/09/how-quickly-can-you-check-that-a-string-is-valid-unicode-utf-8/
SELECT convert_from(decode(CASE floor(random()*9)::integer
WHEN 0 THEN r(x'01',x'7f')
WHEN 1 THEN r(x'c2',x'df')||r(x'80',x'bf')
WHEN 2 THEN r(x'e0',x'e0')||r(x'a0',x'bf')||r(x'80',x'bf')
WHEN 3 THEN r(x'e1',x'ec')||r(x'80',x'bf')||r(x'80',x'bf')
WHEN 4 THEN r(x'ed',x'ed')||r(x'80',x'9f')||r(x'80',x'bf')
WHEN 5 THEN r(x'ee',x'ef')||r(x'80',x'bf')||r(x'80',x'bf')
WHEN 6 THEN r(x'f0',x'f0')||r(x'90',x'bf')||r(x'80',x'bf')||r(x'80',x'bf')
WHEN 7 THEN r(x'f1',x'f3')||r(x'80',x'bf')||r(x'80',x'bf')||r(x'80',x'bf')
WHEN 8 THEN r(x'f4',x'f4')||r(x'80',x'8f')||r(x'80',x'bf')||r(x'80',x'bf')
END,'hex'),'utf8')
$$;

CREATE OR REPLACE FUNCTION regexp_match_null_on_error(subject text, pattern text)
RETURNS text[]
LANGUAGE plpgsql AS
$$
BEGIN
  RETURN regexp_match(subject, pattern);
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END
$$;

CREATE OR REPLACE FUNCTION brute_matches(
regex text,
engine text DEFAULT 'pg',
only_ascii boolean DEFAULT TRUE,
tests bigint DEFAULT 100000
)
RETURNS text
LANGUAGE plpgsql
AS
$$
DECLARE
c text;
result text;
cp integer;
cps integer[] := ARRAY[]::integer[];
deduced_bracket_expression text;
BEGIN
cps := ARRAY[]::integer[];
FOR i IN 1..tests LOOP
  IF only_ascii THEN
    c := chr(1+floor(random()*255)::integer);
  ELSE
    c := rand_char();
  END IF;
  cp := ascii(c);
  IF engine = 'pg' THEN
    result := (regexp_match_null_on_error(c, regex))[1];
  ELSIF engine = 'v8' THEN
    result := (regexp_match_v8(c, regex, ''))[2];
  ELSIF engine = 'pl' THEN
    result := (regexp_match_pl(c, regex, ''))[1];
  ELSE
    RAISE EXCEPTION 'unsupported regex engine %', engine;
  END IF;
  IF (regexp_match_null_on_error(c, regex))[1] = c
  AND NOT cp = ANY(cps)
  THEN
    cps := cps || cp;
  END IF;
END LOOP;
SELECT format('[%s]',string_agg(CASE WHEN MIN=MAX THEN chr(MIN) ELSE format('%s-%s',chr(MIN),chr(MAX)) END,'' ORDER BY MIN))
INTO deduced_bracket_expression
FROM
(
  SELECT
    MIN(unnest),
    MAX(unnest)
  FROM
  (
    SELECT
      unnest,
      unnest-ROW_NUMBER() OVER (ORDER BY unnest) AS gap
    FROM
    (
      SELECT DISTINCT unnest FROM unnest(cps)
    ) AS q0
  ) AS q1
  GROUP BY gap
) AS q2;
RETURN deduced_bracket_expression;
END
$$;

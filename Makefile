EXTENSION = regexes_in_the_wild
DATA = regexes_in_the_wild--1.0.sql

REGRESS = test
EXTRA_CLEAN = regexes_in_the_wild--1.0.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

all: regexes_in_the_wild--1.0.sql

SQL_SRC = \
  complain_header.sql

regexes_in_the_wild--1.0.sql: $(SQL_SRC)
	cat $^ > $@

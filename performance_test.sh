#!/bin/sh
for port in {5432,5412,5411,5410,5496} ; do \
psql -p "$port" -f init_performance_test.sql ; \
done

for port in {5432,5412,5411,5410,5496} ; do \
for n in {1..3} ; do \
psql -p "$port" -f performance_test.sql ; \
done ; \
done

#!/bin/sh
for version in {13,12,11,10} ; do \
psql -p "54$version" -f init_performance_test.sql ; \
done

for version in {13,12,11,10} ; do \
for n in {1..3} ; do \
psql -p "54$version" -f performance_test.sql ; \
done ; \
done

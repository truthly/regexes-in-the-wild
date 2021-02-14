#!/bin/sh
cd /home/regex/regexes-in-the-wild
for n in logs/regex_*.log ; do grep -E '^RegExp.*,.*,.*,' $n | psql -f import.sql && echo $n && rm $n ; done

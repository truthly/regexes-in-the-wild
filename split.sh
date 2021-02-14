#!/bin/bash
mkdir -p logs
i=0
j=0
while read -r line; do
  printf '%s\n' "$line" >> "current.log"
  $(( j++ )) 2> /dev/null
  if [[ $j -ge 10000 ]]; then
    j=0
    $(( i++ )) 2> /dev/null
    mv "current.log" "logs/regex_$i.log"
  fi
done

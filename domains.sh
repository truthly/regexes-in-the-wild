#!/bin/sh
while read d; do
echo $d ;
gtimeout 10 ./out/Default/Chromium.app/Contents/MacOS/Chromium --headless --screenshot "https://$d" 2>/dev/null | grep -E '^RegExp' > /tmp/regexes.csv ;
mv screenshot.png $HOME/screenshots/$d.png ;
psql -c "SELECT process_regexes('$d')" 
done </tmp/domains.txt

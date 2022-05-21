#!/bin/bash

BOT_TOKEN="228322:xxx-xxx_xxx"
CHAT_ID_LOG="-1703"

MESSAGE="<code>/// $(date '+%F %T') ///</code>"

curl --header 'Content-Type: application/json' \
--request 'POST' \
--data '{"chat_id":"'"$CHAT_ID_LOG"'","text":"'"$(echo -e $MESSAGE)"'", "parse_mode": "html"}' "https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

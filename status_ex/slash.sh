#!/bin/bash

# chat for log messages, not alarm
CHAT_ID_LOG="-1703"

# bot token
BOT_TOKEN="228322:xxx-xxx_xxx"

MESSAGE="<code>/// $(date '+%F %T') ///</code>"

curl --header 'Content-Type: application/json' \
--request 'POST' \
--data '{"chat_id":"'"$CHAT_ID_LOG"'","text":"'"$(echo -e $MESSAGE)"'", "parse_mode": "html"}' "https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

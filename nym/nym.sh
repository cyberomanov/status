#!/bin/bash

CURL="https://mixnet.api.explorers.guru/api/mixnodes/"
DENOM="1000000"
TOKEN="nym"
IP=$(wget -qO- eth0.me)

function nodeStatusFunc() {
    MESSAGE="<b>${TOKEN} | ${MONIKER}</b>\n\n"
    echo -e "${TOKEN} | ${MONIKER}\n"
    SEND=0

    TOTAL_INFO=$(curl -s ${CURL}${IDENTITY})
    DELEGATION=$(echo $(echo "scale=2;$(echo ${TOTAL_INFO} | jq ".mixnode.total_delegation.amount" | tr -d '"')/${DENOM}" | bc))
    SELF_STAKE=$(echo $(echo "scale=2;$(echo ${TOTAL_INFO} | jq ".mixnode.pledge_amount.amount" | tr -d '"')/${DENOM}" | bc))
    TOTAL_STAKE=$(echo ${SELF_STAKE} + ${DELEGATION} | bc -l)
    TEXT="stake >>>>> ${TOTAL_STAKE} ${TOKEN}."
    echo ${TEXT}
    MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'

    OUTDATED=$(echo ${TOTAL_INFO} | jq ".outdated" | tr -d '"')
    if [[ "${OUTDATED}" == "true" ]]; then
        SEND=1
        VERSION=$(echo ${TOTAL_INFO} | jq ".mixnode.mix_node.version" | tr -d '"')
        TEXT="version >>> ${VERSION}."
        echo ${TEXT}
        MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
        TEXT="outdated >> ${OUTDATED}."
        echo ${TEXT}
        MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
    fi

    STATUS=$(echo ${TOTAL_INFO} | jq ".mixnode.status" | tr -d '"')
    if [[ "${STATUS}" != "active" ]]; then
        SEND=1
        TEXT="status >>>> ${STATUS}."
        echo ${TEXT}
        MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
    fi

    UPTIME_TOTAL=$(curl -s ${CURL}${IDENTITY}"/uptime")
    LAST_HOUR=$(echo ${UPTIME_TOTAL} | jq ".last_hour" | tr -d '"')
    LAST_DAY=$(echo ${UPTIME_TOTAL} | jq ".last_day" | tr -d '"')
    if (( ${LAST_HOUR} < 90 )); then SEND=1; fi
    TEXT="uptime >>>> $LAST_HOUR%/h, $LAST_DAY%/d."
    echo ${TEXT}
    MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'

    TOTAL_REWARDS=$(curl -s ${CURL}${IDENTITY}"/estimated_reward")
    ESTIMATED_REWARDS=$(echo $(echo "scale=4;$(echo ${TOTAL_REWARDS} | jq ".estimated_operator_reward" | tr -d '"')/${DENOM}" | bc))
    if (( $(bc <<< "${ESTIMATED_REWARDS} < 1") )); then ESTIMATED_REWARDS="0${ESTIMATED_REWARDS}"; fi
    TEXT="estimated > $ESTIMATED_REWARDS ${TOKEN} per hour."
    echo ${TEXT}
    MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'

    REWARDS=$(echo $(echo "scale=2;$(echo ${TOTAL_INFO} | jq ".mixnode.accumulated_rewards" | tr -d '"')/${DENOM}" | bc))
    TEXT="rewards >>> ${REWARDS} ${TOKEN}."
    echo ${TEXT}
    MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'

    if [[ ${SEND} == "1" ]]; then
       curl --header 'Content-Type: application/json' \
            --request 'POST' \
            --data '{"chat_id":"'"$CHAT_ID_ALARM"'", "text":"'"$(echo -e $MESSAGE)"'", "parse_mode": "html"}' "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
       > /dev/null 2>&1
    elif (( $(echo "$(date +%M) < 10" | bc -l) )); then
        curl --header 'Content-Type: application/json' \
             --request 'POST' \
             --data '{"chat_id":"'"$CHAT_ID_STATUS"'", "text":"'"$(echo -e $MESSAGE)"'", "parse_mode": "html"}' "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        > /dev/null 2>&1
    fi
}

echo -e " "
echo -e "/// $(date '+%F %T') ///"
echo -e " "

. $HOME/status/nym.conf
nodeStatusFunc

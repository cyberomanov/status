#!/bin/bash

CURL="https://mixnet.api.explorers.guru/api/mixnodes/"
DENOM="1000000"
TOKEN="nym"
IP=$(wget -qO- eth0.me)

function __send() {
    # print 'TEXT' into 'nym.log' for the sake of history
    echo ${TEXT}

    # add new text to the 'MESSAGE', which will be sent as 'log' or 'alarm'
    # if 'SEND' == 1, it becomes 'alarm', otherwise it's 'log'
    MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
}

function nodeStatusFunc() {
    MESSAGE="<b>${PROJECT} | ${MONIKER}</b>\n\n"
    echo -e "${PROJECT} | ${MONIKER}\n"
    SEND=0

    # get uptime
    UPTIME_TOTAL=$(curl -s ${CURL}${IDENTITY}"/uptime")
    LAST_HOUR=$(echo ${UPTIME_TOTAL} | jq ".last_hour" | tr -d '"')
    LAST_DAY=$(echo ${UPTIME_TOTAL} | jq ".last_day" | tr -d '"')

    # if 'last hour uptime' is low > alarm
    if (( ${LAST_HOUR} < ${UPTIME} ))
    then
        SEND=1
        TEXT="_hour/day > $LAST_HOUR%/$LAST_DAY%."
        __send
    fi
    
    # get info about node status
    TOTAL_INFO=$(curl -s ${CURL}${IDENTITY})

    # if node is outdated > alarm
    OUTDATED=$(echo ${TOTAL_INFO} | jq ".outdated" | tr -d '"')
    if [[ "${OUTDATED}" == "true" ]]
    then
        SEND=1
        VERSION=$(echo ${TOTAL_INFO} | jq ".mixnode.mix_node.version" | tr -d '"')
        TEXT="_version >> ${VERSION}.\n_outdated > ${OUTDATED}."
        __send
    fi

    # if status is not active > alarm
    STATUS=$(echo ${TOTAL_INFO} | jq ".mixnode.status" | tr -d '"')
    if [[ "${STATUS}" != "active" ]]
    then
        SEND=1
        TEXT="_status >>> ${STATUS}."
        __send
    fi

    # get info about stake
    DELEGATION=$(echo $(echo "scale=2;$(echo ${TOTAL_INFO} | jq ".mixnode.total_delegation.amount" | tr -d '"')/${DENOM}" | bc))
    SELF_STAKE=$(echo $(echo "scale=2;$(echo ${TOTAL_INFO} | jq ".mixnode.pledge_amount.amount" | tr -d '"')/${DENOM}" | bc))
    TOTAL_STAKE=$(echo ${SELF_STAKE} + ${DELEGATION} | bc -l)
    TEXT="stake >>>>> ${TOTAL_STAKE} ${TOKEN}."
    __send

    # get info about rewards
    TOTAL_REWARDS=$(curl -s ${CURL}${IDENTITY}"/estimated_reward")

    # get info about estimated rewards
    ESTIMATED_REWARDS_H=$(echo $(echo "scale=3;$(echo ${TOTAL_REWARDS} | jq ".estimated_operator_reward" | tr -d '"')/${DENOM}" | bc))
    ESTIMATED_REWARDS_M=$(echo ${ESTIMATED_REWARDS_H}*720 | bc -l)
    if (( $(bc <<< "${ESTIMATED_REWARDS_H} < 1") )); then ESTIMATED_REWARDS_H="0${ESTIMATED_REWARDS_H}"; fi
    if (( $(bc <<< "${ESTIMATED_REWARDS_M} < 1") )); then ESTIMATED_REWARDS_M="0${ESTIMATED_REWARDS_M}"; fi
    TEXT="salary >>>> $ESTIMATED_REWARDS_H ${TOKEN}/h, $ESTIMATED_REWARDS_M ${TOKEN}/m."
    __send

    REWARDS=$(echo $(echo "scale=2;$(echo ${TOTAL_INFO} | jq ".mixnode.accumulated_rewards" | tr -d '"')/${DENOM}" | bc))
    if (( $(bc <<< "${REWARDS} < 1") )); then REWARDS="0${REWARDS}"; fi
    TEXT="unpaid >>>> ${REWARDS} ${TOKEN}."
    __send

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

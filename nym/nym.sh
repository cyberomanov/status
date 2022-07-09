#!/bin/bash

function __Send() {
    # print 'TEXT' into 'nym.log' for the sake of history
    echo -e "${TEXT}"

    # add new text to the 'MESSAGE', which will be sent as 'log' or 'alarm'
    # if 'SEND' == 1, it becomes 'alarm', otherwise it's 'log'
    MESSAGE=${MESSAGE}'<code>'$(echo "${TEXT}")'</code>\n'
}

function __NodeStatus() {
    MESSAGE="<b>${PROJECT} ⠀|⠀ ${MONIKER}</b>\n\n"
    echo -e "${PROJECT}  |  ${MONIKER}\n"
    SEND=0; MINUTE=10

    RESPONSE=$(curl -s ${CURL}${IDENTITY})
    if [[ ${RESPONSE} != *"error"* ]]; then
        # get uptime
        UPTIME_TOTAL=$(curl -s ${CURL}${IDENTITY}"/uptime")
        LAST_HOUR=$(echo ${UPTIME_TOTAL} | jq ".last_hour" | tr -d '"')
        LAST_DAY=$(echo ${UPTIME_TOTAL} | jq ".last_day" | tr -d '"')

        # if 'last hour uptime' is low > alarm
        if (( ${LAST_HOUR} < ${UPTIME} )); then
            SEND=1
            TEXT="_hour/day > $LAST_HOUR%/$LAST_DAY%."
            __Send
        fi

        # get info about node status
        TOTAL_INFO=$(curl -s ${CURL}${IDENTITY})

        # if node is outdated > alarm
        OUTDATED=$(echo ${TOTAL_INFO} | jq ".outdated" | tr -d '"')
        if [[ "${OUTDATED}" == "true" ]]; then
            SEND=1
            VERSION=$(echo ${TOTAL_INFO} | jq ".mixnode.mix_node.version" | tr -d '"')
            TEXT="_version >> ${VERSION}.\n_outdated > ${OUTDATED}."
            __Send
        fi

        # if status is not active > alarm
        STATUS=$(echo ${TOTAL_INFO} | jq ".mixnode.status" | tr -d '"')
        if [[ "${STATUS}" != "active" ]]; then
            SEND=1
            TEXT="_status >>> ${STATUS}."
            __Send
        fi

        # get info about stake
        DELEGATION=$(echo $(echo "scale=2;$(echo ${TOTAL_INFO} | jq ".mixnode.total_delegation.amount" | tr -d '"')/${DENOM}" | bc))
        SELF_STAKE=$(echo $(echo "scale=2;$(echo ${TOTAL_INFO} | jq ".mixnode.pledge_amount.amount" | tr -d '"')/${DENOM}" | bc))
        TOTAL_STAKE=$(echo ${SELF_STAKE} + ${DELEGATION} | bc -l)
        TOTAL_STAKE_CUR=$(printf "%.2f" $(echo "scale=2;${TOTAL_STAKE}*${TOKEN_PRICE_CUR}" | bc))

        # get info about rewards
        TOTAL_REWARDS=$(curl -s ${CURL}${IDENTITY}"/estimated_reward")

        # get info about estimated rewards
        ESTIMATED_REWARDS_H=$(echo $(echo "scale=2;$(echo ${TOTAL_REWARDS} | jq ".estimated_operator_reward" | tr -d '"')/${DENOM}" | bc))
        ESTIMATED_REWARDS_M=$(echo ${ESTIMATED_REWARDS_H}*720 | bc -l)
        if (( $(bc <<< "${ESTIMATED_REWARDS_H} < 1") )); then ESTIMATED_REWARDS_H="0${ESTIMATED_REWARDS_H}"; fi
        if (( $(bc <<< "${ESTIMATED_REWARDS_M} < 1") )); then ESTIMATED_REWARDS_M="0${ESTIMATED_REWARDS_M}"; fi
        ESTIMATED_REWARDS_M_CUR=$(printf "%.2f" $(echo "scale=2;${ESTIMATED_REWARDS_M}*${TOKEN_PRICE_CUR}" | bc))

        # get unpaid rewards
        DELEGATOR=$(echo ${TOTAL_INFO} | jq ".address" | tr -d '"')
        DELEGATOR_CLAIMABLE=$(curl -sk https://mixnet.api.explorers.guru/api/accounts/${DELEGATOR}/balance | jq ".claimable.amount" | tr -d '"')
        UNPAID=$(echo $(echo "scale=2;${DELEGATOR_CLAIMABLE}/${DENOM}" | bc))
        if (( $(bc <<< "${UNPAID} < 1") )); then UNPAID="0${UNPAID}"; fi
        UNPAID_CUR=$(printf "%.2f" $(echo "scale=2;${UNPAID}*${TOKEN_PRICE_CUR}" | bc))

        # find the longest value
        MAX=${#UNPAID}
        if (( ${#ESTIMATED_REWARDS_M} > ${MAX})); then MAX=${#ESTIMATED_REWARDS_M}; fi
        if (( ${#TOTAL_STAKE} > ${MAX})); then MAX=${#TOTAL_STAKE}; fi
        MAX=$((MAX+1))

        # pretty output
        TOTAL_STAKE_SPACE=$((MAX-${#TOTAL_STAKE})); ESTIMATED_REWARDS_M_SPACE=$((MAX-${#ESTIMATED_REWARDS_M})); UNPAID_SPACE=$((MAX-${#UNPAID}))
        TOTAL_STAKE_TEXT=$(printf "stake >>>>>%${TOTAL_STAKE_SPACE}s${TOTAL_STAKE} | ${CURRENCY_SYMB}${TOTAL_STAKE_CUR}.\n")
        ESTIMATED_REWARDS_M_TEXT=$(printf "salary/m >>%${ESTIMATED_REWARDS_M_SPACE}s${ESTIMATED_REWARDS_M} | ${CURRENCY_SYMB}${ESTIMATED_REWARDS_M_CUR}.\n")
        UNPAID_SPACE_TEXT=$(printf "unpaid >>>>%${UNPAID_SPACE}s${UNPAID} | ${CURRENCY_SYMB}${UNPAID_CUR}.\n")

        TEXT="${TOTAL_STAKE_TEXT}\n${ESTIMATED_REWARDS_M_TEXT}\n${UNPAID_SPACE_TEXT}"
        __Send
    else
        TEXT="_explorer is down."
        __Send
    fi

    if [[ ${SEND} == "1" ]]; then
        curl --header 'Content-Type: application/json' \
        --request 'POST' \
        --data '{"chat_id":"'"${CHAT_ID_ALARM}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        > /dev/null 2>&1
    elif (( $(echo "$(date +%M) < ${MINUTE}" | bc -l) )); then
        curl --header 'Content-Type: application/json' \
        --request 'POST' \
        --data '{"chat_id":"'"${CHAT_ID_STATUS}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        > /dev/null 2>&1
    fi
}

function Main() {
    CURL="https://mixnet.api.explorers.guru/api/mixnodes/"
    IP=$(wget -qO- eth0.me)
    DENOM="1000000"
    TOKEN="nym"
    CURRENCY="usd"
    CURRENCY_SYMB="$"
    TOKEN_PRICE_CUR=$(curl -sk -X GET "https://api.coingecko.com/api/v3/simple/price?ids=${TOKEN}&vs_currencies=${CURRENCY}" -H "accept: application/json" | jq ".nym.usd")

    echo -e " "
    echo -e "/// $(date '+%F %T') ///"
    echo -e " "

    . $HOME/status/nym.conf
    __NodeStatus
}

# run 'Main'
Main

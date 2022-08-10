#!/bin/bash

function __Send() {
    # print 'TEXT' into 'cosmos.log' for the sake of history
    echo -e "${TEXT}"

    # add new text to the 'MESSAGE', which will be sent as 'log' or 'alarm'
    # if 'SEND' == 1, it becomes 'alarm', otherwise it's 'log'
    MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
}

function __Epoch() {
    # init 'timezone'
    TIMEZONE="Africa/Abidjan"
    STRANGE=0

    # read the config
    . $HOME/status/solana.conf

    # get 'cluster_name'
    if [[ ${CLUSTER} == "t" ]]; then CLUSTER_NAME="testnet"; fi
    if [[ ${CLUSTER} == "m" ]]; then CLUSTER_NAME="mainnet"; fi

    # export timezone from the config
    export TZ=${TIMEZONE}

    # do some check
    CHECK=$(${BIN} epoch-info -u${CLUSTER} 2>&1)
    if [[ ${CHECK} == *"error"* ]]; then
        TEXT="${CLUSTER_NAME} >>>> ???\n"
        __Send
        TEXT="rpc request error: 503."
        __Send
    else
        # get some info about epoch
        ${BIN} epoch-info -u${CLUSTER} > ~/temp.txt

        # get epoch number
        EPOCH_NUMBER=$(cat ~/temp.txt | grep "Epoch:" | awk '{print $2}')
        if [[ ${EPOCH_NUMBER} == "" ]]; then EPOCH_NUMBER="0"; STRANGE=1; fi
        TEXT="${CLUSTER_NAME} >>>> #${EPOCH_NUMBER}.\n"
        __Send

        # get epoch progress in percent
        EPOCH_PROGRESS=$(printf "%.2f" $(cat ~/temp.txt | grep "Epoch Completed Percent" | awk '{print $4}' | grep -oE "[0-9]*|[0-9]*.[0-9]*" | awk 'NR==1 {print; exit}'))"%"
        TEXT="progress >>> ${EPOCH_PROGRESS}."
        __Send

        # get average cluster skiprate
        AVG_CLUSTER_SKIP=$(printf "%.2f" $(${BIN} -u${CLUSTER} validators --output json-compact | jq .'averageStakeWeightedSkipRate'))"%"
        TEXT="skiprate >>> ${AVG_CLUSTER_SKIP}.\n"
        __Send

        # get info about epoch ending time
        EPOCH_REMAINING=$(echo $(cat ~/temp.txt | grep "Epoch Completed Time" | grep -o '(.*)' | sed "s/^(//" | awk '{$NF="";sub(/[ \t]+$/,"")}1'))

        # some replacing
        REMAINING=$(echo ${EPOCH_REMAINING} | sed "s/days/day/g")

        EPOCH_REMAINING_PRETTY=$(echo ${REMAINING} | sed "s/day/d/g" )
        if [[ ${EPOCH_REMAINING_PRETTY} == "" ]]; then EPOCH_REMAINING_PRETTY="no info"; STRANGE=2; fi
        TEXT="time_left >> ${EPOCH_REMAINING_PRETTY}."
        __Send

        if [[ ${STRANGE} != 2 ]]; then
            REMAINING=$(echo ${REMAINING} | sed "s/h/hour/g"); REMAINING=$(echo ${REMAINING} | sed "s/m/min/g"); REMAINING=$(echo ${REMAINING} | sed "s/s/sec/g")
            APPROXIMATE_END_TIME=$(date -d "+${REMAINING}" +"%b %d, %H:%M")
            TEXT="appr_time >> ${APPROXIMATE_END_TIME}."
            __Send
        fi

        rm ~/temp.txt
    fi

    echo
    # send info about epoch
    if (( $(echo "$(date +%M) < ${MINUTE}" | bc -l) )); then
        curl --header 'Content-Type: application/json' \
        --request 'POST' \
        --data '{"chat_id":"'"${CHAT_ID_STATUS}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        > /dev/null 2>&1
    fi
}

function __DelinquentStatus() {

    # get some info about delinquent status
    VALIDATOR_INFO=$(echo ${VALIDATOR_INFO_TOTAL} | jq '.validators[] | select(.identityPubkey == "'"${IDENTITY_KEY}"'")')
    DELINQUENT_STATUS=$(echo ${VALIDATOR_INFO} | jq  '.delinquent')

    if [[ ${DELINQUENT_STATUS} == "true" ]]; then
        # init some variables
        DEL_COUNT=0
        NON_DEL_COUNT=0

        # do several checks to prevent random alarm
        for i in {1..3}; do
            VALIDATOR_INFO_TOTAL=$(${BIN} -u${CLUSTER} validators --output json-compact)
            VALIDATOR_INFO=$(echo ${VALIDATOR_INFO_TOTAL} | jq '.validators[] | select(.identityPubkey == "'"${IDENTITY_KEY}"'")')
            DELINQUENT_STATUS=$(echo ${VALIDATOR_INFO} | jq  '.delinquent')

            # echo $DELINQUENT_STATUS
            if [[ ${DELINQUENT_STATUS} == "true" ]]; then DEL=$((${DEL_COUNT}+1)); fi
            if [[ ${DELINQUENT_STATUS} == "false" ]]; then NON_DEL=$((${NON_DEL_COUNT}+1)); fi
            sleep 1
        done

        # if 'delinquent_status_count' > 'non_deliquent_status_count', then 'alarm'
        if (( ${DEL_COUNT} > ${NON_DEL_COUNT} )); then
            DELINQUENT_STATUS="true"
            TEXT="_delinquent > true."
            __Send

            curl --header 'Content-Type: application/json' \
            --request 'POST' \
            --data '{"chat_id":"'"${CHAT_ID_ALARM}"'", "text":"'"$(echo -e ${MESSAGE})"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            > /dev/null 2>&1
        else
            DELINQUENT_STATUS="false"
            # TEXT="delinquent > false."
            # __Send
        fi
    fi
}

function __CPULoad() {

    # init some variables
    CPU_ALARM=80
    RAM_ALARM=80
    PARTITION_ALARM=80
    CPU_LOAD_MESSAGE=""

    # read 'cosmos.conf'
    . $HOME/status/solana.conf

    # get CPU load
    CPU=$(printf "%.0f" $(echo "scale=2; 100-$(mpstat | tail -1 | awk 'NF {print $NF}')" | bc))

    if (( $(echo "${CPU} > ${CPU_ALARM}" | bc -l) )); then
        SEND=1
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"_cpu_used >>>>> ${CPU}%.\n"
    else
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"cpu_used >>>>>> ${CPU}%.\n"
    fi

    # get RAM load
    free -g > ~/temp.txt
    RAM_TOTAL=$(cat ~/temp.txt | awk '{print $2}' | awk 'NR==2 {print; exit}')"G"
    RAM_USED=$(cat ~/temp.txt | awk '{print $3}' | awk 'NR==2 {print; exit}')"G"
    RAM_PERC=$(printf "%.0f" $(echo "scale=2; ${RAM_USED}/${RAM_TOTAL}*100" | bc | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}'))

    if (( $(echo "${RAM_PERC} > ${RAM_ALARM}" | bc -l) )); then
        SEND=1
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"_ram_used >>>>> ${RAM_PERC}%.\n"
    else
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"ram_used >>>>>> ${RAM_PERC}%.\n"
    fi

    # get SWAP load
    SWAP_TOTAL=$(cat ~/temp.txt | grep "Swap" | awk '{print $2}')"G"
    SWAP_USED=$(cat ~/temp.txt | grep "Swap" | awk '{print $3}')"G"
    SWAP_PERC=$(printf "%.0f" $(echo "scale=2; ${SWAP_USED}/${SWAP_TOTAL}*100" | bc | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}'))

    if [[ ${SWAP_TOTAL} != "0G" && ${SWAP_TOTAL} != "G" && ${SWAP_USED} != "0G" && ${SWAP_USED} != "G" ]]; then
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"swap_used >>>>> ${SWAP_PERC}%.\n"
    fi

    # get disk load
    df -h / > ~/temp.txt
    DISK_PERC=$(printf "%.0f" $(cat ~/temp.txt | awk '{print $5}' | awk 'NR==2 {print; exit}' | tr -d '%'))

    if (( $(echo "${DISK_PERC} > ${PARTITION_ALARM}" | bc -l) )); then
        SEND=1
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"_part_used >>>> ${DISK_PERC}%.\n"
    else
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"part_used >>>>> ${DISK_PERC}%.\n"
    fi

    # get system load
    SYSTEM_LOAD=$(cat /proc/loadavg | awk '{print $2}')
    CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"server_load >>> ${SYSTEM_LOAD}."

    if [[ ${SEND} == 1 ]]; then TEXT=${CPU_LOAD_MESSAGE}; __Send; fi

    rm ~/temp.txt
}

function __NodeStatus() {

    # init some variables
    SEND=0
    IDENTITY_BALANCE_ALARM=0

    # read the config
    . $HOME/status/solana.conf

    # get some info about our validator
    VALIDATOR_INFO_TOTAL=$(${BIN} -u${CLUSTER} validators --output json-compact)
    VALIDATOR_INFO=$(echo ${VALIDATOR_INFO_TOTAL} | jq '.validators[] | select(.identityPubkey == "'"${IDENTITY_KEY}"'")')

    # get bin version from chain
    BIN_VERSION=$(echo ${VALIDATOR_INFO} | jq '.version' | tr -d '"')
    TEXT="bin_version >>> ${BIN_VERSION}.\n"
    __Send

    # get some info about slots and skiprate
    TOTAL_PASSED_SLOTS=$(${BIN} block-production -u${CLUSTER} | grep "$IDENTITY_KEY")
    EXECUTED_SLOTS=$(echo ${TOTAL_PASSED_SLOTS} | awk '{print $3}')
    SKIPPED_SLOTS=$(echo ${TOTAL_PASSED_SLOTS} | awk '{print $4}')

    if [[ ${EXECUTED_SLOTS} == "" ]]; then EXECUTED_SLOTS=0; fi
    if [[ ${SKIPPED_SLOTS} == "" ]]; then SKIPPED_SLOTS=0; fi

    SKIPPED=$(echo ${VALIDATOR_INFO} | jq '.skipRate')
    if [[ ${SKIPPED} == ""  || ${SKIPPED} == "null" ]]; then SKIPPED=0; fi

    SKIPPED_PERC=$(printf "%.2f" $(echo ${SKIPPED}))
    PASSED_SLOTS=$((${EXECUTED_SLOTS}+${SKIPPED_SLOTS}))
    LEADER_SLOTS=$(${BIN} leader-schedule | grep ${IDENTITY_KEY} | wc -l)
    PASSED_SLOTS_PERC=$(printf "%.2f" $(echo "scale=4; ${PASSED_SLOTS}/${LEADER_SLOTS}*100" | bc))

    PASSED_SLOTS_PERC_INT=$(printf "%.0f" $(echo "scale=4; ${PASSED_SLOTS}/${LEADER_SLOTS}*100" | bc))
    # if [[ ${PASSED_SLOTS_PERC} == 0.00 ]]; then ${PASSED_SLOTS_PERC}="100"; fi

    # get average cluster skiprate
    AVG_CLUSTER_SKIP=$(printf "%.2f" $(echo ${VALIDATOR_INFO_TOTAL} | jq .'averageStakeWeightedSkipRate'))

    # send 'alarm', if (validator slot progress is > 50%) AND (skiprate is > avg + grace)
    if [[ $(echo "${SKIPPED_PERC} > ${AVG_CLUSTER_SKIP}" | bc) -eq 1 ]]; then
        echo -e "skip is higher than average: ${SKIPPED_PERC} > ${AVG_CLUSTER_SKIP}."
        if [[ $(echo "${SKIPPED_PERC} > $(echo "scale=2; ${AVG_CLUSTER_SKIP}+30" | bc)" | bc) -eq 1 ]]; then
            echo -e "skip is higher than grace: ${SKIPPED_PERC} > (${AVG_CLUSTER_SKIP}+30)."
            if (( ${PASSED_SLOTS_PERC_INT} > 50 )); then
                SEND=1
            else
                echo "but validator slot progress: ${PASSED_SLOTS_PERC_INT}."
            fi
        fi
    else
        echo -e "skip is normal: ${SKIPPED_PERC} < ${AVG_CLUSTER_SKIP}."
    fi
    echo

    # get some info about credits
    CREDITS_PLACE=$(${BIN} validators -u${CLUSTER} --sort=credits -r -n | grep ${IDENTITY_KEY} | awk '{print $1}' | grep -oE "[0-9]*")
    CREDITS_EARNED=$(echo ${VALIDATOR_INFO_TOTAL} | jq '.validators[] | select(.identityPubkey == "'"${IDENTITY_KEY}"'" ) |  .epochCredits')

    # pretty output
    P_T_LENGTH=$(( ${#PASSED_SLOTS} + ${#LEADER_SLOTS} + 1)); E_S_LENGTH=$(( ${#EXECUTED_SLOTS} + ${#SKIPPED_SLOTS} + 1))
    MAX=${P_T_LENGTH}
    if (( ${#E_S_LENGTH} > ${MAX})); then MAX=${E_S_LENGTH}; fi
    if (( ${#CREDITS_EARNED} > ${MAX})); then MAX=${#CREDITS_EARNED}; fi
    MAX=$((MAX+1))

    P_T_SPACE=$((MAX-${P_T_LENGTH})); E_S_SPACE=$((MAX-${E_S_LENGTH})); C_SPACE=$((MAX-${#CREDITS_EARNED}))
    P_T_TEXT=$(printf "passed/total >>%${P_T_SPACE}s${PASSED_SLOTS}/${LEADER_SLOTS} | ${PASSED_SLOTS_PERC}\n")
    if [[ ${SEND} == 1 ]]; then
        E_S_TEXT=$(printf "_exec/skipped >%${E_S_SPACE}s${EXECUTED_SLOTS}/${SKIPPED_SLOTS} | ${SKIPPED_PERC}\n")
    else
        E_S_TEXT=$(printf "exec/skipped >>%${E_S_SPACE}s${EXECUTED_SLOTS}/${SKIPPED_SLOTS} | ${SKIPPED_PERC}\n")
    fi
    C_TEXT=$(printf   "vote_credits >>%${C_SPACE}s${CREDITS_EARNED} | #${CREDITS_PLACE}\n")
    TEXT="${P_T_TEXT}%.\n${E_S_TEXT}%.\n${C_TEXT}.\n"
    __Send

    # get some info about stakes
    STAKES_INFO=$(${BIN} stakes ${VOTE_KEY} -u${CLUSTER} --output json-compact)
    ACTIVE_STAKE=$(echo "scale=2; $(echo ${STAKES_INFO} | jq -c ".[] | .activeStake" | paste -sd+ | bc)/1000000000" | bc)
    if [[ $(echo "${ACTIVE_STAKE} < 1" | bc) -eq 1 && ${ACTIVE_STAKE} != 0 ]]; then ACTIVE_STAKE="0${ACTIVE_STAKE}"; fi
    ACTIVATING_STAKE=$(echo "scale=2; $(echo ${STAKES_INFO} | jq -c ".[] | .activatingStake" | paste -sd+ | bc)/1000000000" | bc)
    if [[ $(echo "${ACTIVATING_STAKE} < 1" | bc) -eq 1 && ${ACTIVATING_STAKE} != 0 ]]; then ACTIVATING_STAKE="0${ACTIVATING_STAKE}"; fi
    DEACTIVATING_STAKE=$(echo "scale=2; $(echo ${STAKES_INFO} | jq -c ".[] | .deactivatingStake" | paste -sd+ | bc)/1000000000" | bc)
    if [[ $(echo "${DEACTIVATING_STAKE} < 1" | bc) -eq 1 && ${DEACTIVATING_STAKE} != 0 ]]; then DEACTIVATING_STAKE="0${DEACTIVATING_STAKE}"; fi

    # send info about 'activating/deactivating' only if != 0
    TEXT="active_stake >> ${ACTIVE_STAKE}.\n"
    if [[ ${ACTIVATING_STAKE} != 0 ]]; then TEXT=${TEXT}"_activating >>> ${ACTIVATING_STAKE}.\n"; fi
    if [[ ${DEACTIVATING_STAKE} != 0 ]]; then TEXT=${TEXT}"_deactivating > ${DEACTIVATING_STAKE}.\n"; fi
    __Send

    # get info about balance
    IDENTITY_BALANCE=$(printf "%.2f" $(${BIN} balance ${IDENTITY_KEY} -u${CLUSTER} | awk '{print $1}'))
    VOTE_BALANCE=$(printf "%.2f" $(${BIN} balance ${VOTE_KEY} -u${CLUSTER} | awk '{print $1}'))

    if [[ $(echo "${IDENTITY_BALANCE} < ${IDENTITY_BALANCE_ALARM}" | bc) -eq 1 ]]; then
        SEND=1
        TEXT="_id_balance >>> ${IDENTITY_BALANCE}.\n_vote_balance > ${VOTE_BALANCE}.\n"
    else
        TEXT="id_balance >>>> ${IDENTITY_BALANCE}.\nvote_balance >> ${VOTE_BALANCE}.\n"
    fi
    __Send
}

function Main() {

    # init some variables
    MINUTE=10
    MONIKER="solana"

    # print the current time
    echo -e " "; echo -e "/// $(date '+%F %T') ///"; echo -e " "

    # read the config
    . $HOME/status/solana.conf

    # send info about epoch
    if [[ ${SEND_EPOCH_INFO} == "true" ]]; then __Epoch; fi

    # init some variables
    MESSAGE="<b>${MONIKER}</b>\n\n"
    echo -e "${MONIKER}\n"

    # check delinquent status
    VALIDATOR_INFO_TOTAL=$(${BIN} -u${CLUSTER} validators --output json-compact 2>&1)
    if [[ ${VALIDATOR_INFO_TOTAL} == *"error"* ]]; then
        TEXT="rpc request error: 503."
        __Send
    else
        __DelinquentStatus

        # if delinquent is 'false'
        if [[ ${DELINQUENT_STATUS} == "false" ]]; then
            # run 'NodeStatus'
            __NodeStatus

            # get CPULoad info
            __CPULoad;
        fi
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

# run 'main'
Main

#!/bin/bash

function __SystemLoad() {

    # print separator
    __SeparatorOutput "$(date '+%F | %T') | ${SERVER} | load"

    # init and zeroing
    SERVER_INTRO="<b>${SERVER} ⠀|⠀ load</b>\n\n"
    CPU_ALARM=80
    RAM_ALARM=80
    PARTITION_ALARM=80
    DISK_PERCENTAGE_USED_ALARM=100
    CPU_LOAD_MESSAGE=""
    DISK_PHYSIC_TEXT=""
    ALARM=0
    KEY=0

    # read 'cosmos.conf'
    source ./cosmos.conf

    # get CPU load
    CPU=$(printf "%.0f" $(echo "scale=2; 100-$(mpstat | tail -1 | awk 'NF {print $NF}')" | bc))
    CPU_TEXT="cpu_used > ${CPU}%.\n"
    if (( $(echo "${CPU} > ${CPU_ALARM}" | bc -l) )); then ALARM=1; CPU_TEXT='_'${CPU_TEXT}; fi

    # get RAM load, 1048576
    RAM_TOTAL=$(cat /proc/meminfo | grep "MemTotal" | grep -o "[0-9]*")
    RAM_FREE=$(cat /proc/meminfo | grep "MemAvailable" | grep -o "[0-9]*")
    RAM_USED=$(echo "scale=2;${RAM_TOTAL}-${RAM_FREE}" | bc)
    RAM_PERC=$(printf "%.0f" $(echo "scale=2; ${RAM_USED}/${RAM_TOTAL}*100" | bc | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}'))
    RAM_TEXT="ram_used > ${RAM_PERC}%.\n"
    if (( $(echo "${RAM_PERC} > ${RAM_ALARM}" | bc -l) )); then ALARM=1; RAM_TEXT='_'${RAM_TEXT}; fi

    # get SWAP load
    SWAP_TOTAL=$(cat /proc/meminfo | grep "MemTotal" | grep -o "[0-9]*")
    SWAP_FREE=$(cat /proc/meminfo | grep "MemAvailable" | grep -o "[0-9]*")
    SWAP_USED=$(echo "scale=2;${SWAP_TOTAL}-${SWAP_FREE}" | bc)
    SWAP_PERC=$(printf "%.0f" $(echo "scale=2; ${SWAP_USED}/${SWAP_TOTAL}*100" | bc | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}'))
    if [[ ${SWAP_TOTAL} != "0G" && ${SWAP_TOTAL} != "G" && ${SWAP_USED} != "0G" && ${SWAP_USED} != "G" ]]; then SWAP_TEXT="swap_used > ${SWAP_PERC}%.\n"; fi

    # get disk usage
    DISK_PERC=$(printf "%.0f" $(df -h / | awk '{print $5}' | awk 'NR==2 {print; exit}' | tr -d '%'))
    DISK_TEXT="part_used > ${DISK_PERC}%.\n"
    if (( $(echo "${DISK_PERC} > ${PARTITION_ALARM}" | bc -l) )); then ALARM=1; DISK_TEXT='_'${DISK_TEXT}; fi

    # check disk physic conditions
    if [[ $(/usr/sbin/smartctl -V 2>&1) != *"not found"* && $(/usr/sbin/fdisk -v 2>&1) != *"not found"* && $(/usr/sbin/smartctl -V 2>&1) != *"such file"* && $(/usr/sbin/fdisk -v 2>&1) != *"such file"*  ]]; then
        DISK_NAME_STRING=$(/usr/sbin/fdisk -l 2>&1 | grep -e "Disk /dev/*" | grep -oE "/dev/[[:alnum:]]*")
        DISK_NAME_ARRAY=($(echo "${DISK_NAME_STRING}" | tr ' ' '\n'))
        for i in "${!DISK_NAME_ARRAY[@]}"; do
            DISK_INFO=$(/usr/sbin/smartctl -s on -a ${DISK_NAME_ARRAY[i]})
            if [[ ${DISK_INFO} != *"Unable to detect device"* && ${DISK_INFO} == *"START OF SMART DATA SECTION"* ]]; then
                KEY=1
                DISK_NAME=$(echo ${DISK_NAME_ARRAY[i]})
                SPARE=$(echo ${DISK_INFO} | grep -o "Available Spare: [0-9]*" | grep -o "[0-9]*")
                SPARE_THRESHOLD=$(echo ${DISK_INFO} | grep -o "Available Spare Threshold: [0-9]*" | grep -o "[0-9]*")
                PERCENTAGE_USED=$(echo ${DISK_INFO} | grep -o "Percentage Used: [0-9]*" | grep -o "[0-9]*")
                if [[ $(echo "${SPARE} < ${SPARE_THRESHOLD}" | bc) -eq 1 || $(echo "${PERCENTAGE_USED} > ${DISK_PERCENTAGE_USED_ALARM}" | bc) -eq 1 ]]; then
                    ALARM=1
                    DISK_PHYSIC_TEXT=${DISK_PHYSIC_TEXT}"_${DISK_NAME:5} > ${SPARE}% spare, ${PERCENTAGE_USED}% used.\n"
                else
                    DISK_PHYSIC_TEXT=${DISK_PHYSIC_TEXT}"${DISK_NAME:5} > ${SPARE}% spare, ${PERCENTAGE_USED}% used.\n"
                fi
            fi
        done
        if [[ ${KEY} == 0 ]]; then
            DISK_PHYSIC_TEXT="there is no disk which can be tested."
        fi
    else
        DISK_PHYSIC_TEXT="install tools manually: 'apt-get install smartmontools fdisk -y'."
    fi

    # get system load
    SYSTEM_LOAD=$(cat /proc/loadavg | awk '{print $2}')
    SYSTEM_LOAD_TEXT="server_load > ${SYSTEM_LOAD}.\n"

    # combine a message
    CPU_LOAD_MESSAGE=${CPU_TEXT}${RAM_TEXT}${SWAP_TEXT}${DISK_TEXT}${DISK_PHYSIC_TEXT}${SYSTEM_LOAD_TEXT}

    # generate 'final_message' from the given text
    FINAL_MESSAGE=$(__PrettyMessageOutput "${CPU_LOAD_MESSAGE}")

    # print 'final_message' into log
    echo -e ${FINAL_MESSAGE}  

    # if 'ALARM' == 1, then send 'alarm_message' into 'alarm_chat'
    if [[ ${ALARM} == "1" ]]; then

        # add to the 'final_message' some format before sending to telegram
        FINAL_MESSAGE="${SERVER_INTRO}<code>${FINAL_MESSAGE}</code>"

        # instant alarm
        __OneMessageToTelegram "${CHAT_ID_ALARM}" "${FINAL_MESSAGE}"
    fi
}

function __PrettyMessageOutput() {
    TEXT=${1}
    MAX_LENGTH=0
    FINAL_MESSAGE=""
    MESSAGE_ARRAY=($(echo "$(echo -e "${TEXT}" | tr ' ' '^')" | tr ' ' '\n'))
    for i in "${!MESSAGE_ARRAY[@]}"; do
        MESSAGE_ARRAY[i]=$(echo ${MESSAGE_ARRAY[i]} | tr '^' ' ')
        TEMP=${MESSAGE_ARRAY[i]//' > '/ ' ' }
        TEMP_ARRAY=(${TEMP})
        if (( ${#TEMP_ARRAY[0]} > ${MAX_LENGTH} )); then MAX_LENGTH=${#TEMP_ARRAY[0]}; fi
    done
    for i in "${!MESSAGE_ARRAY[@]}"; do
        ARROW=""
        TEMP=${MESSAGE_ARRAY[i]//' > '/ ' ' }
        TEMP_ARRAY=(${TEMP})
        ARROW_COUNT=$((${MAX_LENGTH}-${#TEMP_ARRAY[0]}+1))
        for (( i1 = 0; i1 <= ${ARROW_COUNT}; i1++ )); do ARROW=${ARROW}">"; done
        FINAL_MESSAGE=${FINAL_MESSAGE}${MESSAGE_ARRAY[i]//>/${ARROW}}'\n'
    done
    echo ${FINAL_MESSAGE::-2}
}

function __SeparatorOutput() {
    echo -ne "\n┌"
    for (( i = 0; i <= ${#1}+3; i++ )); do echo -n "-"; done
    echo -ne "┐\n   ${1}   \n└"
    for (( i = 0; i <= ${#1}+3; i++ )); do echo -n "-"; done
    echo -n "┘"; echo; echo
}

function __NodeStatus() {

    NODE_STATUS="OK"
    NODE_STATUS_TEXT="node > connectable.\n"
    NODE_STATUS_CHECK=$(timeout 5s ${COSMOS} status 2>&1 --node ${NODE} --home ${NODE_HOME})

    if [[ ${NODE_STATUS_CHECK} == *"connection refused"* ]] || [[ ${NODE_STATUS_CHECK} == "" ]]; then
        ALARM=1; NODE_STATUS="NOT_OK"

        if [[ ${NODE_STATUS_CHECK} == "" ]]; then
            NODE_STATUS_TEXT="_node > lost peers.\n"
            if [[ ${ALLOW_SERVICE_RESTART} == "true" ]]; then
                systemctl restart ${SERVICE} > /dev/null 2>&1
                NODE_STATUS_TEXT=${NODE_STATUS_TEXT::-3}", but service has been restarted.\n"
            fi
        else
            NODE_STATUS_TEXT="_node > connection is refused.\n"
            if [[ ${ALLOW_SERVICE_RESTART} == "true" ]]; then
                systemctl restart ${SERVICE} > /dev/null 2>&1
                NODE_STATUS_TEXT=${NODE_STATUS_TEXT::-3}", but service has been restarted.\n"
            fi
        fi
    fi
}

function __BlockGap() {

    BLOCK_GAP_STATUS="OK"

    # get the last explorer's block
    if [[ ${CURL} == *"v1/status"* ]] || [[ ${CURL} == *"mintscan"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq -r ".block_height")
        if [[ ${LATEST_CHAIN_BLOCK} == "null" ]]; then
            LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq -r ".data.block_height")
        fi
    elif [[ ${CURL} == *"bank/total"* ]] || [[ ${CURL} == *"blocks/latest"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq -r ".height")
        if [[ ${LATEST_CHAIN_BLOCK} == "null" ]]; then
            LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq -r ".block.header.height")
        fi
    elif [[ ${CURL} == *"block?latest"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq -r ".result.block.header.height")
    else
        LATEST_CHAIN_BLOCK="0"
    fi

    # get the latest local node height
    LATEST_NODE_BLOCK=$(${COSMOS} status 2>&1 --node ${NODE} --home ${NODE_HOME} | jq -r '.SyncInfo'.'latest_block_height')

    # if 'CURL' was not set > no compare with explorer height
    if [[ ${CURL} != "" ]] && [[ ${LATEST_CHAIN_BLOCK} != "" ]] && [[ ${LATEST_CHAIN_BLOCK} != "0" ]] && [[ ${LATEST_CHAIN_BLOCK} != "null" ]]; then
        BLOCK_GAP=$((${LATEST_CHAIN_BLOCK}-${LATEST_NODE_BLOCK}))
        BLOCK_GAP_TEXT="exp/me > ${LATEST_CHAIN_BLOCK}/${LATEST_NODE_BLOCK}, gap: ${BLOCK_GAP} blocks.\n"

        # if we are in the past more than 'N' blocks > alarm
        if ((${BLOCK_GAP} > ${BLOCK_GAP_ALARM})); then
            ALARM=1
            BLOCK_GAP_STATUS="NOT_OK"
            BLOCK_GAP_TEXT='_'${BLOCK_GAP_TEXT::-3}".\n"

            if [[ ${ALLOW_SERVICE_RESTART} == "true" ]]; then
                systemctl restart ${SERVICE} > /dev/null 2>&1
                BLOCK_GAP_TEXT=${BLOCK_GAP_TEXT::-3}", but service has been restarted.\n"
            fi
        fi
    else
        BLOCK_GAP_TEXT="exp/me > 0/${LATEST_NODE_BLOCK}.\n"
    fi
}

function __ChainVitality() {

    CHAIN_VITALITY_STATUS="OK"

    CONSENSUS_STATE=$(curl -s localhost:${PORT}/consensus_state | jq ".result.round_state.height_vote_set[0].prevotes_bit_array" | grep -oE [0-9].[0-9]* | tail -1)
    CHAIN_VITALITY_TEXT="chain > alive, consensus: ${CONSENSUS_STATE}.\n"

    # if file with last local height exists, then compare actual hight and the latest value
    if [ -e "./temp/${PROJECT}_LH.temp" ]; then
        if [[ $(cat "./temp/${PROJECT}_LH.temp") == ${LATEST_NODE_BLOCK} && ${BLOCK_GAP_STATUS} == "OK" ]]; then
            ALARM=1
            CHAIN_VITALITY_STATUS="NOT_OK"
            CHAIN_VITALITY_TEXT="_chain > halted, consensus: ${CONSENSUS_STATE}.\n"
        fi
    fi
    echo ${LATEST_NODE_BLOCK} > "./temp/${PROJECT}_LH.temp"
}

function __BlockExecutionTime() {

    # init some variables
    LOOKBEHIND_BLOCKS=100

    # get the latest block time in local history
    NODE_STATUS_TOTAL=$(curl -s localhost:${PORT}/status)
    LATEST_BLOCK_HEIGHT=$(echo ${NODE_STATUS_TOTAL} | jq -r ".result.sync_info.latest_block_height")
    LATEST_BLOCK_TIME=$(echo ${NODE_STATUS_TOTAL} | jq -r ".result.sync_info.latest_block_time" | grep -oE "[0-9]*:[0-9]*:[0-9]*")
    IFS=':' read -ra HMS <<< "$LATEST_BLOCK_TIME"
    LATEST_BLOCK_TIME_IN_SEC=$(echo ${HMS[0]}*3600+${HMS[1]}*60+${HMS[2]} | bc -l)

    # get the latest available block in local history
    FIRST_AVAILABLE_BLOCK=$(curl -sk "localhost:${PORT}/block?height=1")
    if [[ ${FIRST_AVAILABLE_BLOCK} == *"error"* ]]; then
        FIRST_AVAILABLE_BLOCK=$(echo ${FIRST_AVAILABLE_BLOCK} | jq ".error.data" | grep -Eo "[0-9]*" | tail -1)
    else
        FIRST_AVAILABLE_BLOCK=1
    fi

    # get the start block
    START_BLOCK_HEIGHT=$((${LATEST_BLOCK_HEIGHT}-${LOOKBEHIND_BLOCKS}+1))
    if [[ $(echo "${FIRST_AVAILABLE_BLOCK} > ${START_BLOCK_HEIGHT}" | bc) -eq 1 ]]; then START_BLOCK_HEIGHT=${FIRST_AVAILABLE_BLOCK}; fi 

    # get the start block time for calculating
    START_BLOCK_TIME=$(${COSMOS} q block ${START_BLOCK_HEIGHT} --node ${NODE} | jq -r ".block.header.time" | grep -oE "[0-9]*:[0-9]*:[0-9]*")
    IFS=':' read -ra HMS <<< "${START_BLOCK_TIME}"
    START_BLOCK_TIME_IN_SEC=$(echo ${HMS[0]}*3600+${HMS[1]}*60+${HMS[2]} | bc -l)

    # find the max and the min values
    MAX=${LATEST_BLOCK_TIME_IN_SEC}; MIN=${LATEST_BLOCK_TIME_IN_SEC}
    if (( ${START_BLOCK_TIME_IN_SEC} > ${MAX} )); then MAX=${START_BLOCK_TIME_IN_SEC}; fi
    if (( ${START_BLOCK_TIME_IN_SEC} < ${MIN} )); then MIN=${START_BLOCK_TIME_IN_SEC}; fi

    # find the difference between blocks in seconds
    DIFF_IN_SEC=$((${MAX}-${MIN}))
    if (( $(echo "86400 - ${DIFF_IN_SEC}" | bc) < ${DIFF_IN_SEC} )); then
        DIFF_IN_SEC=$((86400 - ${DIFF_IN_SEC}))
    fi

    # get estimated block exectuion time
    BLOCK_EXECUTION_TIME=$(echo "scale=2;${DIFF_IN_SEC}/100" | bc)
    if [[ $(echo "${BLOCK_EXECUTION_TIME} < 1" | bc) -eq 1 ]]; then BLOCK_EXECUTION_TIME="0${BLOCK_EXECUTION_TIME}"; fi

    BLOCK_EXECUTION_TIME_TEXT="block_time > ${BLOCK_EXECUTION_TIME} sec.\n"
}

function __ValidatorExisting() {

    VALIDATOR_EXISTING_STATUS="NOT_OK"
    VALIDATOR_EXISTING_TEXT="validator > does not exist.\n"

    if [[ ${VALIDATOR_ADDRESS} != "" ]]; then
        VALIDATOR_INFO=$(${COSMOS} q staking validator ${VALIDATOR_ADDRESS} -oj --node ${NODE} --home ${NODE_HOME} 2>&1)
        if [[ ${VALIDATOR_INFO} != *"NotFound"* ]]; then
            VALIDATOR_EXISTING_STATUS="OK"
            VALIDATOR_EXISTING_TEXT="validator > exists.\n"
        fi
    fi
}

function __Humaniting() {

    ORIGINAL_VALUE=${1}
    DENOM_VALUE=${2}
    PRICE_VALUE=${3}

    SCALE=2
    HUMAN_VALUE=0

    while [[ $(echo "${HUMAN_VALUE} == 0" | bc) -eq 1 ]]; do
        if [[ ${PRICE_VALUE} == "" && ${DENOM_VALUE} == "" ]]; then
            HUMAN_VALUE=$(printf "%.${SCALE}f" $(echo "${ORIGINAL_VALUE}")) 
        elif [[ ${PRICE_VALUE} == "" ]]; then
            HUMAN_VALUE=$(printf "%.${SCALE}f" $(echo "${ORIGINAL_VALUE} ${DENOM_VALUE}" | awk '{print $1 / $2}'))        
        else
            HUMAN_VALUE=$(printf "%.${SCALE}f" $(echo "${ORIGINAL_VALUE} ${DENOM_VALUE} ${PRICE_VALUE}" | awk '{print $1 / $2 * $3}')) 
        fi
        ((SCALE=SCALE+1))
    done

    if [[ ${PRICE_VALUE} == "" && ${DENOM_VALUE} == "" ]]; then
        HUMAN_VALUE=$(printf "%.${SCALE}f" $(echo "${ORIGINAL_VALUE}")) 
    elif [[ ${PRICE_VALUE} == "" ]]; then
        HUMAN_VALUE=$(printf "%.${SCALE}f" $(echo "${ORIGINAL_VALUE} ${DENOM_VALUE}" | awk '{print $1 / $2}'))        
    else
        HUMAN_VALUE=$(printf "%.${SCALE}f" $(echo "${ORIGINAL_VALUE} ${DENOM_VALUE} ${PRICE_VALUE}" | awk '{print $1 / $2 * $3}')) 
    fi

    if [[ ${HUMAN_VALUE: -1} == "0" ]]; then HUMAN_VALUE=${HUMAN_VALUE::-1}; fi

    echo -e ${HUMAN_VALUE}
}

function __TokenPrice() {

    TOKEN_PRICE_STATUS="NOT_OK"

    # trying to get token price on osmosis, cosmostation and coingecko
    TOKEN_PRICE=$(curl -sk "https://api-osmosis.imperator.co/tokens/v2/${TOKEN}" | jq ".[].price" 2>&1)
    if [[ ${TOKEN_PRICE} == *"null"* || ${TOKEN_PRICE} == *"error"* ]]; then
        TOKEN_PRICE=$(curl -sk "https://api-utility.cosmostation.io/v1/market/price?id=u${TOKEN}" | jq ".[].prices[].current_price" 2>&1)
        if [[ ${TOKEN_PRICE} == *"null"* || ${TOKEN_PRICE} == *"error"* ]]; then
            TOKEN_PRICE="n/a"
        fi
    fi

    if [[ ${TOKEN_PRICE} != "n/a" ]]; then
        TOKEN_PRICE_STATUS="OK"
        TOKEN_PRICE_HUMAN=$(__Humaniting "${TOKEN_PRICE}")
        TOKEN_PRICE_TEXT="token_price > \$${TOKEN_PRICE_HUMAN}.\n"
    else
        TOKEN_PRICE_HUMAN=0
        TOKEN_PRICE_TEXT="token_price > \$n/a.\n"
    fi
}

function __DelegatorBalance() {

    DENOM_STRING=$(${COSMOS} q bank balances ${DELEGATOR_ADDRESS} --chain-id ${CHAIN} --node ${NODE} --output json --home ${NODE_HOME} | jq -r '.balances[].denom')
    DENOM_ARRAY=($(echo "${DENOM_STRING}" | tr ' ' '\n'))
    for i in "${!DENOM_ARRAY[@]}"; do
        if [[ ${DENOM_ARRAY[i]} == *"${TOKEN}"* ]]; then UTOKEN=${DENOM_ARRAY[i]}; fi
    done

    BALANCE_TOKEN=$(${COSMOS} q bank balances ${DELEGATOR_ADDRESS} --chain-id ${CHAIN} --node ${NODE} --output json --home ${NODE_HOME} | jq -r '.balances[] | select(.denom == "'"${UTOKEN}"'") .amount' | bc)
    if [[ ${BALANCE_TOKEN} != "" ]]; then
        BALANCE_TOKEN_HUMAN=$(__Humaniting "${BALANCE_TOKEN}" "${DENOM}")
    else
        BALANCE_TOKEN_HUMAN=0
    fi

    BALANCE_TEXT="balance > ${BALANCE_TOKEN_HUMAN} ${TOKEN}.\n"

    if [[ ${TOKEN_PRICE_HUMAN} != 0 && ${BALANCE_TOKEN_HUMAN} != 0 ]]; then
        BALANCE_USD=$(__Humaniting "${BALANCE_TOKEN}" "${DENOM}" "${TOKEN_PRICE}")
        BALANCE_TEXT=${BALANCE_TEXT::-3}", \$${BALANCE_USD}.\n"
    fi
}

function __ValidatorStake() {

    LOCAL_EXPLORER=$(${COSMOS} q staking validators --node ${NODE} --output json --home ${NODE_HOME} --limit=999999999)
    VALIDATOR_STRING=$(echo ${LOCAL_EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens + " " + .description.moniker' | sort -gr | nl | grep -F ${MONIKER})
    if [[ ${VALIDATOR_STRING} == "" ]]; then
        VALIDATOR_STRING=$(echo ${LOCAL_EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_UNBONDING")' | jq -r '.tokens + " " + .description.moniker' | sort -gr | nl | grep -F ${MONIKER})
        if [[ ${VALIDATOR_STRING} == "" ]]; then
            VALIDATOR_STRING=$(echo ${LOCAL_EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_UNBONDED")' | jq -r '.tokens + " " + .description.moniker' | sort -gr | nl | grep -F ${MONIKER})
        fi
    fi
    
    # validator stake in tokens
    VALIDATOR_STAKE_TOKEN=$(echo ${VALIDATOR_STRING} | awk '{print $2}')

    if [[ ${VALIDATOR_STAKE_TOKEN} != "" ]]; then
        VALIDATOR_STAKE_TOKEN_HUMAN=$(__Humaniting "${VALIDATOR_STAKE_TOKEN}" "${DENOM}")
    else
        VALIDATOR_STAKE_TOKEN_HUMAN=0
    fi
    STAKE_TEXT="stake > ${VALIDATOR_STAKE_TOKEN_HUMAN} ${TOKEN}.\n"

    # validator stake in usd
    if [[ ${TOKEN_PRICE_HUMAN} != 0 && ${VALIDATOR_STAKE_TOKEN_HUMAN} != 0 ]]; then
        VALIDATOR_STAKE_USD=$(__Humaniting "${VALIDATOR_STAKE_TOKEN}" "${DENOM}" "${TOKEN_PRICE}")
        STAKE_TEXT=${STAKE_TEXT::-3}", \$${VALIDATOR_STAKE_USD}.\n"
    fi
}

function __PrivateValidatorKey() {

    CONSENSUS_PUBKEY=$(${COSMOS} q staking validator ${VALIDATOR_ADDRESS} -oj --node ${NODE} --home ${NODE_HOME} | jq -r ".consensus_pubkey.key")
    CURRENT_PUBKEY=$(curl -s localhost:${PORT}/status | jq -r ".result.validator_info.pub_key.value")

    if [[ ${CONSENSUS_PUBKEY} == ${CURRENT_PUBKEY} ]]; then
        PRIVKEY_STATUS="OK"
        PRIVKEY_TEXT="priv_key > right.\n"
    else
        PRIVKEY_STATUS="NOT_OK"
        PRIVKEY_TEXT="_priv_key > wrong.\n"
        if [[ ${IGNORE_WRONG_PRIVKEY} == "true" ]]; then PRIVKEY_TEXT=${PRIVKEY_TEXT::-3}", but we know.\n"; else ALARM=1; fi
    fi
}

function __BondingStatus() {

    VALIDATOR_INFO=$(${COSMOS} query staking validator ${VALIDATOR_ADDRESS} --node ${NODE} --output json --home ${NODE_HOME})
    BONDING_STATUS=$(echo ${VALIDATOR_INFO} | jq -r '.status')

    if [[ "${BONDING_STATUS}" != "BOND_STATUS_BONDED" ]]; then
        BONDING_STATUS="NOT_OK"
        JAILED_STATUS=$(echo ${VALIDATOR_INFO} | jq -r .'jailed')

        if [[ "${JAILED_STATUS}" == "true" ]]; then
            
            JAILED_UNTIL_STRING=$(${COSMOS} q slashing signing-info $(${COSMOS} tendermint show-validator) -o json | jq -r '.jailed_until')
            JAILED_UNTIL_DATE=$(echo ${JAILED_UNTIL_STRING} | grep -Eo "[0-9]*-[0-9]*-[0-9]*")
            
            JAILED_UNTIL_TIME=$(echo ${JAILED_UNTIL_STRING} | grep -Eo "[0-9]*:[0-9]*:[0-9]*")
            JAILED_TIME_LEFT_SEC=$(( ($(date --date="${JAILED_UNTIL_DATE} ${JAILED_UNTIL_TIME}" +%s) - $(date +%s) ) ))

            if [[ $(echo "${JAILED_TIME_LEFT_SEC} > 0" | bc) -eq 1 ]]; then
                BONDING_STATUS_TEXT="_status > jailed.\n_until > ${JAILED_UNTIL_DATE} ${JAILED_UNTIL_TIME} UTC+0.\n_unjailable > false.\n"
            else
                BONDING_STATUS_TEXT="_status > jailed.\n_until > ${JAILED_UNTIL_DATE} ${JAILED_UNTIL_TIME} UTC+0.\n_unjailable > true.\n"
            fi
            if [[ ${IGNORE_WRONG_PRIVKEY} == "true" && ${PRIVKEY_STATUS} == "NOT_OK" ]]; then BONDING_STATUS_TEXT=${BONDING_STATUS_TEXT::-3}", but we know.\n"; else ALARM=1; fi
        else
            BONDING_STATUS_TEXT="_status > inactive.\n"
            if [[ ${IGNORE_INACTIVE_STATUS} == "true" ]]; then BONDING_STATUS_TEXT=${BONDING_STATUS_TEXT::-3}", but we know.\n"; else ALARM=1; fi
        fi
    else
        BONDING_STATUS="OK"
        BONDING_STATUS_TEXT="status > active.\n"
    fi
}

function __ValidatorPlace() {

    LOCAL_EXPLORER=$(${COSMOS} q staking validators --node ${NODE} --output json --home ${NODE_HOME} --limit=999999999)
    VALIDATORS_COUNT=$(echo ${LOCAL_EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens' | sort -gr | wc -l)
    VALIDATOR_STRING=$(echo ${LOCAL_EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens + " " + .description.moniker' | sort -gr | nl | grep -F ${MONIKER})
    VALIDATOR_POSITION=$(echo ${VALIDATOR_STRING} | awk '{print $1}')
    ACTIVE_VALIDATOR_SET=$(${COSMOS} q staking params --node ${NODE} --output json --home ${NODE_HOME} | jq ."max_validators")

    PLACE_STATUS="OK"
    PLACE_TEXT="place > ${VALIDATOR_POSITION}/${ACTIVE_VALIDATOR_SET}.\n"

    SAFE_VALIDATOR_PLACE=$(echo ${ACTIVE_VALIDATOR_SET}-${POSITION_GAP_ALARM} | bc -l)
    if ((${VALIDATOR_POSITION} > ${SAFE_VALIDATOR_PLACE})); then 
        if [[ ${IGNORE_INACTIVE_STATUS} != "true" ]]; then
            ALARM=1
            PLACE_STATUS="NOT_OK"
            PLACE_TEXT='_'${PLACE_TEXT}
        fi
    fi
}

function __ValidatorOutstandingRewards() {


    REWARDS_TOTAL_TOKEN_HUMAN=0
    if [[ $(${COSMOS} query distribution commission ${VALIDATOR_ADDRESS} --chain-id ${CHAIN} --node ${NODE} --output json 2>&1) != *"unknown command"* ]]; then
        COMMISSION_TOKEN=$(${COSMOS} query distribution commission ${VALIDATOR_ADDRESS} --chain-id ${CHAIN} --node ${NODE} --output json | jq '.commission[] | select(.denom == "'"${UTOKEN}"'") .amount' | bc)
        if [[ ${COMMISSION_TOKEN} == "" ]]; then COMMISSION_TOKEN=0; fi
        REWARDS_TOKEN=$(${COSMOS} query distribution rewards ${DELEGATOR_ADDRESS} --chain-id ${CHAIN} --node ${NODE} --output json | jq '.total[] | select(.denom == "'"${UTOKEN}"'") .amount' | bc)
        if [[ ${REWARDS_TOKEN} == "" ]]; then REWARDS_TOKEN=0; fi
        REWARDS_TOTAL_TOKEN=$(echo "scale=2;(${COMMISSION_TOKEN}+${REWARDS_TOKEN})/1" | bc)
        if (( $(bc <<< "${REWARDS_TOTAL_TOKEN} < 1") )); then REWARDS_TOTAL_TOKEN="0${REWARDS_TOTAL_TOKEN}"; fi

        if [[ ${REWARDS_TOTAL_TOKEN} != "00" ]]; then
            REWARDS_TOTAL_TOKEN_HUMAN=$(__Humaniting "${REWARDS_TOTAL_TOKEN}" "${DENOM}")
        else
            REWARDS_TOTAL_TOKEN_HUMAN=0
        fi
    fi

    REWARDS_TEXT="outstanding > ${REWARDS_TOTAL_TOKEN_HUMAN} ${TOKEN}.\n"

    if [[ ${TOKEN_PRICE_HUMAN} != 0 && ${REWARDS_TOTAL_TOKEN_HUMAN} != 0 ]]; then
        REWARDS_USD=$(__Humaniting "${REWARDS_TOTAL_TOKEN}" "${DENOM}" "${TOKEN_PRICE}")
        REWARDS_TEXT=${REWARDS_TEXT::-3}", \$${REWARDS_USD}.\n"
    fi
}

function __ValidatorExpectedRewards() {

    # great thanks to landeros#9587
    EPOCH="false"
    APR_TEXT=""
    APR_IDEAL=""
    APR_REAL=""

    # get inflation info
    INFLATION=$(${COSMOS} query mint inflation --node ${NODE} --home ${NODE_HOME} 2>&1)
    if [[ ${INFLATION} == *"unknown"* || ${INFLATION} == *"error"* ]]; then
        EPOCH_MINT_PROVISION=$(${COSMOS} query inflation epoch-mint-provision --node ${NODE} --home ${NODE_HOME} 2>&1)
        if [[ ${EPOCH_MINT_PROVISION} != *"unknown"* && ${EPOCH_MINT_PROVISION} != *"error"* ]]; then
            EPOCH="true"
            INFLATION_PERC=$(${COSMOS} query inflation inflation-rate --node ${NODE} --home ${NODE_HOME} 2>&1 | grep -oE "[0-9]*.[0-9]*" | head -1)
            INFLATION=$(echo "${INFLATION_PERC} 100" | awk '{print $1 / $2}')
        else
            INFLATION=0
        fi
    fi

    if [[ $(echo "${INFLATION} > 0" | bc) -eq 1 ]]; then
        if [[ ${EPOCH} == "false" ]]; then
            MINT_PARAMS=$(${COSMOS} query mint params --output json --node ${NODE} --home ${NODE_HOME} 2>&1)
            ANNUAL_PROVISION=$(${COSMOS} query mint annual-provisions --node ${NODE} --home ${NODE_HOME} 2>&1)
            BONDED_TOKENS=$(${COSMOS} query staking pool --output json --node ${NODE} --home ${NODE_HOME} | jq -r ".bonded_tokens")
            BLOCKS_PER_YEAR_IDEAL=$(echo ${MINT_PARAMS} | jq -r ".blocks_per_year")
            BLOCKS_PER_YEAR_REAL=$(echo "31536000 ${BLOCK_EXECUTION_TIME}"| awk '{print $1 / $2}')
            BLOCK_PROVISION_IDEAL=$(echo "${ANNUAL_PROVISION} ${BLOCKS_PER_YEAR_IDEAL}"| awk '{print $1 / $2}')
            BLOCK_PROVISION_REAL=$(echo "${BLOCK_PROVISION_IDEAL} ${BLOCKS_PER_YEAR_REAL}"| awk '{print $1 * $2}')
            COMMUNITY_TAX=$(${COSMOS} query distribution params --output json --node ${NODE} --home ${NODE_HOME} | jq -r ".community_tax")
            APR_IDEAL=$(echo "${ANNUAL_PROVISION} ${COMMUNITY_TAX} ${BONDED_TOKENS}" | awk '{print $1 * ((1 - $2 ) / $3)}')
            APR_REAL=$(echo "${APR_IDEAL} ${BLOCK_PROVISION_REAL} ${ANNUAL_PROVISION}" | awk '{print $1 * ($2 / $3)}')
        else
            EPOCH_PERIOD=$($COSMOS query inflation period --node ${NODE} --home ${NODE_HOME})
            if [[ ${EPOCH_PERIOD} == 0 ]]; then EPOCH_PERIOD=1; fi
            EPOCHS_PER_YEAR=$(echo "365 ${EPOCH_PERIOD}" | awk '{print $1 / $2}')
            EPOCH_MINT_PROVISION=$(${COSMOS} query inflation epoch-mint-provision --node ${NODE} --home ${NODE_HOME} 2>&1 | grep -oE "[0-9]*.[0-9]*" | head -1)
            ANNUAL_PROVISION_IDEAL=$(echo "${EPOCH_MINT_PROVISION} ${EPOCHS_PER_YEAR}" | awk '{print $1 * $2}')
            BONDED_TOKENS=$(${COSMOS} query staking pool --output json --node ${NODE} --home ${NODE_HOME} | jq -r ".bonded_tokens")
            STAKING_REWARDS=$(${COSMOS} q inflation params -o json --node ${NODE} --home ${NODE_HOME} | jq -r ".inflation_distribution.staking_rewards")
            APR_IDEAL=$(echo "${ANNUAL_PROVISION_IDEAL} ${STAKING_REWARDS} ${BONDED_TOKENS}" | awk '{print $1 * ($2 / $3)}')
        fi

        if [[ ${APR_REAL} != "" ]]; then APR=${APR_REAL}; else APR=${APR_IDEAL}; fi
        APR_PERC=$(printf "%.2f" $(echo "${APR} 100" | awk '{print $1 * $2}'))
        APR_TEXT="apr > ${APR_PERC}%.\n"

        TOTAL_STAKE=$(${COSMOS} query staking validator ${VALIDATOR_ADDRESS} --output json --node ${NODE} --home ${NODE_HOME} | jq -r ".tokens")
        SELF_STAKE=$(${COSMOS} query staking delegation ${DELEGATOR_ADDRESS} ${VALIDATOR_ADDRESS} --output json --node ${NODE} --home ${NODE_HOME} | jq -r ".balance.amount")
        OTHER_STAKE=$(echo "${TOTAL_STAKE} ${SELF_STAKE}" | awk '{print $1 - $2}')

        ANNUAL_REWARD_FOR_SELF_STAKE=$(echo "${SELF_STAKE} ${APR}" | awk '{print $1 * $2}')
        MONTHLY_SELF_STAKE_REWARD=$(echo "${ANNUAL_REWARD_FOR_SELF_STAKE} 12" | awk '{print $1 / $2}')

        VALIDATOR_RATE=$(${COSMOS} query staking validator ${VALIDATOR_ADDRESS} --output json --node ${NODE} --home ${NODE_HOME} | jq -r ".commission.commission_rates.rate")
        OTHER_STAKE_LIKE_SELF=$(echo "${OTHER_STAKE} ${VALIDATOR_RATE}" | awk '{print $1 * $2}')
        ANNUAL_REWARD_FOR_OTHER_STAKE=$(echo "${OTHER_STAKE_LIKE_SELF} ${APR}" | awk '{print $1 * $2}')
        MONTHLY_OTHER_STAKE_REWARD=$(echo "${ANNUAL_REWARD_FOR_OTHER_STAKE} 12" | awk '{print $1 / $2}')

        SALARY_TOKEN=$(printf "%.9f" $(echo "${MONTHLY_SELF_STAKE_REWARD} ${MONTHLY_OTHER_STAKE_REWARD}" | awk '{print $1 + $2}'))
        if (( $(bc <<< "${SALARY_TOKEN} < 1") )); then SALARY_TOKEN="0${SALARY_TOKEN}"; fi

        if [[ ${SALARY_TOKEN} != "" ]]; then
            SALARY_TOKEN_HUMAN=$(__Humaniting "${SALARY_TOKEN}" "${DENOM}")
        else
            SALARY_TOKEN_HUMAN=0
        fi

        SALARY_TEXT="salary/mo > ${SALARY_TOKEN_HUMAN} ${TOKEN}.\n"

        if [[ ${TOKEN_PRICE_HUMAN} != 0 && ${SALARY_TOKEN_HUMAN} != 0 ]]; then
            SALARY_USD=$(__Humaniting "${SALARY_TOKEN}" "${DENOM}" "${TOKEN_PRICE}")
            SALARY_TEXT=${SALARY_TEXT::-3}", \$${SALARY_USD}.\n"
        fi
    else
        SALARY_TEXT="salary > inflation is disabled.\n"
    fi
}

function __ValidatorMissedBlocks() {

    MISSED_BLOCKS_STATUS="OK"

    # if we don't ignore wrong key, then run 'SignedAndMissedBlocks'
    if [[ ${IGNORE_WRONG_PRIVKEY} != "true" ]]; then

        # init some variables
        SIGNED=0
        MISSED=0
        MAX_ROW=0
        MISSED_IN_A_ROW=0
        LOOKBEHIND_BLOCKS=100

        # get slashing params
        SLASHING=$(${COSMOS} q slashing params -o json --node ${NODE} --home ${NODE_HOME})
        WINDOW=$(echo ${SLASHING} | jq -r ".signed_blocks_window")
        MIN_SIGNED=$(echo ${SLASHING} | jq -r ".min_signed_per_window")
        JAILED_AFTER=$(echo ${WINDOW}-${WINDOW}*${MIN_SIGNED} | bc -l | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}')
        MISSED_BLOCKS_FOR_ALARM=$(echo ${JAILED_AFTER}/10 | bc -l | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}')

        # get some info about node
        NODE_STATUS_TOTAL=$(curl -s localhost:${PORT}/status)
        VALIDATOR_PUB_ADDRESS=$(echo ${NODE_STATUS_TOTAL} | jq -r ".result.validator_info.address")
        LATEST_BLOCK_HEIGHT=$(echo ${NODE_STATUS_TOTAL} | jq -r ".result.sync_info.latest_block_height")
        LATEST_BLOCK_TIME=$(echo ${NODE_STATUS_TOTAL} | jq -r ".result.sync_info.latest_block_time")

        # get the latest available block in local history
        FIRST_AVAILABLE_BLOCK=$(curl -sk "localhost:${PORT}/block?height=1")
        if [[ ${FIRST_AVAILABLE_BLOCK} == *"error"* ]]; then
            FIRST_AVAILABLE_BLOCK=$(echo ${FIRST_AVAILABLE_BLOCK} | jq ".error.data" | grep -Eo "[0-9]*" | tail -1)
        else
            FIRST_AVAILABLE_BLOCK=1
        fi

        # get the start block
        START_BLOCK=$((${LATEST_BLOCK_HEIGHT}-${LOOKBEHIND_BLOCKS}+1))
        if [[ $(echo "${FIRST_AVAILABLE_BLOCK} > ${START_BLOCK}" | bc) -eq 1 ]]; then START_BLOCK=${FIRST_AVAILABLE_BLOCK}; fi    
        
        for (( BLOCK = ${START_BLOCK}; BLOCK <= ${LATEST_BLOCK_HEIGHT}; BLOCK++ )); do

            # check for validator signature
            SIGNATURE=$(curl -s localhost:${PORT}/block?height=${BLOCK} | jq -r ".result.block.last_commit.signatures[].validator_address" | grep ${VALIDATOR_PUB_ADDRESS})

            # if signature exists > signed + 1
            if [[ ${SIGNATURE} != "" ]]; then
                MISSED_IN_A_ROW=0
                ((SIGNED=SIGNED+1))

            # if signature does not exist > missed + 1
            else
                ((MISSED_IN_A_ROW=MISSED_IN_A_ROW+1))
                ((MISSED=MISSED+1))
                if (( ${MISSED_IN_A_ROW} > ${MAX_ROW} )); then MAX_ROW=${MISSED_IN_A_ROW}; fi
            fi
        done    

        # if missed is more than 10 > check the whole window before jail
        if [[ ${MISSED} > "10" ]]; then

            # zeroing variables
            SIGNED=0
            MISSED=0
            MAX_ROW=0
            MISSED_IN_A_ROW=0
            LOOKBEHIND_BLOCKS=${JAILED_AFTER}
            
            # get the start block
            START_BLOCK=$((${LATEST_BLOCK_HEIGHT}-${LOOKBEHIND_BLOCKS}+1))
            if [[ $(echo "${FIRST_AVAILABLE_BLOCK} > ${START_BLOCK}" | bc) -eq 1 ]]; then START_BLOCK=${FIRST_AVAILABLE_BLOCK}; fi 

            for (( BLOCK = ${START_BLOCK}; BLOCK <= ${LATEST_BLOCK_HEIGHT}; BLOCK++ )); do
                
                # check for validator signature
                SIGNATURE=$(curl -s localhost:${PORT}/block?height=${BLOCK} 2>&1 | jq -r ".result.block.last_commit.signatures[].validator_address" | grep ${VALIDATOR_PUB_ADDRESS})
                # if signature exists > signed + 1
                if [[ ${SIGNATURE} != "" ]]; then
                    MISSED_IN_A_ROW=0
                    ((SIGNED=SIGNED+1))

                # if signature does not exist > missed + 1
                else
                    ((MISSED_IN_A_ROW=MISSED_IN_A_ROW+1))
                    ((MISSED=MISSED+1))
                    if (( ${MISSED_IN_A_ROW} > ${MAX_ROW} )); then MAX_ROW=${MISSED_IN_A_ROW}; fi
                fi
            done
        fi

        MISSED_TEXT="missed > ${MISSED} blocks, ${MAX_ROW} in a row.\n"
        JAILED_AFTER_TEXT="jailed > after ${JAILED_AFTER} missed blocks.\n"
        MISSED_BLOCKS_TEXT=${MISSED_TEXT}${JAILED_AFTER_TEXT}

        if (( ${MISSED} > ${MISSED_BLOCKS_FOR_ALARM} )); then 
            ALARM=1
            MISSED_BLOCKS_STATUS="NOT_OK"
            MISSED_BLOCKS_TEXT='_'${MISSED_TEXT}'_'${JAILED_AFTER_TEXT}
        fi
    else
        MISSED_BLOCKS_TEXT="missed > ignoring.\n"
    fi
}

function __UnvotedProposals() {

    GOV_STATUS="OK"

    # get proposals
    PROPOSALS=$(${COSMOS} q gov proposals --node ${NODE} --limit 999999999 --output json 2>&1)

    # if at least one proposal exists
    if [[ ${PROPOSALS} != *"no proposals found"* ]]; then
        # get array of active proposals
        ACTIVE_PROPOSALS_STRING=$(echo ${PROPOSALS} | jq '.proposals[] | select(.status=="PROPOSAL_STATUS_VOTING_PERIOD")' | jq -r '.proposal_id')
        if [[ ${ACTIVE_PROPOSALS_STRING} == "null" ]]; then
            ACTIVE_PROPOSALS_STRING=$(echo ${PROPOSALS} | jq '.proposals[] | select(.status=="PROPOSAL_STATUS_VOTING_PERIOD")' | jq -r '.id')
        fi
        ACTIVE_PROPOSALS_ARRAY=($(echo "${ACTIVE_PROPOSALS_STRING}" | tr ' ' '\n'))

        # init array of unvoted proposals
        UNVOTED_ARRAY=( )

        # run loop on each proposal
        for i in "${!ACTIVE_PROPOSALS_ARRAY[@]}"; do
            # if vote does not exist, add proposal id to 'UNVOTED_ARRAY'
            VOTE=$(${COSMOS} q gov votes ${ACTIVE_PROPOSALS_ARRAY[i]} --limit 999999999 --node ${NODE} --output json | jq -r '.votes[].voter' | grep ${DELEGATOR_ADDRESS})
            if [[ ${VOTE} == "" ]]; then UNVOTED_ARRAY+=(${ACTIVE_PROPOSALS_ARRAY[i]}); fi
        done

            # if exists at least one unvoted proposal
            if (( ${#UNVOTED_ARRAY[@]} > 0 )); then
                GOV_STATUS="NOT_OK"
                GOV_TEXT="_gov >"

                # add proposal id to message
                for i in "${!UNVOTED_ARRAY[@]}"; do
                    GOV_TEXT=${GOV_TEXT}' #'${UNVOTED_ARRAY[i]}
                    if (( ${i} < ${#UNVOTED_ARRAY[@]}-1 )); then GOV_TEXT=${GOV_TEXT}','; else GOV_TEXT=${GOV_TEXT}'.\n'; fi
                done
            else
                GOV_TEXT="gov > no unvoted proposals.\n"
            fi
    else
        GOV_TEXT="gov > no any proposals.\n"
    fi
}

function __UpgradePlan() {

    UPGRADE_PLAN=$(${COSMOS} q upgrade plan --node ${NODE} --output json 2>&1)
    if [[ ${UPGRADE_PLAN} != *"no upgrade scheduled"* ]]; then
        UPGRADE_STATUS="NOT_OK"

        UPGRADE_HEIGHT=$(echo ${UPGRADE_PLAN} | jq -r ".height")
        UPGRADE_NAME=$(echo ${UPGRADE_PLAN} | jq -r ".name")

        BLOCKS_BEFORE_UPGRADE=$((${UPGRADE_HEIGHT}-${LATEST_BLOCK_HEIGHT}))
        ESTIMATED_TIME_BEFORE_UPGRADE_IN_SEC=$(printf "%.0f" $(echo "scale=2; ${BLOCKS_BEFORE_UPGRADE}*${BLOCK_EXECUTION_TIME}" | bc))
        ESTIMATED_TIME_BEFORE_UPGRADE_IN_MIN=$(echo "scale=2; ${BLOCKS_BEFORE_UPGRADE}*${BLOCK_EXECUTION_TIME}/60" | bc)

        ETBU_D=$((${ESTIMATED_TIME_BEFORE_UPGRADE_IN_SEC}/60/60/24))
        ETBU_H=$((${ESTIMATED_TIME_BEFORE_UPGRADE_IN_SEC}/60/60%24))
        ETBU_M=$((${ESTIMATED_TIME_BEFORE_UPGRADE_IN_SEC}/60%60))

        if (( ${ETBU_D} > 0 )); then ETBU_TEXT="${ETBU_TEXT}${ETBU_D}d "; fi
        if (( ${ETBU_D} > 0 )); then ETBU_APPR="${ETBU_APPR}${ETBU_D}day "; fi
        if (( ${ETBU_H} > 0 )); then ETBU_TEXT="${ETBU_TEXT}${ETBU_H}h "; fi
        if (( ${ETBU_H} > 0 )); then ETBU_APPR="${ETBU_APPR}${ETBU_H}hour "; fi
        if (( ${ETBU_M} > 0 )); then ETBU_TEXT="${ETBU_TEXT}${ETBU_M}m "; fi
        if (( ${ETBU_M} > 0 )); then ETBU_APPR="${ETBU_APPR}${ETBU_M}min "; fi

        APPROXIMATE_UPGRADE_TIME=$(date -d "+${ETBU_APPR}" +"%b %d, %H:%M")

        UPGRADE_NAME_TEXT="_upgrade > ${UPGRADE_NAME}.\n"

        UPGRADE_APPR_TIME_TEXT="_appr_time > ${APPROXIMATE_UPGRADE_TIME}, ${ETBU_TEXT::-1} left.\n"
        UPGRADE_TEXT=${UPGRADE_NAME_TEXT}${UPGRADE_APPR_TIME_TEXT}

        if [[ $(echo "${ESTIMATED_TIME_BEFORE_UPGRADE_IN_MIN} < ${UPGRADE_ALARM_IN_MIN}" | bc) -eq 1 && ${ESTIMATED_TIME_BEFORE_UPGRADE_IN_MIN} != 0 ]]; then
            ALARM=1
        fi
    else
        UPGRADE_STATUS="OK"
        UPGRADE_TEXT="upgrade > no upgrade scheduled.\n"
    fi
}

function __ValidatorMonitorMessageCollection() {

    VALIDATOR_MONITOR_LOG_MESSAGE=""
    VALIDATOR_MONITOR_TELEGRAM_MESSAGE=""

    # node status
    VALIDATOR_MONITOR_LOG_MESSAGE+=${NODE_STATUS_TEXT}
    if [[ ${NODE_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${NODE_STATUS_TEXT}; fi

    # block gap and exp/me
    VALIDATOR_MONITOR_LOG_MESSAGE+=${BLOCK_GAP_TEXT}
    if [[ ${BLOCK_GAP_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${BLOCK_GAP_TEXT}; fi

    # chain vitality
    VALIDATOR_MONITOR_LOG_MESSAGE+=${CHAIN_VITALITY_TEXT}
    if [[ ${CHAIN_VITALITY_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${CHAIN_VITALITY_TEXT}; fi

    # block exectution time
    VALIDATOR_MONITOR_LOG_MESSAGE+=${BLOCK_EXECUTION_TIME_TEXT}

    # validator existing
    VALIDATOR_MONITOR_LOG_MESSAGE+=${VALIDATOR_EXISTING_TEXT}
    if [[ ${VALIDATOR_EXISTING_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${VALIDATOR_EXISTING_TEXT}; fi

    # priv_key
    VALIDATOR_MONITOR_LOG_MESSAGE+=${PRIVKEY_TEXT}
    if [[ ${PRIVKEY_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${PRIVKEY_TEXT}; fi

    # bonding status
    VALIDATOR_MONITOR_LOG_MESSAGE+=${BONDING_STATUS_TEXT}
    if [[ ${BONDING_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${BONDING_STATUS_TEXT}; fi

    # validator place
    VALIDATOR_MONITOR_LOG_MESSAGE+=${PLACE_TEXT}
    # if [[ ${PLACE_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${PLACE_TEXT}; fi
    VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${PLACE_TEXT}
    
    # token price
    VALIDATOR_MONITOR_LOG_MESSAGE+=${TOKEN_PRICE_TEXT}
    if [[ ${TOKEN_PRICE_STATUS} == "OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${TOKEN_PRICE_TEXT}; fi

    # apr
    VALIDATOR_MONITOR_LOG_MESSAGE+=${APR_TEXT}

    # stake
    VALIDATOR_MONITOR_LOG_MESSAGE+=${STAKE_TEXT}
    VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${STAKE_TEXT}

    # balance
    VALIDATOR_MONITOR_LOG_MESSAGE+=${BALANCE_TEXT}
    VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${BALANCE_TEXT}

    # rewards
    VALIDATOR_MONITOR_LOG_MESSAGE+=${REWARDS_TEXT}
    VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${REWARDS_TEXT}

    # salary
    VALIDATOR_MONITOR_LOG_MESSAGE+=${SALARY_TEXT}
    VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${SALARY_TEXT}

    # missed blocks
    VALIDATOR_MONITOR_LOG_MESSAGE+=${MISSED_BLOCKS_TEXT}
    if [[ ${MISSED_BLOCKS_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${MISSED_BLOCKS_TEXT}; fi

    # gov
    VALIDATOR_MONITOR_LOG_MESSAGE+=${GOV_TEXT}
    if [[ ${GOV_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${GOV_TEXT}; fi

    # upgrade
    VALIDATOR_MONITOR_LOG_MESSAGE+=${UPGRADE_TEXT}
    if [[ ${UPGRADE_STATUS} == "NOT_OK" ]]; then VALIDATOR_MONITOR_TELEGRAM_MESSAGE+=${UPGRADE_TEXT}; fi
}

function __VariablesZeroing() {

    # zeroing
    ALARM=0
    BLOCK_GAP_TEXT=""
    BLOCK_GAP=""
    CHAIN_VITALITY_TEXT=""
    CHAIN_VITALITY_STATUS=""
    BLOCK_EXECUTION_TIME_TEXT=""
    VALIDATOR_EXISTING_TEXT=""
    VALIDATOR_EXISTING_STATUS=""
    PRIVKEY_TEXT=""
    PRIVKEY_STATUS=""
    BONDING_STATUS_TEXT=""
    BONDING_STATUS=""
    PLACE_TEXT=""
    PLACE_STATUS=""
    TOKEN_PRICE_TEXT=""
    APR_TEXT=""
    STAKE_TEXT=""
    BALANCE_TEXT=""
    REWARDS_TEXT=""
    SALARY_TEXT=""
    MISSED_BLOCKS_TEXT=""
    MISSED_BLOCKS_STATUS=""
    GOV_TEXT=""
    GOV_STATUS=""
    UPGRADE_TEXT=""
    UPGRADE_STATUS=""

    IGNORE_INACTIVE_STATUS=""
    IGNORE_WRONG_PRIVKEY=""
    ALLOW_SERVICE_RESTART=""
    SERVICE=""
    POSITION_GAP_ALARM=0
    BLOCK_GAP_ALARM=100
    CURL=""
    MONIKER=""
    DELEGATOR_ADDRESS=""
    VALIDATOR_ADDRESS=""
    TOKEN=""
    DENOM=0
    PROJECT=""
    COSMOS=""
    CONFIG=""
    CHAT_ID_ALARM=""
    CHAT_ID_STATUS=""
    BOT_TOKEN=""
}

function __ValidatorMonitorPrestart() {

    if [[ ${1} != "" ]]; then CONFIG=${1}; fi

    # greeting
    PROJECT_INTRO="<b>${PROJECT} ⠀|⠀ ${MONIKER}</b>\n\n"
    __SeparatorOutput "${PROJECT}  |  ${MONIKER}"

    # get some static values
    NODE=$(cat ${CONFIG}/config.toml | grep -oPm1 "(?<=^laddr = \")([^%]+)(?=\")")
    NODE_HOME=$(echo ${CONFIG} | rev | cut -c 8- | rev)
    CHAIN=$(cat ${CONFIG}/genesis.json | jq .chain_id | sed -E 's/.*"([^"]+)".*/\1/')
    PORT=$(echo ${NODE} | awk 'NR==1 {print; exit}' | grep -o ":[0-9]*" | awk 'NR==2 {print; exit}' | cut -c 2-)
}

function __ValidatorMonitorPostend() {
    __ValidatorMonitorMessageCollection

    # generate 'final_message' from the given text
    FINAL_LOG_MESSAGE=$(__PrettyMessageOutput "${VALIDATOR_MONITOR_LOG_MESSAGE}")
    FINAL_TELEGRAM_MESSAGE=$(__PrettyMessageOutput "${VALIDATOR_MONITOR_TELEGRAM_MESSAGE}")

    # print 'final_message'
    echo -e ${FINAL_LOG_MESSAGE}

    # add to the 'final_message' some format before sending to telegram
    FINAL_TELEGRAM_MESSAGE="${PROJECT_INTRO}<code>${FINAL_TELEGRAM_MESSAGE}</code>"

    # if 'ALARM' == 1 > send 'alarm_message'
    if [[ ${ALARM} == "1" ]]; then
        __OneMessageToTelegram "${CHAT_ID_ALARM}" "${FINAL_TELEGRAM_MESSAGE}"
    fi

    # send 'log_message'
    echo "${FINAL_TELEGRAM_MESSAGE}\n" >> "./${CHAT_ID_STATUS}"
}

function __ValidatorMonitor() {
    __NodeStatus # get 'NODE_STATUS', 'NODE_STATUS_TEXT'
    if [[ ${NODE_STATUS} == "OK" ]]; then __BlockGap; # get 'BLOCK_GAP_STATUS', 'BLOCK_GAP_TEXT'
        if [[ ${BLOCK_GAP_STATUS} == "OK" ]]; then __ChainVitality; # get 'CHAIN_VITALITY_STATUS', 'CHAIN_VITALITY_TEXT'
            if [[ ${CHAIN_VITALITY_STATUS} == "OK" ]]; then
                __BlockExecutionTime # get 'BLOCK_EXECUTION_TIME'
                __ValidatorExisting # get 'VALIDATOR_EXISTING_STATUS', 'VALIDATOR_EXISTING_TEXT'
                if [[ ${VALIDATOR_EXISTING_STATUS} == "OK" ]]; then
                    __PrivateValidatorKey # get 'PRIVKEY_STATUS', 'PRIVKEY_TEXT'
                    __BondingStatus # get 'BONDING_STATUS', 'BONDING_STATUS_TEXT'
                    if [[ ${BONDING_STATUS} == "OK" ]]; then
                        __TokenPrice # get 'TOKEN_PRICE'
                        __DelegatorBalance # get 'BALANCE_TEXT'
                        __ValidatorStake # get 'STAKE_TEXT'
                        __ValidatorPlace # get 'PLACE_STATUS', 'PLACE_TEXT'
                        __ValidatorOutstandingRewards # get 'REWARDS_TEXT'
                        __ValidatorExpectedRewards # get 'SALARY_TEXT'
                        __ValidatorMissedBlocks # get 'MISSED_BLOCKS_STATUS', 'MISSED_BLOCKS_TEXT'
                    fi
                    __UnvotedProposals # get 'GOV_STATUS', 'GOV_TEXT'
                fi
            fi
            __UpgradePlan # get 'UPGRADE_STATUS', 'UPGRADE_TEXT'
        fi
    fi
}

function __OneMessageToTelegram() {

    # init
    CHAT_ID=${1}; MESSAGE=${2}

    # send a given message to a given chat
    curl --header 'Content-Type: application/json' \
    --request 'POST' \
    --data '{"chat_id":"'"${CHAT_ID}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    > /dev/null 2>&1
}



function __TelegramReport() {

    # get chat ids from temp files
    CHAT_IDS=($(ls | grep -E "[0-9]{2,}"))

    # send a message from temp files to chats
    for i in "${!CHAT_IDS[@]}"; do

        # send separator message
        if [[ ${SEND_TELEGRAM_SEPARATOR} != "false" ]]; then
            __OneMessageToTelegram "${CHAT_IDS[i]}" "<code>/// $(date '+%F %T') ///</code>"
        fi

        # send a log message
        __OneMessageToTelegram "${CHAT_IDS[i]}" "$(cat "./${CHAT_IDS[i]}")"
    done

    # delete temp log files
    rm ~/status/-?[0-9]* ~/status/*.temp > /dev/null 2>&1

}

function __SpecificValidatorMonitor() {

    CONF=${1}

    if [[ $(cat ./${CONF}) == *"COSMOS"* ]]; then

        # init some variables
        IGNORE_INACTIVE_STATUS=""
        IGNORE_WRONG_PRIVKEY=""
        ALLOW_SERVICE_RESTART=""
        SERVICE=""
        POSITION_GAP_ALARM=0
        BLOCK_GAP_ALARM=100
        CURL=""
        MONIKER=""
        DELEGATOR_ADDRESS=""
        VALIDATOR_ADDRESS=""
        TOKEN=""
        DENOM=0
        PROJECT=""
        COSMOS=""
        CONFIG=""
        CHAT_ID_ALARM=""
        CHAT_ID_STATUS=""
        BOT_TOKEN=""
        

        # read the config
        source ./${CONF}
        # echo -e " "
        
        # if config directory, config.toml and genesis.json exist
        if [[ -e "${CONFIG}" &&  -e "${CONFIG}/config.toml" && -e "${CONFIG}/genesis.json" ]]; then              

            __ValidatorMonitorPrestart # 
            __ValidatorMonitor # run 'ValidatorMonitor'
            __ValidatorMonitorPostend # perform final calculates
            rm "./${CHAT_ID_STATUS}" > /dev/null 2>&1

        else
            echo -e "\n${PROJECT}  |  ${MONIKER}\n"
            echo "we have some problems with config. maybe config files do not exist."
            MESSAGE="<b>${PROJECT} ⠀|⠀ ${MONIKER}</b>\n\n<code>we have some problems with config.\nremove '${CONF}' or fix it.</code>\n\n"

            # send 'alarm_message'
            __OneMessageToTelegram "${CHAT_ID_ALARM}" "${MESSAGE}"
        fi
    fi
}

function __ValidatorsMonitor() {

    # run 'ValidatorMonitor' loop with every '*.conf' file in the 'status' folder
    for CONF in *.conf; do
        if [[ $(cat ./${CONF}) == *"COSMOS"* ]]; then
            __VariablesZeroing # zeroing

            # read the config
            source ./${CONF}
            
            # if config directory, config.toml and genesis.json exist
            if [[ -e "${CONFIG}" &&  -e "${CONFIG}/config.toml" && -e "${CONFIG}/genesis.json" ]]; then    
                __ValidatorMonitorPrestart # perform validator monitor prepare 
                __ValidatorMonitor # perform main calculates
                __ValidatorMonitorPostend # perform final calculates

            else
                echo -e "\n${PROJECT}  |  ${MONIKER}\n"
                echo "we have some problems with config. maybe config files do not exist."
                MESSAGE="<b>${PROJECT} ⠀|⠀ ${MONIKER}</b>\n\n<code>we have some problems with config.\nremove '${CONF}' or fix it.</code>\n\n"

                # send 'alarm_message'
                __OneMessageToTelegram "${CHAT_ID_ALARM}" "${MESSAGE}"
            fi
        fi
    done
}

function Status() {

    cd $HOME/status/
    source ./cosmos.conf
    mkdir -p $HOME/status/temp > /dev/null 2>&1

    if [[ ${TIMEZONE} == "" ]]; then TIMEZONE="Africa/Abidjan"; fi
    export TZ=${TIMEZONE}
 
    if [[ ${1} == "" ]]; then
        __SystemLoad # perform server load checks
        __ValidatorsMonitor # start monitoring for bunch of validators
        __TelegramReport # send results into telegram
    else
        __SpecificValidatorMonitor "${1}" # start monitoring for specific config
    fi

}

# run 'Status "name.conf"' for 'SpecificValidatorMonitor', usecase: ./cosmos.sh "bitsong.conf"
# Status "bitsong.conf"

# run 'Status "${1}"' for 'ValidatorsMonitor'
Status "${1}"

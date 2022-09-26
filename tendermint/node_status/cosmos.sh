#!/bin/bash

function __Send() {

    # print 'TEXT' into 'cosmos.log' for the sake of history
    echo -e ${TEXT}

    # add new text to the 'MESSAGE', which will be sent as 'log_message' or 'alarm_message'
    # if 'SEND' == 1, it becomes 'alarm_message', otherwise it's 'log_message'
    MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
}

function __PreMessage() {

    # init some premessages
    CPU_T="cpu_used >>>>"
    RAM_T="ram_used >>>>"
    SWAP_T="swap_used >>>"
    PART_T="part_used >>>"
    LOAD_T="serv_load >>>"
    DISK_SPARE_T="disk_spare >>"
    DISK_USED_T="disk_used >>>"

    MISSED_T="missed >>>>>>"
    TRAIN_T="train >>>>>>>"
    JAILED_A="_jailed >>>>>"

    GOV_T="gov >>>>>>>>>"

    UPGRADE_T="upgrade >>>>>"
    TIME_L_T="_time_left >>"
    APPR_T_T="_appr_time >>"

    EXP_ME_T="exp/me >>>>>>"
    ACTIVE_A="_active >>>>>"
    PLACE_T="place >>>>>>>"
    STAKE_T="stake >>>>>>>"

    PRIVKEY_T="priv_key >>>>"
}

function __DiskVitality() {

    # init some variables
    KEY=0

    # trying to install 'smartmontools'
    if [[ $(/usr/sbin/smartctl -V 2>&1) == *"not found"* || $(/usr/sbin/fdisk -v 2>&1) == *"not found"* ]]; then
        apt-get install smartmontools fdisk -y > /dev/null 2>&1
    fi

    # if successfuly installed > check disk
    if [[ $(/usr/sbin/smartctl -V 2>&1) != *"not found"* || $(/usr/sbin/fdisk -v 2>&1) != *"not found"* ]]; then
        DISK_NAME_STRING=$(/usr/sbin/fdisk -l | grep -e "Disk /dev/*" | grep -oE "/dev/[[:alnum:]]*")
        DISK_NAME_ARRAY=($(echo "${DISK_NAME_STRING}" | tr ' ' '\n'))
        for i in "${!DISK_NAME_ARRAY[@]}"; do
            DISK_INFO=$(/usr/sbin/smartctl -s on -a ${DISK_NAME_ARRAY[i]})
            if [[ ${DISK_INFO} != *"Unable to detect device"* ]]; then
                KEY=1
                DISK_NAME=$(echo ${DISK_NAME_ARRAY[i]})
                SPARE=$(echo ${DISK_INFO} | grep -o "Available Spare: [0-9]*" | grep -o "[0-9]*")
                SPARE_THRESHOLD=$(echo ${DISK_INFO} | grep -o "Available Spare Threshold: [0-9]*" | grep -o "[0-9]*")
                PERCENTAGE_USED=$(echo ${DISK_INFO} | grep -o "Percentage Used: [0-9]*" | grep -o "[0-9]*")

                if [[ $(echo "${SPARE} < ${SPARE_THRESHOLD}" | bc) -eq 1 ]]; then
                    SEND=1
                    CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"\n_${DISK_SPARE_T::-1} ${DISK_NAME:5} has only ${SPARE}% spare."
                else
                    CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"\n${DISK_SPARE_T} ${DISK_NAME:5} has ${SPARE}% spare."
                fi

                if [[ $(echo "${PERCENTAGE_USED} > ${DISK_PERCENTAGE_USED_ALARM}" | bc) -eq 1 ]]; then
                    SEND=1
                    CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"\n_${DISK_USED_T::-1} ${DISK_NAME:5} has ${PERCENTAGE_USED}% used."
                else
                    CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"\n${DISK_USED_T} ${DISK_NAME:5} has ${PERCENTAGE_USED}% used."
                fi
            fi
        done

        if [[ ${KEY} == 0 ]]; then
            CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"\nthere is no disk which can be tested."
        fi
    else
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"\ninstall tools manually: 'apt-get install smartmontools fdisk -y'."
    fi
}

function __ServerLoad() {

    # add new text to the 'MESSAGE', which will be sent as 'log_message' or 'alarm_message'
    MESSAGE="<b>${SERVER} ⠀|⠀ load</b>\n\n"
    echo -e "${SERVER}  |  load\n"

    # init some variables
    CPU_ALARM=80
    RAM_ALARM=80
    PARTITION_ALARM=80
    CPU_LOAD_MESSAGE=""
    TEXT=""
    SEND=0

    # read 'cosmos.conf'
    . ./cosmos.conf

    # get CPU load
    CPU=$(printf "%.0f" $(echo "scale=2; 100-$(mpstat | tail -1 | awk 'NF {print $NF}')" | bc))
    if (( $(echo "${CPU} > ${CPU_ALARM}" | bc -l) )); then
        SEND=1
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"_${CPU_T::-1} ${CPU}%.\n"
    else
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"${CPU_T} ${CPU}%.\n"
    fi

    # get RAM load
    free -g > ~/temp.txt
    RAM_TOTAL=$(cat ~/temp.txt | awk '{print $2}' | awk 'NR==2 {print; exit}')"G"
    RAM_USED=$(cat ~/temp.txt | awk '{print $3}' | awk 'NR==2 {print; exit}')"G"
    RAM_PERC=$(printf "%.0f" $(echo "scale=2; ${RAM_USED}/${RAM_TOTAL}*100" | bc | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}'))
    if (( $(echo "${RAM_PERC} > ${RAM_ALARM}" | bc -l) )); then
        SEND=1
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"_${RAM_T::-1} ${RAM_PERC}%.\n"
    else
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"${RAM_T} ${RAM_PERC}%.\n"
    fi

    # get SWAP load
    SWAP_TOTAL=$(cat ~/temp.txt | grep "Swap" | awk '{print $2}')"G"
    SWAP_USED=$(cat ~/temp.txt | grep "Swap" | awk '{print $3}')"G"
    SWAP_PERC=$(printf "%.0f" $(echo "scale=2; ${SWAP_USED}/${SWAP_TOTAL}*100" | bc | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}'))
    if [[ ${SWAP_TOTAL} != "0G" && ${SWAP_TOTAL} != "G" && ${SWAP_USED} != "0G" && ${SWAP_USED} != "G" ]]; then
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"${SWAP_T} ${SWAP_PERC}%.\n"
    fi

    # get disk load
    df -h / > ~/temp.txt
    DISK_PERC=$(printf "%.0f" $(cat ~/temp.txt | awk '{print $5}' | awk 'NR==2 {print; exit}' | tr -d '%'))
    if (( $(echo "${DISK_PERC} > ${PARTITION_ALARM}" | bc -l) )); then
        SEND=1
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"_${PART_T::-1} ${DISK_PERC}%.\n"
    else
        CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"${PART_T} ${DISK_PERC}%.\n"
    fi

    # get system load
    SYSTEM_LOAD=$(cat /proc/loadavg | awk '{print $2}')
    CPU_LOAD_MESSAGE=${CPU_LOAD_MESSAGE}"${LOAD_T} ${SYSTEM_LOAD}.\n"

    __DiskVitality

    # delete the temp file
    rm ~/temp.txt

    # if 'SEND' == 1 > send 'MESSAGE' into 'alarm telegram channel'
    if [[ ${SEND} == "1" ]]; then
        TEXT=${CPU_LOAD_MESSAGE}
        __Send

        curl --header 'Content-Type: application/json' \
        --request 'POST' \
        --data '{"chat_id":"'"${CHAT_ID_ALARM}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        > /dev/null 2>&1
    else
        echo -e "${CPU_LOAD_MESSAGE}"
    fi
}

function __LastChainBlock() {
    # get the last explorer's block
    if [[ ${CURL} == *"v1/status"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq ".block_height" | tr -d '"')
        if [[ ${LATEST_CHAIN_BLOCK} == "null" ]]; then
            LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq ".data.block_height" | tr -d '"')
        fi
    elif [[ ${CURL} == *"bank/total"* ]] || [[ ${CURL} == *"blocks/latest"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq ".height" | tr -d '"')
        if [[ ${LATEST_CHAIN_BLOCK} == "null" ]]; then
            LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq ".block.header.height" | tr -d '"')
        fi
    elif [[ ${CURL} == *"block?latest"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq ".result.block.header.height" | tr -d '"')
    else
        LATEST_CHAIN_BLOCK="0"
    fi
    echo ${LATEST_CHAIN_BLOCK}
}

function __SignedAndMissedBlocks() {
    # init some variables
    SIGNED=0
    MISSED=0
    MAX_ROW=0
    LOOKBEHIND_BLOCKS=100

    # get slashing params
    SLASHING=$(${COSMOS} q slashing params -o json --node ${NODE} --home ${NODE_HOME})
    WINDOW=$(echo ${SLASHING} | jq ".signed_blocks_window" | tr -d '"')
    MIN_SIGNED=$(echo ${SLASHING} | jq ".min_signed_per_window" | tr -d '"')
    JAILED_AFTER=$(echo ${WINDOW}-${WINDOW}*${MIN_SIGNED} | bc -l | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}')
    # LOOKBEHIND_BLOCKS=${JAILED_AFTER}
    MISSED_BLOCKS_FOR_ALARM=$(echo ${JAILED_AFTER}/10 | bc -l | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}')
    # echo ${MISSED_BLOCKS_FOR_ALARM}

    # get some info about node
    NODE_STATUS_TOTAL=$(curl -s localhost:${PORT}/status)
    VALIDATOR_ADDRESS=$(echo ${NODE_STATUS_TOTAL} | jq .result.validator_info.address | tr -d '"')
    LATEST_BLOCK_HEIGHT=$(echo ${NODE_STATUS_TOTAL} | jq .result.sync_info.latest_block_height | tr -d '"')
    LATEST_BLOCK_TIME=$(echo ${NODE_STATUS_TOTAL} | jq .result.sync_info.latest_block_time | tr -d '"')

    # check only 100 last blocks
    START_BLOCK=$((${LATEST_BLOCK_HEIGHT}-${LOOKBEHIND_BLOCKS}+1))
    for (( BLOCK = ${START_BLOCK}; BLOCK <= ${LATEST_BLOCK_HEIGHT}; BLOCK++ )); do
        # check for validator signature
        SIGNATURE=$(curl -s localhost:${PORT}/block?height=${BLOCK} | jq .result.block.last_commit.signatures[].validator_address | tr -d '"' | grep ${VALIDATOR_ADDRESS})

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
        LOOKBEHIND_BLOCKS=${JAILED_AFTER}

        START_BLOCK=$((${LATEST_BLOCK_HEIGHT}-${LOOKBEHIND_BLOCKS}+1))
        for (( BLOCK = ${START_BLOCK}; BLOCK <= ${LATEST_BLOCK_HEIGHT}; BLOCK++ )); do
            # check for validator signature
            SIGNATURE=$(curl -s localhost:${PORT}/block?height=${BLOCK} | jq .result.block.last_commit.signatures[].validator_address | tr -d '"' | grep ${VALIDATOR_ADDRESS})

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

    # if missed more than 10% of allowed missed blocks before jail > alarm
    if (( ${MISSED} > ${MISSED_BLOCKS_FOR_ALARM} )); then
        SEND=1
        TEXT="_${MISSED_T::-1} ${MISSED}/${LOOKBEHIND_BLOCKS} last blocks.\n_${TRAIN_T::-1} ${MAX_ROW} missed in a row.\n${JAILED_A} after ${JAILED_AFTER} missed blocks."
        __Send
    elif (( ${MISSED} > 0 )); then
        TEXT="${MISSED_T} ${MISSED} blocks.\n${TRAIN_T} ${MAX_ROW} missed in a row."
        __Send
    else
        echo "${MISSED_T} ${MISSED} blocks."
    fi
}

function __UnvotedProposals() {

    # get proposals
    PROPOSALS=$(${COSMOS} q gov proposals --node ${NODE} --home ${NODE_HOME} --limit 999999999 --output json 2>&1)

    # if at least one proposal exists
    if [[ ${PROPOSALS} != *"no proposals found"* ]]; then
        # get array of active proposals
        ACTIVE_PROPOSALS_STRING=$(echo ${PROPOSALS} | jq '.proposals[] | select(.status=="PROPOSAL_STATUS_VOTING_PERIOD")' | jq '.proposal_id' | tr -d '"')
        ACTIVE_PROPOSALS_ARRAY=($(echo "${ACTIVE_PROPOSALS_STRING}" | tr ' ' '\n'))

        # init array of unvoted proposals
        UNVOTED_ARRAY=( )

        # run loop on each proposal
        for i in "${!ACTIVE_PROPOSALS_ARRAY[@]}"; do
            # if vote does not exist, add proposal id to 'UNVOTED_ARRAY'
            VOTE=$(${COSMOS} q gov votes ${ACTIVE_PROPOSALS_ARRAY[i]} --limit 999999999 --node ${NODE} --home ${NODE_HOME} --output json | jq '.votes[].voter' | tr -d '"' | grep ${DELEGATOR_ADDRESS})
            if [[ ${VOTE} == "" ]]; then UNVOTED_ARRAY+=(${ACTIVE_PROPOSALS_ARRAY[i]}); fi
        done

            # if exists at least one unvoted proposal
            if (( ${#UNVOTED_ARRAY[@]} > 0 )); then
                TEXT="_${GOV_T::-1}"

                # add proposal id to message
                for i in "${!UNVOTED_ARRAY[@]}"; do
                    TEXT=${TEXT}' #'${UNVOTED_ARRAY[i]}
                    if (( ${i} < ${#UNVOTED_ARRAY[@]}-1 )); then TEXT=${TEXT}','; else TEXT=${TEXT}'.'; fi
                done
                __Send
            else
                echo "${GOV_T} no unvoted proposals."
            fi
    else
        echo "${GOV_T} no any proposals."
    fi
}

function __AverageBlockExecutionTime() {

    # init some variables
    LOOKBEHIND_BLOCKS=100

    # get some info about node
    NODE_STATUS_TOTAL=$(curl -s localhost:${PORT}/status)

    # get last block time and height
    LATEST_BLOCK_HEIGHT=$(echo ${NODE_STATUS_TOTAL} | jq .result.sync_info.latest_block_height | tr -d '"')
    LATEST_BLOCK_TIME=$(echo ${NODE_STATUS_TOTAL} | jq .result.sync_info.latest_block_time | tr -d '"' | grep -oE "[0-9]*:[0-9]*:[0-9]*")
    IFS=':' read -ra HMS <<< "$LATEST_BLOCK_TIME"
    LATEST_BLOCK_TIME_IN_SEC=$(echo ${HMS[0]}*3600+${HMS[1]}*60+${HMS[2]} | bc -l)

    # get upgrade block time and height
    UPGRADE_BLOCK_HEIGHT=$((${LATEST_BLOCK_HEIGHT}-${LOOKBEHIND_BLOCKS}))
    UPGRADE_BLOCK_TIME=$(${COSMOS} q block ${UPGRADE_BLOCK_HEIGHT} --node ${NODE} --home ${NODE_HOME} | jq ".block.header.time" | tr -d '"' | grep -oE "[0-9]*:[0-9]*:[0-9]*")
    IFS=':' read -ra HMS <<< "${UPGRADE_BLOCK_TIME}"
    UPGRADE_BLOCK_TIME_IN_SEC=$(echo ${HMS[0]}*3600+${HMS[1]}*60+${HMS[2]} | bc -l)

    # find the max and the min values
    MAX=${LATEST_BLOCK_TIME_IN_SEC}; MIN=${LATEST_BLOCK_TIME_IN_SEC}
    if (( ${UPGRADE_BLOCK_TIME_IN_SEC} > ${MAX} )); then MAX=${UPGRADE_BLOCK_TIME_IN_SEC}; fi
    if (( ${UPGRADE_BLOCK_TIME_IN_SEC} < ${MIN} )); then MIN=${UPGRADE_BLOCK_TIME_IN_SEC}; fi

    # find the difference between blocks in seconds
    DIFF_IN_SEC=$((${MAX}-${MIN}))
    if (( $(echo "86400 - ${DIFF_IN_SEC}" | bc) < ${DIFF_IN_SEC} )); then
        DIFF_IN_SEC=$((86400 - ${DIFF_IN_SEC})); echo ${DIFF_IN_SEC}
    fi

    # get estimated block exectuion time
    BLOCK_EXECUTION_TIME=$(echo "scale=2;${DIFF_IN_SEC}/100" | bc)
}

function __UpgradePlan() {

    # init some variables
    UPGRADE_ALARM_IN_MIN=30
    ETBU_TEXT=""
    ETBU_APPR=""

    # read 'cosmos.conf'
    . ./cosmos.conf

    # get some info about chain upgrade plan
    UPGRADE_PLAN=$(${COSMOS} q upgrade plan --node ${NODE} --home ${NODE_HOME} --output json 2>&1)

    # if smth is planned, then calculate approximate upgrade time
    if [[ ${UPGRADE_PLAN} != *"no upgrade scheduled"* ]]; then
        UPGRADE_HEIGHT=$(echo ${UPGRADE_PLAN} | jq ".height" | tr -d '"')
        UPGRADE_NAME=$(echo ${UPGRADE_PLAN} | jq ".name" | tr -d '"')

        __AverageBlockExecutionTime
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

        if [[ $(echo "${ESTIMATED_TIME_BEFORE_UPGRADE_IN_MIN} < ${UPGRADE_ALARM_IN_MIN}" | bc) -eq 1 && ${ESTIMATED_TIME_BEFORE_UPGRADE_IN_MIN} != 0 ]]; then
            SEND=1
            TEXT="\n_${UPGRADE_T::-1} ${UPGRADE_NAME}.\n${TIME_L_T} ${ETBU_TEXT::-1}.\n${APPR_T_T} ${APPROXIMATE_UPGRADE_TIME}."
            __Send
        else
            TEXT="\n_${UPGRADE_T::-1} ${UPGRADE_NAME}.\n${TIME_L_T} ${ETBU_TEXT::-1}.\n${APPR_T_T} ${APPROXIMATE_UPGRADE_TIME}."
            __Send
        fi
    else
        echo "${UPGRADE_T} no."
    fi
}

function __NodeStatus() {

    # init some variables
    MESSAGE="<b>${PROJECT} ⠀|⠀ ${MONIKER}</b>\n\n"
    echo -e "${PROJECT}  |  ${MONIKER}\n"
    INACTIVE=""
    SEND=0

    # get some info about node
    NODE_STATUS=$(timeout 5s ${COSMOS} status 2>&1 --node ${NODE} --home ${NODE_HOME})

    # if 'NODE_STATUS' response contains 'connection refused' > instant alarm
    if [[ ${NODE_STATUS} != *"connection refused"* ]] && [[ ${NODE_STATUS} != "" ]]; then
        # get the lastest node and explorer blocks height
        LATEST_NODE_BLOCK=$(echo ${NODE_STATUS} | jq .'SyncInfo'.'latest_block_height' | tr -d '"')
        LATEST_CHAIN_BLOCK=$(__LastChainBlock)

        # if 'CURL' was not set > no compare with explorer height
        if [[ ${CURL} != "" ]] && [[ ${LATEST_CHAIN_BLOCK} != "" ]] && [[ ${LATEST_CHAIN_BLOCK} != "0" ]] && [[ ${LATEST_CHAIN_BLOCK} != "null" ]]; then
            # if we are in the past more than 100 block > alarm
            if ((${LATEST_CHAIN_BLOCK}-${BLOCK_GAP_ALARM} > ${LATEST_NODE_BLOCK})); then
                if [[ ${ALLOW_SERVICE_RESTART} == "true" ]]; then
                    systemctl restart ${SERVICE} > /dev/null 2>&1
                    TEXT="_${EXP_ME_T::-1} ${LATEST_CHAIN_BLOCK}/${LATEST_NODE_BLOCK}. \n\nbut service has been restarted."
                else
                    TEXT="_${EXP_ME_T::-1} ${LATEST_CHAIN_BLOCK}/${LATEST_NODE_BLOCK}."
                fi
                SEND=1
                __Send
            else
                echo "${EXP_ME_T} ${LATEST_CHAIN_BLOCK}/${LATEST_NODE_BLOCK}."
           fi
        else
            echo "${EXP_ME_T} 0/${LATEST_NODE_BLOCK}."
        fi

        # if there is no problem with height
        if [[ ${SEND} == "0" ]]; then

            # check 'priv_key' actuality
            CONSENSUS_PUBKEY=$(${COSMOS} q staking validator ${VALIDATOR_ADDRESS} -oj --node ${NODE} --home ${NODE_HOME} | jq -r ".consensus_pubkey.key")
            CURRENT_PUBKEY=$(curl -s localhost:${PORT}/status | jq -r ".result.validator_info.pub_key.value")
            if [[ ${CONSENSUS_PUBKEY} == ${CURRENT_PUBKEY} ]]; then
                PRIVKEY="right"
                echo "${PRIVKEY_T} right."
            else
                PRIVKEY="wrong"
                if [[ ${IGNORE_WRONG_PRIVKEY} == "true" ]]; then
                    TEXT="_${PRIVKEY_T::-1} wrong, but we know."
                    __Send
                else
                    SEND=1
                    TEXT="_${PRIVKEY_T::-1} wrong."
                    __Send
                fi
            fi

            # get validator info
            VALIDATOR_INFO=$(${COSMOS} query staking validator ${VALIDATOR_ADDRESS} --node ${NODE} --output json --home ${NODE_HOME})
            BOND_STATUS=$(echo ${VALIDATOR_INFO} | jq .'status' | tr -d '"')

            # if 'BOND_STATUS' is different than 'BOND_STATUS_BONDED' > alarm
            if [[ "${BOND_STATUS}" != "BOND_STATUS_BONDED" ]]; then
                # if 'JAILED_STATUS' is 'true' > alarm with 'jailed > true.'
                # if 'JAILED_STATUS' is 'true' > alarm with 'active > false.'
                INACTIVE="true"

                JAILED_STATUS=$(echo ${VALIDATOR_INFO} | jq .'jailed')
                if [[ "${JAILED_STATUS}" == "true" ]]; then
                    if [[ ${IGNORE_WRONG_PRIVKEY} == "true" && ${PRIVKEY} == "wrong" ]]; then
                        TEXT="${JAILED_A} ${JAILED_STATUS}, but we know."
                    else
                        SEND=1
                        TEXT="${JAILED_A} ${JAILED_STATUS}."
                    fi
                else
                    # if 'ignore_inactive_status' is not set or 'false' > alarm
                    if [[ ${IGNORE_INACTIVE_STATUS} != "true" ]]; then SEND=1; fi
                    TEXT="${ACTIVE_A} false."
                fi
                __Send

            # if 'BOND_STATUS' is 'BOND_STATUS_BONDED' > continue
            else
                # get local explorer snapshot and request some info about our validator
                EXPLORER=$(${COSMOS} q staking validators --node ${NODE} --output json --home ${NODE_HOME} --limit=999999999)
                VALIDATORS_COUNT=$(echo ${EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens' | sort -gr | wc -l)
                VALIDATOR_STRING=$(echo ${EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens + " " + .description.moniker' | sort -gr | nl | grep -F ${MONIKER})
                VALIDATOR_POSITION=$(echo ${VALIDATOR_STRING} | awk '{print $1}')
                ACTIVE_VALIDATOR_SET=$(${COSMOS} q staking params --node ${NODE} --output json --home ${NODE_HOME} | jq ."max_validators")

                # alarm if validator is close to become inactive
                SAFE_VALIDATOR_PLACE=$(echo ${ACTIVE_VALIDATOR_SET}-${POSITION_GAP_ALARM} | bc -l)

                if ((${VALIDATOR_POSITION} > ${SAFE_VALIDATOR_PLACE})); then
                    if [[ ${IGNORE_INACTIVE_STATUS} != "true" ]]; then
                        SEND=1
                        TEXT="_${PLACE_T::-1} ${VALIDATOR_POSITION}/${ACTIVE_VALIDATOR_SET}."
                    else
                        TEXT="${PLACE_T} ${VALIDATOR_POSITION}/${ACTIVE_VALIDATOR_SET}."
                    fi
                else
                    TEXT="${PLACE_T} ${VALIDATOR_POSITION}/${ACTIVE_VALIDATOR_SET}."
                fi
                __Send

                # validator active stake
                VALIDATOR_STAKE=$(echo ${VALIDATOR_STRING} | awk '{print $2}')
                TEXT="${STAKE_T} $(echo "scale=2;${VALIDATOR_STAKE}/${DENOM}" | bc) ${TOKEN}."
                __Send
            fi

            if [[ ${INACTIVE} != "true" ]]; then
                if [[ ${IGNORE_WRONG_PRIVKEY} != "true" ]]; then
                    __SignedAndMissedBlocks
                else
                    echo "missed >>>>> ignore, cause of 'IWP'."
                fi
            else
                echo "missed >>>>> ignore, cause of inactive status."
            fi

            # get info about proposals
            __UnvotedProposals

            # get info about upgrades
            __UpgradePlan
        fi
    else
        if [[ ${NODE_STATUS} == "" ]]; then
            if [[ ${ALLOW_SERVICE_RESTART} == "true" ]]; then
                systemctl restart ${SERVICE} > /dev/null 2>&1
                TEXT="_we lost any connection. \n\nbut service has been restarted."
            else
                TEXT="_we lost any connection."
            fi
        else
            if [[ ${ALLOW_SERVICE_RESTART} == "true" ]]; then
                systemctl restart ${SERVICE} > /dev/null 2>&1
                TEXT="_connection is refused. \n\nbut service has been restarted."
            else
                TEXT="_connection is refused."
            fi
        fi

        SEND=1
        __Send
    fi

    # read the config
    # echo ${CONF}
    . ./${CONF}

    # if 'SEND' == 1 > send 'MESSAGE' into 'alarm telegram channel'
    if [[ ${SEND} == "1" ]]; then
        curl --header 'Content-Type: application/json' \
        --request 'POST' \
        --data '{"chat_id":"'"${CHAT_ID_ALARM}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        > /dev/null 2>&1
    fi

    # send 'log_message' only one time per hour
    # if the current minute value is less than 'MINUTE' > send 'log_message', else > ignore
    if (( $(echo "$(date +%M) < ${MINUTE}" | bc -l) )); then
        # write message text into temp file to send all logs via one message
        echo ${MESSAGE} >> "./${CHAT_ID_STATUS}"
    fi
}

function Main() {
    # init some variables
    SEND_LOAD=""
    MINUTE=10
    TIMEZONE="Africa/Abidjan"
    DISK_PERCENTAGE_USED_ALARM=100
    __PreMessage

    # print the current time
    echo -e " "; echo -e "/// $(date '+%F %T') ///"; echo -e " "

    # read 'cosmos.conf'
    cd $HOME/status/ && . ./cosmos.conf
    export TZ=${TIMEZONE}

    # get ServerLoad info
    __ServerLoad

    # run 'NodeStatus' with every '*.conf' file in the 'status' folder
    for CONF in *.conf; do

        # if config at least contains 'COSMOS' string, then go
        if [[ $(cat ${CONF}) == *"COSMOS"* ]]; then

            # init some variables
            IGNORE_INACTIVE_STATUS=""
            IGNORE_WRONG_PRIVKEY=""
            ALLOW_SERVICE_RESTART=""
            POSITION_GAP_ALARM=0
            BLOCK_GAP_ALARM=100

            # read the config
            . ./${CONF}
            echo -e " "

            # if config directory, config.toml and genesis.json exist
            if [[ -e "${CONFIG}" &&  -e "${CONFIG}/config.toml" && -e "${CONFIG}/genesis.json" ]]; then

                # get '--node' and '--chain' value
                NODE=$(cat ${CONFIG}/config.toml | grep -oPm1 "(?<=^laddr = \")([^%]+)(?=\")")
                NODE_HOME=$(echo ${CONFIG} | rev | cut -c 8- | rev)
                CHAIN=$(cat ${CONFIG}/genesis.json | jq .chain_id | sed -E 's/.*"([^"]+)".*/\1/')
                PORT=$(echo ${NODE} | awk 'NR==1 {print; exit}' | grep -o ":[0-9]*" | awk 'NR==2 {print; exit}' | cut -c 2-)

                # run 'NodeStatus'
                __NodeStatus
            else
                echo -e "${PROJECT}  |  ${MONIKER}\n"
                echo "we have some problems with config. maybe config files do not exist."
                MESSAGE="<b>${PROJECT} ⠀|⠀ ${MONIKER}</b>\n\n<code>we have some problems with config.\nremove '${CONF}' or fix it.</code>\n\n"

                # send 'alarm_message'
                curl --header 'Content-Type: application/json' \
                --request 'POST' \
                --data '{"chat_id":"'"${CHAT_ID_ALARM}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                > /dev/null 2>&1
            fi
        fi
    done

    # send 'log_messages' from temp files into chats
    CHAT_IDS=($(ls | grep -E "[0-9]{2,}"))
    for i in "${!CHAT_IDS[@]}"; do
        SLASH="<code>/// $(date '+%F %T') ///</code>"

        curl --header 'Content-Type: application/json' \
        --request 'POST' \
        --data '{"chat_id":"'"${CHAT_IDS[i]}"'","text":"'"$(echo -e ${SLASH})"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        > /dev/null 2>&1

        curl --header 'Content-Type: application/json' \
        --request 'POST' \
        --data '{"chat_id":"'"${CHAT_IDS[i]}"'", "text":"'"$(cat "./${CHAT_IDS[i]}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        > /dev/null 2>&1
    done

    # delete temp log files
    rm ./-?[0-9]* > /dev/null 2>&1
}

# run 'main'
Main

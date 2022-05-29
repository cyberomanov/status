#!/bin/bash

function __sendFunc() {
    # print 'TEXT' into 'cosmos.log' for the sake of history
    echo -e ${TEXT}

    # add new text to the 'MESSAGE', which will be sent as 'log' or 'alarm'
    # if 'SEND' == 1, it becomes 'alarm', otherwise it's 'log'
    MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
}

function __getLastChainBlockFunc() {

    # get the last explorer block
    if [[ ${CURL} == *"v1/status"* ]]
    then
        LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq ".block_height" | tr -d '"')
        if [[ ${LATEST_CHAIN_BLOCK} == "null" ]]
        then
            LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq ".data.block_height" | tr -d '"')
        fi
    elif [[ ${CURL} == *"bank/total"* ]] || [[ ${CURL} == *"blocks/latest"* ]]
    then
        LATEST_CHAIN_BLOCK=$(curl -sk ${CURL} | jq ".height" | tr -d '"')
    else
        LATEST_CHAIN_BLOCK="0"
    fi

    echo ${LATEST_CHAIN_BLOCK}
}

function __getSignedAndMissedBlocksFunc() {

    # get slashing params
    SLASHING=$(${COSMOS} q slashing params -o json --node ${NODE} --home ${NODE_HOME})
    WINDOW=$(echo $SLASHING | jq ".signed_blocks_window" | tr -d '"')
    MIN_SIGNED=$(echo $SLASHING | jq ".min_signed_per_window" | tr -d '"')

    JAILED_AFTER=$(echo ${WINDOW}*${MIN_SIGNED} | bc -l | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}')
    MISSED_BLOCKS_FOR_ALARM=$(echo ${JAILED_AFTER}/10 | bc -l | grep -oE "[0-9]*" | awk 'NR==1 {print; exit}')

    # get some info about node
    NODE_STATUS_TOTAL=$(curl -s localhost:${PORT}/status)

    VALIDATOR_ADDRESS=$(echo $NODE_STATUS_TOTAL | jq .result.validator_info.address | tr -d '"')
    LATEST_BLOCK_HEIGHT=$(echo $NODE_STATUS_TOTAL | jq .result.sync_info.latest_block_height | tr -d '"')
    LATEST_BLOCK_TIME=$(echo $NODE_STATUS_TOTAL | jq .result.sync_info.latest_block_time | tr -d '"')
    TIME=$(date --iso-8601=ns -u)

    PROPOSED=0
    SIGNED=0
    MISSED=0
    MAX_ROW=0

    LOOKBEHIND_BLOCKS=100

    START_BLOCK=$(($LATEST_BLOCK_HEIGHT-$LOOKBEHIND_BLOCKS+1))
    for (( BLOCK = $START_BLOCK; BLOCK <= $LATEST_BLOCK_HEIGHT; BLOCK++ ))
    do
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

    # if missed more than 10% of allowed missed blocks before jail > alarm
    if (( ${MISSED} > ${MISSED_BLOCKS_FOR_ALARM}))
    then
        SEND=1
        TEXT="_missed > ${MISSED}/100 last blocks.\n_train >> ${MAX_ROW} missed in a row.\n_jailed > after ${JAILED_AFTER} missed blocks."
    elif (( ${MISSED} > 0 ))
    then
        TEXT="missed >> ${MISSED} blocks.\ntrain >>> ${MAX_ROW} missed in a row."
    else
        TEXT="missed >> ${MISSED} blocks."
    fi
    __sendFunc
}

function __getUnvotedProposalsFunc() {

    # get proposals
    PROPOSALS=$(${COSMOS} q gov proposals --node ${NODE} --output json 2>&1)

    # if at least one proposal exists
    if [[ ${PROPOSALS} != *"no proposals found"* ]]
    then
        # get array of active proposals
        ACTIVE_PROPOSALS_STRING=$(echo ${PROPOSALS} | jq '.proposals[] | select(.status=="PROPOSAL_STATUS_VOTING_PERIOD")' | jq '.proposal_id' | tr -d '"')
        ACTIVE_PROPOSALS_ARRAY=($(echo "$ACTIVE_PROPOSALS_STRING" | tr ' ' '\n'))

        # init array of unvoted proposals
        UNVOTED_ARRAY=( )

        # run loop on each proposal
        for i in "${!ACTIVE_PROPOSALS_ARRAY[@]}"
        do

            # if vote does not exist, add proposal id to 'UNVOTED_ARRAY'
            VOTE=$(${COSMOS} q gov votes ${ACTIVE_PROPOSALS_ARRAY[i]} --limit 999999999 --node ${NODE} --output json | jq '.votes[].voter' | tr -d '"' | grep ${DELEGATOR_ADDRESS})
            if [[ ${VOTE} == "" ]]
            then
                UNVOTED_ARRAY+=(${ACTIVE_PROPOSALS_ARRAY[i]})
            fi
        done

            # if exists at least one unvoted proposal
            if (( ${#UNVOTED_ARRAY[@]} > 0 ))
            then
                TEXT="_gov >>>>"

                # add proposal id to message
                for i in "${!UNVOTED_ARRAY[@]}"
                do
                TEXT=${TEXT}' #'${UNVOTED_ARRAY[i]}

                # if current id is not the lastest one > add ','; else > add '.'
                if (( ${i} < ${#UNVOTED_ARRAY[@]}-1 ))
                then
                    TEXT=${TEXT}','
                else
                    TEXT=${TEXT}'.'
                fi
            done
        else
            TEXT="gov >>>>> no active proposals."
        fi
    else
        TEXT="gov >>>>> no any proposals."
    fi
    __sendFunc
}


function nodeStatusFunc() {

   MESSAGE="<b>${PROJECT} ⠀|⠀ ${MONIKER}</b>\n\n"
   echo -e "${PROJECT}  |  ${MONIKER}\n"

   # if 'SEND' become '1' > alarm will be sent
   SEND=0
   NODE_STATUS=$(timeout 5s ${COSMOS} status 2>&1 --node ${NODE} --home ${NODE_HOME})

   # if 'NODE_STATUS' response contains 'connection refused' > instant alarm
   if [[ ${NODE_STATUS} != *"connection refused"* ]] && [[ ${NODE_STATUS} != "" ]]
   then

       # get the last block height
       LATEST_NODE_BLOCK=$(echo ${NODE_STATUS} | jq .'SyncInfo'.'latest_block_height' | tr -d '"')

       # get the last explorer block height
       LATEST_CHAIN_BLOCK=$(__getLastChainBlockFunc)

       # if 'CURL' was not set > no compare with explorer height
       if [[ $CURL != "" ]] && [[ $LATEST_CHAIN_BLOCK != "" ]] && [[ $LATEST_CHAIN_BLOCK != "0" ]] && [[ $LATEST_CHAIN_BLOCK != "null" ]]
       then

           # if we are in the past more than 10 block > alarm
           if (( ${LATEST_CHAIN_BLOCK}-10 > ${LATEST_NODE_BLOCK} ))
           then
               SEND=1
               TEXT="_exp/me > ${LATEST_CHAIN_BLOCK}/${LATEST_NODE_BLOCK}."
           else
               TEXT="exp/me >> ${LATEST_CHAIN_BLOCK}/${LATEST_NODE_BLOCK}."
           fi
       else
           TEXT="exp/me >> 0/${LATEST_NODE_BLOCK}."
       fi
       __sendFunc

       # if there is no problem with height
       if [[ ${SEND} == "0" ]]
       then
           # get validator info
           VALIDATOR_INFO=$(${COSMOS} query staking validator ${VALIDATOR_ADDRESS} --node $NODE --output json --home ${NODE_HOME})
           BOND_STATUS=$(echo ${VALIDATOR_INFO} | jq .'status' | tr -d '"')

           # if 'BOND_STATUS' is different than 'BOND_STATUS_BONDED' > alarm
           if [[ "${BOND_STATUS}" != "BOND_STATUS_BONDED" ]]
           then
               SEND=1

               # if 'JAILED_STATUS' is 'true' > alarm with 'jailed > true.'
               # if 'JAILED_STATUS' is 'true' > alarm with 'active* > false.' *active - active set
               JAILED_STATUS=$(echo ${VALIDATOR_INFO} | jq .'jailed')
               if [[ "${JAILED_STATUS}" == "true" ]]
               then
                   TEXT="_jailed > ${JAILED_STATUS}."
               else
                   TEXT="_active > false."
               fi
               __sendFunc

           # if 'BOND_STATUS' is 'BOND_STATUS_BONDED' > continue
           else

               # get local explorer snapshot and request some info about our validator
               EXPLORER=$(${COSMOS} q staking validators --node $NODE --output json --home ${NODE_HOME} --limit=10000)
               VALIDATORS_COUNT=$(echo ${EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens' | sort -gr | wc -l)
               VALIDATOR_STRING=$(echo ${EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens + " " + .description.moniker' | sort -gr | nl | grep -F ${MONIKER})
               VALIDATOR_POSITION=$(echo ${VALIDATOR_STRING} | awk '{print $1}')
               ACTIVE_VALIDATOR_SET=$(${COSMOS} q staking params --node ${NODE} --output json --home ${NODE_HOME} | jq ."max_validators")

               # alarm if validator is close to become inactive
               SAFE_VALIDATOR_PLACE=$(echo ${ACTIVE_VALIDATOR_SET} - ${POSITION_ALARM} | bc -l)

               if (( ${VALIDATOR_POSITION} > ${SAFE_VALIDATOR_PLACE} ))
               then
                   SEND=1
                   TEXT="_place >> ${VALIDATOR_POSITION}/${ACTIVE_VALIDATOR_SET}."
               else
                   TEXT="place >>> ${VALIDATOR_POSITION}/${ACTIVE_VALIDATOR_SET}."
               fi
               __sendFunc

               # validator active stake
               VALIDATOR_STAKE=$(echo ${VALIDATOR_STRING} | awk '{print $2}')
               TEXT="stake >>> $(echo "scale=2;${VALIDATOR_STAKE}/${DENOM}" | bc) ${TOKEN}."
               __sendFunc
           fi

           __getSignedAndMissedBlocksFunc
           __getUnvotedProposalsFunc

       fi
   else

       # if connection is refused or we lost connection > alarm
       SEND=1

       if [[ ${NODE_STATUS} == "" ]]
       then
           TEXT="_we lost any connection."
       else
           TEXT="_connection is refused."
       fi
       __sendFunc
   fi

   # if 'SEND' == 1 > send 'MESSAGE' into 'alarm telegram channel'
   if [[ ${SEND} == "1" ]]
   then
       curl --header 'Content-Type: application/json' \
            --request 'POST' \
            --data '{"chat_id":"'"$CHAT_ID_ALARM"'", "text":"'"$(echo -e $MESSAGE)"'", "parse_mode": "html"}' "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            > /dev/null 2>&1
   # send 'MESSAGE' into 'log telegram channel'
   elif (( $(echo "$(date +%M) < 10" | bc -l) )); then
       curl --header 'Content-Type: application/json' \
            --request 'POST' \
            --data '{"chat_id":"'"$CHAT_ID_STATUS"'", "text":"'"$(echo -e $MESSAGE)"'", "parse_mode": "html"}' "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            > /dev/null 2>&1
   fi
}

# move into 'status' folder
cd $HOME/status/

# run 'nodeStatusFunc' with every '*.conf' file in the 'status' folder
for CONFIG in *.conf
do

    # if config at least contains 'COSMOS' string, then go
    if [[ $(cat $CONFIG) == *"COSMOS"* ]]
    then

        # read the config
        . $CONFIG
        # get '--node' and '--chain' value
        NODE=$(cat ${CONFIG}/config.toml | grep -oPm1 "(?<=^laddr = \")([^%]+)(?=\")")
        NODE_HOME=$(echo $CONFIG | rev | cut -c 8- | rev)
        CHAIN=$(cat ${CONFIG}/genesis.json | jq .chain_id | sed -E 's/.*"([^"]+)".*/\1/')
        PORT=$(echo ${NODE} | awk 'NR==1 {print; exit}' | grep -o ":[0-9]*" | awk 'NR==2 {print; exit}' | cut -c 2-)

        # print the current time
        echo -e " "
        echo -e "/// $(date '+%F %T') ///"
        echo -e " "

        # run main func
        nodeStatusFunc
    fi
done

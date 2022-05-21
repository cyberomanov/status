#!/bin/bash

function __getLastChainBlockFunc() {

    # get the last explorer block with 3 supported creators: cosmostation (mintscan), guru (nodes.guru) and ping (polkachu)
    if [[ $CURL == *"cosmostation"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -s ${CURL} | jq ".block_height" | tr -d '"')
    elif [[ $CURL == *"guru"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -s ${CURL} | jq ".[].height" | tr -d '"')
    elif [[ $CURL == *"postcapitalist"* ]]; then
                LATEST_CHAIN_BLOCK=$(curl -s ${CURL} | jq ".block.header.height" | tr -d '"')
    else
        LATEST_CHAIN_BLOCK=$(curl -s ${CURL} | jq ".height" | tr -d '"')
    fi

    echo ${LATEST_CHAIN_BLOCK}
}

function nodeStatusFunc() {

   MESSAGE="<b>${PROJECT} | ${MONIKER}</b>\n\n"
   echo -e "${PROJECT} | ${MONIKER}\n"

   # if 'SEND' become '1' > alarm will be sent
   SEND=0
   NODE_STATUS=$(${COSMOS} status 2>&1 --node ${NODE})

   # if 'NODE_STATUS' response contains 'connection refused' > instant alarm
   if [[ $NODE_STATUS != *"connection refused"* ]]
   then

       # get the last block height
       LATEST_NODE_BLOCK=$(echo ${NODE_STATUS} | jq .'SyncInfo'.'latest_block_height' | tr -d '"')

       # if 'CURL' was not set > no compare with explorer height
       if [[ $CURL != "" ]]
       then

           # get the last explorer block height
           LATEST_CHAIN_BLOCK=$(__getLastChainBlockFunc)

           # if we are in the past more than 10 block > alarm
           if (( ${LATEST_CHAIN_BLOCK}-10 > ${LATEST_NODE_BLOCK} )); then SEND=1; fi
           TEXT="sync >>> ${LATEST_CHAIN_BLOCK}/${LATEST_NODE_BLOCK}."
       else
           TEXT="sync >>> ${LATEST_NODE_BLOCK}."
       fi

       # print 'TEXT' into 'cosmos.log' for the sake of history
       echo ${TEXT}

       # add new text to the 'MESSAGE', which will be sent as 'log' or 'alarm'
       # if 'SEND' == 1, it becomes 'alarm', otherwise it's 'log'
       MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'

       # get validator info
       VALIDATOR_INFO=$(${COSMOS} query staking validator ${VALIDATOR_ADDRESS} --node $NODE --output json)
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
               TEXT="jailed > ${JAILED_STATUS}."
           else
               TEXT="active > false."
           fi
           echo ${TEXT}
           MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'

       # if 'BOND_STATUS' is 'BOND_STATUS_BONDED' > continue
       else

           # get local explorer snapshot and request some info about our validator
           EXPLORER=$(${COSMOS} q staking validators --node $NODE -o json --limit=1000)
           VALIDATORS_COUNT=$(echo ${EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens' | sort -gr | wc -l)
           VALIDATOR_STRING=$(echo ${EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens + " " + .description.moniker' | sort -gr | nl | grep -F ${MONIKER})
           VALIDATOR_PLACE=$(echo ${VALIDATOR_STRING} | awk '{print $1}')
           MAX_VALIDATOR_COUNT=$(${COSMOS} q staking params --node ${NODE} -o json | jq ."max_validators")

           # validator place in the set
           TEXT="place >> ${VALIDATOR_PLACE}/${MAX_VALIDATOR_COUNT}."
           echo ${TEXT}
           MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'

           # validator active stake
           VALIDATOR_STAKE=$(echo ${VALIDATOR_STRING} | awk '{print $2}')
           TEXT="stake >> $(echo "scale=2;${VALIDATOR_STAKE}/${DENOM}" | bc) ${TOKEN}."
           echo ${TEXT}
           MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
       fi
    else

       # if connection is refused > alarm
       TEXT="connection is refused."
       echo ${TEXT}
       MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>'
       SEND=1
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
        CHAIN=$(cat ${CONFIG}/genesis.json | jq .chain_id | sed -E 's/.*"([^"]+)".*/\1/')

        # print the current time
        echo -e " "
        echo -e "/// $(date '+%F %T') ///"
        echo -e " "

        # run main func
        nodeStatusFunc
    fi
done

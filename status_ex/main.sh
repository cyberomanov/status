#!/bin/bash

function __getLastChainBlockFunc() {
    if [[ $CURL == *"cosmostation"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -s ${CURL} | jq ".block_height" | tr -d '"')
    elif [[ $CURL == *"guru"* ]]; then
        LATEST_CHAIN_BLOCK=$(curl -s ${CURL} | jq ".[].height" | tr -d '"')
    else
        LATEST_CHAIN_BLOCK=$(curl -s ${CURL} | jq ".height" | tr -d '"')
    fi
    echo ${LATEST_CHAIN_BLOCK}
}

function nodeStatusFunc() {
   FUNC_NAME="nodeStatusFunc"
   MESSAGE="<b>${CHAIN}</b>\n\n"
   SEND=0
   NODE_STATUS=$(${COSMOS} status 2>&1 --node ${NODE})

   if [[ $NODE_STATUS != *"connection refused"* ]]; then
       LATEST_CHAIN_BLOCK=$(__getLastChainBlockFunc)
       LATEST_NODE_BLOCK=$(echo ${NODE_STATUS} | jq .'SyncInfo'.'latest_block_height' | tr -d '"')

       if (( ${LATEST_CHAIN_BLOCK}-10 > ${LATEST_NODE_BLOCK} )); then SEND=1; fi

       TEXT="sync >>> ${LATEST_CHAIN_BLOCK}/${LATEST_NODE_BLOCK}."
       echo ${FUNC_NAME} ">>" ${TEXT}
       MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'

       VALIDATOR_INFO=$(${COSMOS} query staking validator ${VALIDATOR_ADDRESS} --node $NODE --output json)
       BOND_STATUS=$(echo ${VALIDATOR_INFO} | jq .'status' | tr -d '"')

       if [[ "${BOND_STATUS}" != "BOND_STATUS_BONDED" ]]; then
           SEND=1
           JAILED_STATUS=$(echo ${VALIDATOR_INFO} | jq .'jailed')
           if [[ "${JAILED_STATUS}" == "true" ]]; then
               TEXT="validator is jailed."
           else
               TEXT="validator is not in the active set."
           fi
           echo ${FUNC_NAME} ">>" ${TEXT}
           MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
       else
           EXPLORER=$(${COSMOS} q staking validators --node $NODE -o json --limit=1000)
           VALIDATORS_COUNT=$(echo ${EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens' | sort -gr | wc -l)
           VALIDATOR_STRING=$(echo ${EXPLORER} | jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens + " " + .description.moniker' | sort -gr | nl | grep ${MONIKER})
           VALIDATOR_PLACE=$(echo ${VALIDATOR_STRING} | awk '{print $1}')
           MAX_VALIDATOR_COUNT=$(${COSMOS} q staking params --node ${NODE} -o json | jq ."max_validators")
           TEXT="place >> ${VALIDATOR_PLACE}/${MAX_VALIDATOR_COUNT}."
           echo ${FUNC_NAME} ">>" ${TEXT}
           MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'

           VALIDATOR_STAKE=$(echo ${VALIDATOR_STRING} | awk '{print $2}')
           TEXT="stake >> $(echo "scale=2;${VALIDATOR_STAKE}/${DENOM}" | bc) ${TOKEN}."
           echo ${FUNC_NAME} ">>" ${TEXT}
           MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>\n'
       fi
       TEXT="status > ${BOND_STATUS}."
       echo ${FUNC_NAME} ">>" ${TEXT}
       MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>'
   else
       TEXT="connection is refused."
       echo ${FUNC_NAME} ">>" ${TEXT}
       MESSAGE=${MESSAGE}'<code>'${TEXT}'</code>'
       SEND=1
   fi

   if [[ ${SEND} == "1" ]]; then
       curl --header 'Content-Type: application/json' \
            --request 'POST' \
            --data '{"chat_id":"'"$CHAT_ID_ALARM"'", "text":"'"$(echo -e $MESSAGE)"'", "parse_mode": "html"}' "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
       > /dev/null 2>&1
   elif (( $(echo "$(date +%M) < 5" | bc -l) )); then
       curl --header 'Content-Type: application/json' \
            --request 'POST' \
            --data '{"chat_id":"'"$CHAT_ID_STATUS"'", "text":"'"$(echo -e $MESSAGE)"'", "parse_mode": "html"}' "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
       > /dev/null 2>&1
   fi
}

for CONFIG in *.conf
do
    . $CONFIG

    echo -e " "
    echo -e "/// $(date '+%F %T') ///"
    echo -e " "

    nodeStatusFunc
done

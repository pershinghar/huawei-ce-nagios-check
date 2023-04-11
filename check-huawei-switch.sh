#!/bin/bash

#
# Nagios Huawei check
# 
# <C> 2017 Jakub Stollmann
#
#

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE=0

# Var's
VERBOSE="N"
HOST="$1"
MSG=""
ENTITYLIST=""
SNMPGET="snmpget -v2c -Oqv -r2 -t1 -c public $HOST"
SNMPWALK="snmpwalk -v2c -Oqn -r2 -t1 -c public $HOST"

if [[ "$5" == "-c" ]]; then
    TMPCRITICAL=$6
else
    TMPCRITICAL=70
fi

if [[ "$3" == "-w" ]]; then
    TMPWARNING=$4
else
    TMPWARNING=60
fi

##############
#FUNCTIONS

debug () {
    if [ "$VERBOSE" == "Y" ]; then
        echo -en "\n<DEBUG>"
        echo -en "$1"
        echo -en "</DEBUG>"
    fi
}

get_entity_list () {
    ENTITYLIST="$(${SNMPWALK} 1.3.6.1.2.1.47.1.1.1.1.7 | awk -F. '{print $NF}'| tr " " "_" | sed 's/_/-/' )"
}

check_operation_byindex () {
    # function to go thru entities, then get operational status
    LIST="$1"
    NAME="$2"
    RTRN=""
    while read -r line; do
        INDEX="$(echo "$line" | cut -d"-" -f1)"
        INDEXHUMAN="$(echo "$line" | cut -d"-" -f2)"
        STATUS="$(${SNMPGET} 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.2."$INDEX")"
        if [ "$STATUS" != "3" ]; then
            RTRN="${NAME}:${INDEXHUMAN} Error;"
        fi
    done <<< "$LIST"
    echo -en "$RTRN"
    return
}
check_fans () {
    # list fans and their status and check it
    # not using function due to special indexing
    FANS="$(${SNMPWALK} 1.3.6.1.4.1.2011.5.25.31.1.1.10.1.7)"
    while read -r line; do
        INDEX="$(echo "$line" | cut -d" " -f1 | awk -F. '{print $NF"-"$(NF-1)}')"
        STATUS="$(echo "$line" | cut -d" " -f1 --complement)"
        if [ "$STATUS" != "1" ]; then
            MSG="${MSG}Fan:${INDEX} Error;"
        fi
    done <<< "$FANS"
    return
}

check_psu () {
    # get power id
    POWERSLOTS="$(echo -e "$ENTITYLIST" | grep "POWER_[0-9]")"
    MSG="${MSG}$(check_operation_byindex "${POWERSLOTS}" "Power")"    
}

check_alarms () {
    :
    # now N/A
}

check_temp () {
    # walk thru all senzors, get non-null
    TEMPS=$(${SNMPWALK} 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.11 | awk -F. '{print $NF}'| tr " " "_" | sed 's/_/-/'| grep -v "[0-9]*-0")
    while read -r line; do
        INDEX="$(echo "$line" | cut -d"-" -f1)"
        INDEXHUMAN="$(echo "$ENTITYLIST" | grep $INDEX | cut -d"-" -f2)"
        TEMP="$(echo "$line" | cut -d"-" -f2)"
        if (( $TEMP > $TMPCRITICAL )); then
            MSG="${MSG}CRITICAL Temp:$INDEXHUMAN Above threshold ($TEMP Celsius)"
            STATE=2;
        elif (( $TEMP > $TMPWARNING )); then
            MSG="${MSG}WARNING Temp:$INDEXHUMAN Above threshold ($TEMP Celsius)"
            STATE=1;
        fi
    done <<< "$TEMPS"
    return
}

check_general () {
    check_fans
    check_psu
    check_temp
}

check_CE12800 () {
    # check cards
    MPUS="$(echo -e "$ENTITYLIST" | grep "MPU")"
    MSG="${MSG}$(check_operation_byindex "${MPUS}" "MPU")"
 
    SFUS="$(echo -e "$ENTITYLIST" | grep "SFU")"
    MSG="${MSG}$(check_operation_byindex "${SFUS}" "SFU")"
 
    CMUS="$(echo -e "$ENTITYLIST" | grep "CMU")"
    MSG="${MSG}$(check_operation_byindex "${CMUS}" "CMU")"
 
    LINECARDS="$(echo -e "$ENTITYLIST" | grep "CE-L24LQ-EC1")"
    MSG="${MSG}$(check_operation_byindex "${LINECARDS}" "Linecard")"
}

check_CE6851 () {

    MAIN="$(echo -e "$ENTITYLIST" | grep "\"CE68[0-9][0-9]-")"
    MSG="${MSG}$(check_operation_byindex "${MAIN}" "Switch")"
}

check_S5735 () {
    check_temp
}

## MAIN

# Check host
if [ "$HOST" == "" ]; then
    echo "Unknown host - check parameters; USAGE: ./check-huawei-swich.sh HOST"
    exit $STATE_UNKNOWN
fi
# Get model & check snmp
if ! MODEL=$(${SNMPGET} .1.3.6.1.4.1.2011.6.3.11.4.0 | tr -d "\""); then
    echo "SNMP Timeout"
    exit $STATE_UNKNOWN
fi

get_entity_list


case "$MODEL" in
    "CE12800")
        check_general
        check_CE12800
        ;;

    "CE6851HI")
        check_general
        check_CE6851
        ;;

    "S5735-L24T4S-A")
        check_S5735
        ;;  

    *)
        check_general
        ;;

esac   

if [ "$MSG" != "" ]; then
    echo "$MSG"
    if [ $STATE == 1 ]; then
        exit $STATE_WARNING
    elif [ $STATE == 2 ]; then
        exit $STATE_CRITICAL
    else
        exit $STATE_CRITICAL
   fi
fi

echo "OK"
exit $STATE_OK 

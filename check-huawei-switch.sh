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

# Var's
VERBOSE="Y"
HOST="$1"
MSG=""
SNMPGET="snmpget -v2c -Oqv -r2 -t1 -c public $HOST"
SNMPWALK="snmpwalk -v2c -Oqn -r2 -t1 -c public $HOST"

##############
#FUNCTIONS

debug () {
    if [ "$VERBOSE" == "Y" ]; then
        echo -en "\n<DEBUG>"
        echo -en $1
        echo -en "</DEBUG>"
    fi
}

check_operation_byindex () {
    # function to go thru entities, then get operational status
    LIST="$1"
    NAME="$2"
    RTRN=""
    while read -r line; do
        INDEX="$(echo "$line" | cut -d" " -f1 | awk -F. '{print $NF}')"
        INDEXHUMAN="$(echo "$line" | cut -d" " -f1 --complement)"
        STATUS="$($SNMPGET 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.2.$INDEX)"
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
    FANS="`$SNMPWALK 1.3.6.1.4.1.2011.5.25.31.1.1.10.1.7`"
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
    POWERSLOTS="$($SNMPWALK 1.3.6.1.2.1.47.1.1.1.1.7 | grep "POWER [0-9]")"
    MSG="${MSG}$(check_operation_byindex "${POWERSLOTS}" "Power")"    
}

check_alarms () {
    :
    # now N/A
}

check_general () {
    check_fans
    check_psu

}

check_CE12800 () {
    # check cards
    MPUS="$($SNMPWALK 1.3.6.1.2.1.47.1.1.1.1.7 | grep "MPU")"
    MSG="${MSG}$(check_operation_byindex ${MPUS} "MPU")"
 
    SFUS="$($SNMPWALK 1.3.6.1.2.1.47.1.1.1.1.7 | grep "SFU")"
    MSG="${MSG}$(check_operation_byindex ${SFUS} "SFU")"
 
    CMUS="$($SNMPWALK 1.3.6.1.2.1.47.1.1.1.1.7 | grep "CMU")"
    MSG="${MSG}$(check_operation_byindex $CMUS "CMU")"
 
    LINECARDS="$($SNMPWALK 1.3.6.1.2.1.47.1.1.1.1.7 | grep "CE-L24LQ-EC1")"
    MSG="${MSG}$(check_operation_byindex $LINECARDS "Linecard")"
}

check_CE6851 () {

    MAIN="$($SNMPWALK 1.3.6.1.2.1.47.1.1.1.1.7 | grep "\"CE68[0-9][0-9]-")"
    MSG="${MSG}$(check_operation_byindex $MAIN "Switch")"
}

## MAIN

# Check host
if [ "$HOST" == "" ]; then
    echo "Unknown host - check parameters"
    exit $STATE_UNKNOWN
fi
# Get model & check snmp
if ! MODEL=$($SNMPGET .1.3.6.1.4.1.2011.6.3.11.4.0 | tr -d "\""); then
    echo "SNMP Timeout"
    exit $STATE_UNKNOWN
fi


case "$MODEL" in
    "CE12800")
        check_general
        check_CE12800
        ;;

    "CE6851HI")
        check_general
        check_CE6851
        ;;

    *)
        check_general
        ;;

esac   

if [ "$MSG" != "" ]; then
    echo "$MSG"
    exit $STATE_CRITICAL
fi

echo "OK"
exit $STATE_OK 

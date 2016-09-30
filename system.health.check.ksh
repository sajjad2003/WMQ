#!/usr/bin/ksh
###############################################################################
#
#       Program Name:   system.health.check.ksh
#
#       Modification History:
#       Date            Name                    What
#       ----------------------------------------------------------------------
#       04/10/2014      Alejandro Ramirez       Initial version
#
#       Copyright (c) 2014 Abbott Laboratories
#       All Rights Reserved.
#
#       No part of this software may be reproduced or transmitted in any form
#       or by any means, electronic, mechanical, photocopying, recording or
#       otherwise, without the prior written consent of Abbott Laboratories.
#       Abbott Internal Use Only
#
###############################################################################
clear
/opt/mqm/bin/mqconfig
QMGRS=`( cd /var/mqm/qmgrs ; ls -d [a-zA-Z]* | tr ! . )`
if [ -t 1 ]; then
	PASS="\033[32mPASS\033[m"
	WARN="\033[33mWARN\033[m"
	FAIL="\033[31mFAIL\033[m"
else
	PASS=PASS
	WARN=WARN
	FAIL=FAIL
fi
#-----------------------------------------------------------------------------
CheckMQprocess()
{
ps -ef | grep $QMGR | grep -v grep | grep $PROCESS > /dev/null
if [ $? -ne 0 ]
then
    printf "  %-20s %-51s $FAIL %b\n" $PROCESS "$DEFINITION"
else
    printf "  %-20s %-51s $PASS %b\n" $PROCESS "$DEFINITION"
fi
}
#-----------------------------------------------------------------------------
CheckMQchannels()
{
echo "DISPLAY CHSTATUS(*)" | runmqsc $QMGR | egrep "STOPPED|RETRYING" > /dev/null
if [ $? -ne 0 ]
then
    printf "  %-20s %-51s $PASS %b\n" "Channels Status"
else
    printf "  %-20s %-51s $FAIL %b\n" "Channels Status" \
    "Found channel(s) stopped or retrying"
fi
}
#-----------------------------------------------------------------------------
CheckQueuesDepth()
{
QUERY="DISPLAY Q(*) where(curdepth gt 4000)"
echo "$QUERY" | runmqsc $QMGR | egrep "QUEUE|CURDEPTH" > /dev/null
if [ $? -ne 0 ]
then
    printf "  %-20s %-51s $PASS %b\n" "Queues Depth"
else
    printf "  %-20s %-51s $WARN %b\n" "Queues Depth" \
    "Found queue(s) with over 4000 messages"
fi
}
#-----------------------------------------------------------------------------
CheckDLQ()
{
QUERY="DISPLAY Q(DLQ) where(curdepth gt 0)"
echo "$QUERY" | runmqsc $QMGR | egrep "QUEUE|CURDEPTH" > /dev/null
if [ $? -ne 0 ]
then
    printf "  %-20s %-51s $PASS %b\n" "DLQ"
else
    printf "  %-20s %-51s $FAIL %b\n" "DLQ" \
    "Found messages in the dead letter queue"
fi
}
#-----------------------------------------------------------------------------
CheckDir()
{
f_size=`df -v ${DIR} | grep $DIR | awk '{ print $5 }'`
if [ $f_size -gt 80 ]
then
    printf "  %-20s %-51s $FAIL %b\n" $DIR $f_size%
else
	if [ $f_size -gt 50 ]
	then
	printf "  %-20s %-51s $WARN %b\n" $DIR $f_size%
	else
	printf "  %-20s %-51s $PASS %b\n" $DIR $f_size%
	fi
fi
}
#-----------------------------------------------------------------------------
CheckCPU()
{
CPU=`vmstat|egrep [0-9]|awk '{print $16}'`
if [ $CPU -gt 60 ]
then
    printf "  %-20s %-51s $WARN %b\n" CPU $CPU%
else
    printf "  %-20s %-51s $PASS %b\n" CPU $CPU%
fi
}
#-----------------------------------------------------------------------------
CheckMem()
{
MEM=`/usr/sbin/swapinfo -M | grep memory | awk '{print $5}' | sed 's/\%//g'`
if [ $MEM -gt 60 ]
then
    printf "  %-20s %-51s $WARN %b\n" Memory $MEM%
else
    printf "  %-20s %-51s $PASS %b\n" Memory $MEM%
fi
}
#-----------------------------------------------------------------------------
CheckMqmErrors()
{
DIR=/var/mqm/errors
if [ -f $DIR/*.FDC ]
then
    printf "  %-20s %-51s $FAIL %b\n" $DIR "FDC files found"
else
    printf "  %-20s %-51s $PASS %b\n" $DIR 
fi
}
#-----------------------------------------------------------------------------
CheckProcessExist()
{
ps -ef | grep -v grep | grep $PROCESS > /dev/null
if [ $? -ne 0 ]
then
    printf "  %-20s %-51s $FAIL %b\n" $PROCESS "$DEFINITION"
else
    printf "  %-20s %-51s $PASS %b\n" $PROCESS "$DEFINITION"
fi
}
#-----------------------------------------------------------------------------

echo "\nOthers"
DIR=/opt/mqm; CheckDir
DIR=/var/mqm; CheckDir
CheckMqmErrors
CheckCPU
CheckMem
#PROCESS=DB.LOGGER; DEFINITION="MFT Database logger"; CheckProcessExist
#PROCESS=FILE.LOGGER; DEFINITION="MFT file logger"; CheckProcessExist

for QMGR in $QMGRS
do
	dspmq -m ${QMGR} | grep Running > /dev/null
	if [ $? -ne 0 ];
		then
			printf "\n%-74s $FAIL %b\n" $QMGR
		else
	printf "\n%-74s $PASS %b\n" $QMGR
	PROCESS=amqzmuc0; DEFINITION="Critical process manager"
	CheckMQprocess
	PROCESS=amqzxma0; DEFINITION="Execution controller"
	CheckMQprocess
	PROCESS=amqzfuma; DEFINITION="OAM process"
        CheckMQprocess
	PROCESS=amqzlaa0; DEFINITION="LQM agents"
	CheckMQprocess
	PROCESS=amqzmuf0; DEFINITION="Utility Manager"
	CheckMQprocess
	PROCESS=amqzmur0; DEFINITION="Restartable process manager"
	CheckMQprocess
	PROCESS=amqzmgr0; DEFINITION="Process controller"
	CheckMQprocess
	PROCESS=amqfqpub; DEFINITION="Publish Subscribe process"
	CheckMQprocess
	PROCESS=amqfcxba; DEFINITION="Broker worker process"
	CheckMQprocess
	PROCESS=amqrrmfa; DEFINITION="The repository process (for clusters)"
	CheckMQprocess
	PROCESS=amqzdmaa; DEFINITION="Deferred message processor"
	CheckMQprocess
	PROCESS=amqpcsea; DEFINITION="The command server"
	CheckMQprocess
	PROCESS=runmqchi; DEFINITION="The channel initiator process"
	CheckMQprocess
	PROCESS=runmqlsr; DEFINITION="The channel listener process"
	CheckMQprocess
	CheckMQchannels
	CheckQueuesDepth
	CheckDLQ
	fi
done
echo "\nBMM"
#PROCESS=qpea; DEFINITION="Extensible Agent"; CheckProcessExist
#PROCESS=qpcfg; DEFINITION="Extension for WebSphere MQ"; CheckProcessExist
#PROCESS=qpmon; DEFINITION="Monitoring Extension for WebSphere MQ"; CheckProcessExist
echo "\nAutoSys"
#PROCESS=cybAgent; DEFINITION="Workload automation agent"; CheckProcessExist


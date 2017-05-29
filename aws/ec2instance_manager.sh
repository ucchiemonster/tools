#!/bin/sh
#起動中のインスタンス情報を取得し、停止する

#停止させないIDをパイプ区切りにする
WHITE_IDS="i-test|addmore"
TCR_URL=WEBHOOKURL
#起動させるインスタンスをシェルの配列で記載
#例：arr=("first" "second" "third")
START_IDS=("i-test")

################################## 
##[起動中のインスタンスIDの取得]
################################## 
#InstanceStatusesの配列の中からInstanceIdとInstanceState.Nameを取り出す。
STS_MAP=`aws ec2 describe-instance-status | jq -r '.InstanceStatuses[] |  { (.InstanceState.Name ): .InstanceId}'`

#起動中のインスタンスIDのみ取り出す
IDS=`echo ${STS_MAP} | jq -r '.running'`

################################## 
##[メイン処理]
################################## 
echo "================================================="
DSTR=`date +'%Y-%m-%d %H:%M:%S'`

## 指定EC2インスタンスの起動(aws ec2 start-instances).
if [ -n "$1" ] && [ $1 = '--start' ] ; then
    for SID in ${START_IDS[@]}; do
      echo "sid->${SID}"
      INSTANCE_STATUS=`aws ec2 describe-instance-status --instance-ids $SID | jq -r '.InstanceStatuses[].InstanceState.Name'` 

      if [ -n "$INSTANCE_STATUS" ] && [ $INSTANCE_STATUS = 'running' ] ; then
          ## 稼働中であれば特に何もしない.
          echo "status is running. nothing to do."
      else
          ## 停止中であれば起動指示.
          echo "status is stopped."
          aws ec2 start-instances --instance-ids $SID
          echo "ec2 instance starting..."
          curl -X POST --data-urlencode "payload={\"text\": \"AWSステータス[${DSTR}]:インスタンス起動(${SID})\"}" $TCR_URL
      fi
    done;
## 指定EC2インスタンスの停止(stop).
elif [ -n "$1" ] && [ $1 = '--stop' ] ; then
    for ID in $IDS; do

        if  `echo ${ID} | egrep -q ${WHITE_IDS} ` ; then
            echo "whitelist.ignore.: ${ID}"
        else 
          echo "stop instance:${ID}"
          aws ec2 stop-instances --instance-ids ${ID}
          curl -X POST --data-urlencode "payload={\"text\": \"AWSステータス[${DSTR}]:起動中のインスタンスを停止しました(${ID})\"}" $TCR_URL
          ## レスポンスの出力用の改行
          echo ""
        fi
    done;
## インスタンスの状態を出力 
elif [ -n "$1" ] && [ $1 = '--send' ] ; then

    echo $STS_MAP
    STS_MAP=`echo $STS_MAP | sed -e s/\"//g`
    BODY="payload={\"text\": \"AWSステータス[${DSTR}]\", \"attachments\": [ { \"title\": \"ec2 runnning instances\", \"value\": \"${STS_MAP}\" } ] }"
    curl -X POST --data-urlencode "${BODY}" $TCR_URL

## 引数無しの場合は何もしない.
else
    if [ -z "$1" ] ; then
        echo "argument is required( --start / --stop ). nothing to do."
    else
        echo "argument is invalid. valid argument is --start or --stop."
    fi
fi


#!/bin/bash

MQTT_SERVER=`cat /etc/inverter/mqtt.json | jq '.server' -r`
MQTT_PORT=`cat /etc/inverter/mqtt.json | jq '.port' -r`
MQTT_TOPIC=`cat /etc/inverter/mqtt.json | jq '.topic' -r`
MQTT_DEVICENAME=`cat /etc/inverter/mqtt.json | jq '.devicename' -r`
MQTT_USERNAME=`cat /etc/inverter/mqtt.json | jq '.username' -r`
MQTT_PASSWORD=`cat /etc/inverter/mqtt.json | jq '.password' -r`
MQTT_CLIENTID=`cat /etc/inverter/mqtt.json | jq '.clientid' -r`
cd /etc/inv1

ret=1
while [ $ret = 1 ];
do
      /usr/bin/pgrep mosquitto > /dev/null
      ret=$?
      /usr/bin/sleep 1
done
/usr/bin/sleep 4

/usr/bin/mosquitto_pub --retain \
    -h $MQTT_SERVER \
    -u "$MQTT_USERNAME" \
    -P "$MQTT_PASSWORD" \
    -t "inv1/status" \
    -m `(cd /etc/inv1 && inverter_poller -r QFLAG| sed "s/Reply:  //")`

while read rawcmd;
do
    #echo "Incoming request send: [$rawcmd] to inverter."
    (cd /etc/inv1 && /usr/local/bin/inverter_poller -r $rawcmd &)
    (cd /etc/inv2 && /usr/local/bin/inverter_poller -r $rawcmd &)
    if [ ${rawcmd:0:2} = 'PE' -o ${rawcmd:0:2} = 'PD' ]; then
        /usr/bin/mosquitto_pub \
          -h $MQTT_SERVER \
          -u "$MQTT_USERNAME" \
          -P "$MQTT_PASSWORD" \
          -t "inv1/status" \
          -m `(cd /etc/inv1 && inverter_poller -r QFLAG| sed "s/Reply:  //")`
    fi
done < <(/usr/bin/mosquitto_sub -h $MQTT_SERVER -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" -t "inv1" -q 1)

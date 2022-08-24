#!/usr/bin/env sh

## need export two environment vars
PORT_PATTERN=${PORT_PATTERN:-"(8080|8090)"}
METRICS_SERVER_API=${METRICS_SERVER_API:-"http://vminsert-host/insert/0/prometheus/api/v1/import/prometheus"}
INTERVAL=${INTERVAL:-15}

echo 
echo "Current ENVs(you can use export to change them): "
echo 
echo "  export PORT_PATTERN=${PORT_PATTERN}"
echo "  export METRICS_SERVER_API=${METRICS_SERVER_API}"
echo "  export INTERVAL=${INTERVAL}"
echo 
echo "Start to collect TCP Status Stat metrics, interval: ${INTERVAL}s"

while true; do 

netstat -ntp | grep tcp \
 | awk '$4~/:'${PORT_PATTERN:-80}'$/ {a[$6]++}; END { for(b in a) printf "container_tcp_state_count{host=\"'${HOSTNAME}'\", app=\"'${APP_NAME}'\", job="tcp-status-stat", direction=\"inbound\", state=\"%s\"} %s\n", b, a[b]}' \
 | curl --data-binary @- $METRICS_SERVER_API

netstat -ntp | grep tcp \
 | awk '$4!~/:'${PORT_PATTERN:-80}'$/ {a[$6]++}; END { for(b in a) printf "container_tcp_state_count{host=\"'${HOSTNAME}'\", app=\"'${APP_NAME}'\", job="tcp-status-stat", direction=\"outbound\", state=\"%s\"} %s\n", b, a[b]}' \
 | curl --data-binary @- $METRICS_SERVER_API

echo 
echo "Metrics sent, sleep ${INTERVAL}s for next collection."
sleep ${INTERVAL}

done

## outputs
# container_tcp_state_count{direction="inbound", state="ESTABLISHED"} 8
# container_tcp_state_count{direction="inbound", state="TIME_WAIT"} 8
# container_tcp_state_count{direction="outbound", state="ESTABLISHED"} 15
# container_tcp_state_count{direction="outbound", state="TIME_WAIT"} 37

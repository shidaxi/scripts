#!/usr/bin/env sh

## need export two environment vars
export PORT_PATTERN=${PORT_PATTERN:-"(8080|8090)"}
export METRICS_SERVER_API=${METRICS_SERVER_API:-"http://vminsert-host/insert/0/prometheus/api/v1/import/prometheus"}

netstat -ntp | grep tcp \
 | awk '$4~/:'${PORT_PATTERN:-80}'$/ {a[$6]++}; END { for(b in a) printf "container_tcp_state_count{direction=\"inbound\", state=\"%s\"} %s\n", b, a[b]}' \
 | curl --data-binary @- $METRICS_SERVER_API

netstat -ntp | grep tcp \
 | awk '$4!~/:'${PORT_PATTERN:-80}'$/ {a[$6]++}; END { for(b in a) printf "container_tcp_state_count{direction=\"outbound\", state=\"%s\"} %s\n", b, a[b]}' \
 | curl --data-binary @- $METRICS_SERVER_API

## outputs
# container_tcp_state_count{direction="inbound", state="ESTABLISHED"} 8
# container_tcp_state_count{direction="inbound", state="TIME_WAIT"} 8
# container_tcp_state_count{direction="outbound", state="ESTABLISHED"} 15
# container_tcp_state_count{direction="outbound", state="TIME_WAIT"} 37

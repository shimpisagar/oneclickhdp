#!/bin/bash

USER=admin
PASSWORD=admin
AMBARI_HOST=ip-10-0-1-141.ec2.internal
CLUSTER=hdptest

#stop all services
curl -u $USER:$PASSWORD -i -H 'X-Requested-By: ambari' -X PUT \
   -d '{"RequestInfo":{"context":"_PARSE_.STOP.ALL_SERVICES","operation_level":{"level":"CLUSTER","cluster_name":"$ClusterName"}},"Body":{"ServiceInfo":{"state":"INSTALLED"}}}' \
   http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER/services

#sleep 60

#start all services
curl -u $USER:$PASSWORD -i -H 'X-Requested-By: ambari' -X PUT \
   -d '{"RequestInfo":{"context":"_PARSE_.START.ALL_SERVICES","operation_level":{"level":"CLUSTER","cluster_name":"$ClusterName"}},"Body":{"ServiceInfo":{"state":"STARTED"}}}' \
   http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER/services

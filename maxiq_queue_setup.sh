#!/bin/bash


#Usage function

if [ $# -ne 4 ]
then
        echo "Usage: ./maxiq_queue_setup.sh <ambari_login_user> <ambari_login_password> <ambari_server_hostname> <CLUSTER_NAME>"
        exit 1;
fi


ambari_user=$1
ambari_password=$2
ambari_server_host=$3
CLUSTER_NAME=$4
date=`date +%s`


 curl -u $ambari_user:$ambari_password -H 'X-Requested-By:admin' -X PUT "http://$ambari_server_host:8080/api/v1/clusters/$CLUSTER_NAME" -d '{
  "Clusters": {
    "desired_config": {
      "type": "capacity-scheduler",
      "tag": "version'$date'",
      "properties": {
            "yarn.scheduler.capacity.maximum-am-resource-percent" : "0.2",
            "yarn.scheduler.capacity.maximum-applications" : "10000",
            "yarn.scheduler.capacity.node-locality-delay" : "40",
            "yarn.scheduler.capacity.queue-mappings-override.enable" : "false",
            "yarn.scheduler.capacity.resource-calculator" : "org.apache.hadoop.yarn.util.resource.DefaultResourceCalculator",
            "yarn.scheduler.capacity.root.MaxiqQueue.acl_administer_queue" : "*",
            "yarn.scheduler.capacity.root.MaxiqQueue.acl_submit_applications" : "*",
            "yarn.scheduler.capacity.root.MaxiqQueue.capacity" : "90",
            "yarn.scheduler.capacity.root.MaxiqQueue.maximum-capacity" : "90",
            "yarn.scheduler.capacity.root.MaxiqQueue.minimum-user-limit-percent" : "100",
            "yarn.scheduler.capacity.root.MaxiqQueue.ordering-policy" : "fifo",
            "yarn.scheduler.capacity.root.MaxiqQueue.state" : "RUNNING",
            "yarn.scheduler.capacity.root.MaxiqQueue.user-limit-factor" : "1",
            "yarn.scheduler.capacity.root.accessible-node-labels" : "*",
            "yarn.scheduler.capacity.root.acl_administer_queue" : "yarn",
            "yarn.scheduler.capacity.root.capacity" : "100",
            "yarn.scheduler.capacity.root.default.acl_administer_queue" : "yarn",
            "yarn.scheduler.capacity.root.default.acl_submit_applications" : "yarn",
            "yarn.scheduler.capacity.root.default.capacity" : "10",
            "yarn.scheduler.capacity.root.default.maximum-capacity" : "100",
            "yarn.scheduler.capacity.root.default.state" : "RUNNING",
            "yarn.scheduler.capacity.root.default.user-limit-factor" : "1",
            "yarn.scheduler.capacity.root.queues" : "MaxiqQueue,default"
      }
    }
  }
}'

stop_start_knox(){
echo -e "\033[32m`timestamp` \033[32mRestarting YARN Service in Progress. Please check service status from Ambari UI. \033[0m"
curl --user $ambari_user:$ambari_password -i -X PUT -d '{"RequestInfo": {"context": "Stop YARN"}, "ServiceInfo": {"state": "INSTALLED"}}' http://$ambari_server_host:8080/api/v1/clusters/$CLUSTER_NAME/services/YARN
sleep 60
curl --user $ambari_user:$ambari_password -i -X PUT -d '{"RequestInfo": {"context": "Start YARN"}, "ServiceInfo": {"state": "STARTED"}}' http://$ambari_server_host:8080/api/v1/clusters/$CLUSTER_NAME/services/YARN
}

stop_start_knox


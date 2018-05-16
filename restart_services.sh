#!/bin/bash
#Author - Sagar Shimpi
#############
LOC=`pwd`
#PROP=ambari.props
CLUSTER_PROPERTIES=$1
source $LOC/$CLUSTER_PROPERTIES 2>/dev/null
AMBARI_ADMIN_USER=admin
AMBARI_ADMIN_PASSWORD=admin
AMBARI_SERVER=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|head -1|cut -d'=' -f2`.$DOMAIN_NAME
#############
start_stale_services()
{
echo "curl -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD http://$AMBARI_SERVER:8080/api/v1/clusters/$CLUSTERNAME/host_components?HostRoles/stale_configs=true&fields=HostRoles/service_name,HostRoles/host_name&minimal_response=false"> /tmp/curl_ambari.sh
sh /tmp/curl_ambari.sh 1 > /tmp/stale_services_json 2>/dev/null
sleep 1
grep host_components /tmp/stale_services_json|grep -v stale|rev|cut -d'"' -f2|rev > /tmp/list_of_components
for URL in `cat /tmp/list_of_components`
do
curl -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -H 'X-Requested-By: ambari' -X PUT -d '{"HostRoles": {"state": "INSTALLED"}}' "$URL"
sleep 0.5
curl -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -H 'X-Requested-By: ambari' -X PUT -d '{"HostRoles": {"state": "STARTED"}}' "$URL"
done
}
start_stale_services

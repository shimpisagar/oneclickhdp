#!/bin/bash


#Usage function

if [ $# -ne 5 ]
then
        echo "Usage: ./knox_ldap_setup.sh <ambari_login_user> <ambari_login_password> <ambari_server_hostname> <CLUSTER_NAME> <OPENLDAP_SERVER_IP>"
        exit 1;
fi

LOC=`pwd`
ambari_user=$1
ambari_password=$2
ambari_server_host=$3
CLUSTER_NAME=$4
OPENLDAP_SERVER_HOSTNAME=$5
date=`date +%s`


 curl -u admin:admin -H 'X-Requested-By:admin' -X PUT 'http://$ambari_server_host:8080/api/v1/clusters/hdptest' -d '{
  "Clusters": {
    "desired_config": {
      "type": "topology",
      "tag": "version'$date'",
      "properties": {
        "content" : " <topology>\n\n            <gateway>\n\n                <provider>\n                    <role>authentication</role>\n                    <name>ShiroProvider</name>\n                    <enabled>true</enabled>\n                    <param>\n                        <name>sessionTimeout</name>\n                        <value>30</value>\n                    </param>\n                    <param>\n                        <name>main.ldapRealm</name>\n                        <value>org.apache.shiro.realm.ldap.JndiLdapRealm</value>\n                    </param>\n                    <param>\n                        <name>main.ldapRealm.userDnTemplate</name>\n                        <value>uid={0},ou=People,dc=lti,dc=com</value>\n                    </param>\n                    <param>\n                        <name>main.ldapRealm.contextFactory.url</name>\n                        <value>ldap://'$OPENLDAP_SERVER_HOSTNAME':389</value>\n                    </param>\n                    <param>\n                        <name>main.ldapRealm.contextFactory.authenticationMechanism</name>\n                        <value>simple</value>\n                    </param>\n                    <param>\n                        <name>urls./**</name>\n                        <value>authcBasic</value>\n                    </param>\n                </provider>\n\n                <provider>\n                    <role>identity-assertion</role>\n                    <name>Default</name>\n                    <enabled>true</enabled>\n                </provider>\n\n                <provider>\n                    <role>authorization</role>\n                    <name>AclsAuthz</name>\n                    <enabled>true</enabled>\n                </provider>\n\n            </gateway>\n\n            <service>\n                <role>NAMENODE</role>\n                <url>hdfs://{{namenode_host}}:{{namenode_rpc_port}}</url>\n            </service>\n\n            <service>\n                <role>JOBTRACKER</role>\n                <url>rpc://{{rm_host}}:{{jt_rpc_port}}</url>\n            </service>\n\n            <service>\n                <role>WEBHDFS</role>\n                {{webhdfs_service_urls}}\n            </service>\n\n            <service>\n                <role>WEBHCAT</role>\n                <url>http://{{webhcat_server_host}}:{{templeton_port}}/templeton</url>\n            </service>\n\n            <service>\n                <role>OOZIE</role>\n                <url>http://{{oozie_server_host}}:{{oozie_server_port}}/oozie</url>\n            </service>\n\n            <service>\n                <role>WEBHBASE</role>\n                <url>http://{{hbase_master_host}}:{{hbase_master_port}}</url>\n            </service>\n\n            <service>\n                <role>HIVE</role>\n                <url>http://{{hive_server_host}}:{{hive_http_port}}/{{hive_http_path}}</url>\n            </service>\n\n            <service>\n                <role>RESOURCEMANAGER</role>\n                <url>http://{{rm_host}}:{{rm_port}}/ws</url>\n            </service>\n        </topology>"
      }
    }
  }
}'


/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080 set $ambari_server_host hdptest "core-site" "hadoop.proxyuser.knox.hosts" "*"
/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080 set $ambari_server_host hdptest "core-site" "hadoop.proxyuser.yarn.groups" "*"
/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080 set $ambari_server_host hdptest "core-site" "hadoop.proxyuser.yarn.hosts" "*"
/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080 set $ambari_server_host hdptest "core-site" "hadoop.proxyuser.hdfs.hosts" "*"
/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080 set $ambari_server_host hdptest "core-site" "hadoop.proxyuser.hdfs.groups" "*"
/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080 set $ambari_server_host hdptest "core-site" "hadoop.proxyuser.HTTP.groups" "*"

stop_start_knox(){
echo -e "\033[32m`timestamp` \033[32mRestarting Knox Service in Progress. Please check service status from Ambari UI. \033[0m"
curl --user $ambari_user:$ambari_password -i -X PUT -d '{"RequestInfo": {"context": "Stop KNOX"}, "ServiceInfo": {"state": "INSTALLED"}}' http://$ambari_server_host:8080/api/v1/clusters/$CLUSTER_NAME/services/KNOX
sleep 60
curl --user $ambari_user:$ambari_password -i -X PUT -d '{"RequestInfo": {"context": "Stop HDFS"}, "ServiceInfo": {"state": "INSTALLED"}}' http://$ambari_server_host:8080/api/v1/clusters/$CLUSTER_NAME/services/HDFS
sleep 60
curl --user $ambari_user:$ambari_password -i -X PUT -d '{"RequestInfo": {"context": "Start KNOX"}, "ServiceInfo": {"state": "STARTED"}}' http://$ambari_server_host:8080/api/v1/clusters/$CLUSTER_NAME/services/KNOX
sleep 60
curl --user $ambari_user:$ambari_password -i -X PUT -d '{"RequestInfo": {"context": "Start HDFS"}, "ServiceInfo": {"state": "STARTED"}}' http://$ambari_server_host:8080/api/v1/clusters/$CLUSTER_NAME/services/HDFS

mv $LOC/doSet_version* /tmp &>/dev/null
}

stop_start_knox


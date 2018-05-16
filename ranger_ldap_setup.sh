#!/bin/bash

#Usage function

if [ $# -ne 6 ]
then
	echo "Usage: ./ranger_ldap_setup.sh <ambari_login_user> <ambari_login_password> <ambari_server_hostname> <CLUSTER_NAME> <OPENLDAP_SERVER_IP> <LDAP_PASSWORD>"
	exit 1;
fi

LOC=`pwd`

timestamp()
{
        echo "`date +%Y-%m-%d,%H:%M:%S`"
}

ambari_user=$1
ambari_password=$2
ambari_server_host=$3
CLUSTER_NAME=$4
OPENLDAP_SERVER_HOSTNAME=$5
LDAP_PASSWORD=$6


/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site  "ranger.usersync.source.impl.class" "org.apache.ranger.ldapusersync.process.LdapUserGroupBuilder"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.ldap.url" "ldap://$OPENLDAP_SERVER_HOSTNAME:389"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.ldap.binddn" "cn=Manager,dc=lti,dc=com"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.ldap.user.nameattribute" "uid"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.ldap.user.searchbase" "dc=lti,dc=com"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.user.searchenabled" "true"


/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.group.searchenabled" "true"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.group.memberattributename" "memberUid"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.ldap.user.groupnameattribute" "memberof, ismemberof"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.group.nameattribute" "cn"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.group.objectclass" "posixGroup"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.group.searchbase" "dc=lti,dc=com"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.group.searchfilter" "cn=*"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.group.search.first.enabled" "true"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-admin-site "ranger.authentication.method" "LDAP"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-admin-site "ranger.ldap.base.dn" "dc=lti,dc=com"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-admin-site "ranger.ldap.group.roleattribute" "uid"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-admin-site "ranger.ldap.user.dnpattern" "uid={0},ou=People,dc=lti,dc=com"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.group.searchscope" "sub"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.ldap.bindalias" "ranger.usersync.ldap.bindalias"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.ldap.searchBase" "dc=lti,dc=com"

/var/lib/ambari-server/resources/scripts/configs.sh -u $ambari_user -p $ambari_password -port 8080  set $ambari_server_host $CLUSTER_NAME ranger-ugsync-site "ranger.usersync.ldap.ldapbindpassword" "$LDAP_PASSWORD"

stop_start_ranger(){
echo -e "\033[32m`timestamp` \033[32mRestarting Knox Service in Progress... \033[0m"
curl --user $ambari_user:$ambari_password -i -X PUT -d '{"RequestInfo": {"context": "Stop RANGER"}, "ServiceInfo": {"state": "INSTALLED"}}' http://$ambari_server_host:8080/api/v1/clusters/$CLUSTER_NAME/services/RANGER
sleep 60
curl --user $ambari_user:$ambari_password -i -X PUT -d '{"RequestInfo": {"context": "Start RANGER"}, "ServiceInfo": {"state": "STARTED"}}' http://$ambari_server_host:8080/api/v1/clusters/$CLUSTER_NAME/services/RANGER
echo -e "\033[32m`timestamp` \033[32mPlease check service status from Ambari UI... \033[0m"
mv $LOC/doSet_version* /tmp &>/dev/null
}

stop_start_ranger

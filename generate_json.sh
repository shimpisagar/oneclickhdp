#!/bin/bash
########
# Author: Sagar Shimpi
# Description: This script does the Magic of automating HDP install using Ambari Blueprints


#Cleanup script
mv $LOC/cluster_config.json /tmp &>/dev/null
mv $LOC/hostmap.json /tmp &>/dev/null
mv $LOC/repo* /tmp &>/dev/null
mv $LOC/list /tmp &>/dev/null

#Globals
LOC=`pwd`
PROPS=$1
#Source props
source $LOC/$PROPS 2>/dev/null
STACK_VERSION=`echo $CLUSTER_VERSION|cut -c1-3`
AMBARI_HOST=$2
NUMBER_OF_HOSTS=`grep HOST $LOC/$PROPS|grep -v SERVICES|wc -l`
LAST_HOST=`grep HOST $LOC/$PROPS|grep -v SERVICES|head -n $NUMBER_OF_HOSTS|tail -1|cut -d'=' -f2`
grep HOST $LOC/$PROPS|grep -v SERVICES|grep -v $LAST_HOST|cut -d'=' -f2 > $LOC/list
OS_VERSION=`echo $OS|rev|cut -c1|rev`

#Generate hostmap function#

hostmap()
{
#Start of function

echo "{
  \"blueprint\" : \"$CLUSTERNAME\","
  
if [ "${AMBARIVERSION:0:3}" > "2.6" ]] || [[ "${AMBARIVERSION:0:3}" == "2.6" ]]
	then
		echo "\"repository_version_id\" : \"1\","
fi
  \"default_password\" : \"$DEFAULT_PASSWORD\",
  \"host_groups\" :["

for HOST in `cat list`
do
   echo "{
      \"name\" : \"$HOST\",
      \"hosts\" : [
        {
          \"fqdn\" : \"$HOST.$DOMAIN_NAME\"
        }
      ]
    },"
done

echo "{
      \"name\" : \"$LAST_HOST\",
      \"hosts\" : [
        {
          \"fqdn\" : \"$LAST_HOST.$DOMAIN_NAME\"
        }
      ]
    }
  ]
}"

#End of function
}

clustermap()
{
#Start of function
LAST_HST_NAME=`grep 'HOST[0-9]*' $LOC/$PROPS|grep -v SERVICES|tail -1|cut -d'=' -f1`

echo "{
  \"configurations\" : [ 
],
  \"host_groups\" : ["

for HOST in `grep -w 'HOST[0-9]*' $LOC/$PROPS|tr '\n' ' '`
do
   HST_NAME_VAR=`echo $HOST|cut -d'=' -f1`
   echo "{
      \"name\" : \"`grep $HST_NAME_VAR $PROPS |head -1|cut -d'=' -f2|cut -d'.' -f1`\",
      \"components\" : ["
		LAST_SVC=`grep $HST_NAME_VAR"_SERVICES" $LOC/$PROPS|cut -d'=' -f2|tr ',' ' '|rev|cut -d' ' -f1|rev|cut -d'"' -f1`
		for SVC in `grep $HST_NAME_VAR"_SERVICES" $LOC/$PROPS|cut -d'=' -f2|tr ',' ' '|cut -d'"' -f2|cut -d'"' -f1`
		do
        		echo "{
			\"name\" : \"$SVC\""
			if [ "$SVC" == "$LAST_SVC" ]
			then
				echo "}
				],
      			        \"cardinality\" : "1""
				if [ "$HST_NAME_VAR" == "$LAST_HST_NAME" ]
				then
    	               		    	echo "}"
				else
					echo "},"
				fi
			else
       	 				echo "},"
			fi
		done
done

echo "  ],
  \"Blueprints\" : {
    \"blueprint_name\" : \"$CLUSTERNAME\",
    \"stack_name\" : \"HDP\",
    \"stack_version\" : \"$STACK_VERSION\"
  }
}"


#End of function
}

#Setting up Repositories

repobuilder()
{
#Start of function
BASE_URL="http://$REPO_SERVER/repo/hadoop/hortonworks/hdp/$OS/HDP-$CLUSTER_VERSION/"


echo "{
\"Repositories\" : {
   \"base_url\" : \"$BASE_URL\",
   \"verify_base_url\" : true
}
}" > $LOC/repo.json

BASE_URL_UTILS="http://$REPO_SERVER/repo/hadoop/hortonworks/hdp/$OS/HDP-UTILS-$UTILS_VERSION/"

export BASE_URL_UTILS;

echo "{
\"Repositories\" : {
   \"base_url\" : \"$BASE_URL_UTILS\",
   \"verify_base_url\" : true
}
}" > $LOC/repo-utils.json

#End of function
}

#Function to print timestamp
timestamp()
{
echo -e  "\033[36m`date +%Y-%m-%d-%H:%M:%S`\033[0m"
}

ranger_config(){
#!/bin/bash

sed -i '/"configurations"/a {\
      "admin-properties" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "DB_FLAVOR" : "MYSQL",\
          "audit_db_name" : "ranger_audit",\
          "db_name" : "ranger",\
          "audit_db_user" : "rangerlogger",\
          "SQL_CONNECTOR_JAR" : "/usr/share/java/mysql-connector-java.jar",\
          "db_user" : "rangeradmin",\
          "policymgr_external_url" : "http://'$RANGER_ADMIN_SERVER':6080",\
          "db_host" : "'$DB_SERVER':3306",\
          "db_root_user" : "root",\
          "db_root_password" : "'$DB_ROOT_PASSWORD'"\
        }\
      }\
    },\
    {\
      "ranger-kms-security" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "ranger.plugin.kms.policy.source.impl" : "org.apache.ranger.admin.client.RangerAdminRESTClient",\
          "ranger.plugin.kms.service.name" : "{{repo_name}}",\
          "ranger.plugin.kms.policy.rest.url" : "{{policymgr_mgr_url}}"\
        }\
      }\
    },\
    {\
      "kms-site" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "hadoop.kms.security.authorization.manager" : "org.apache.ranger.authorization.kms.authorizer.RangerKmsAuthorizer",\
          "hadoop.kms.key.provider.uri" : "dbks://http@localhost:9292/kms"\
        }\
      }\
    },\
    {\
      "ranger-hdfs-plugin-properties" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "REPOSITORY_CONFIG_USERNAME" : "hadoop",\
          "ranger-hdfs-plugin-enabled" : "Yes",\
          "common.name.for.certificate" : "",\
          "policy_user" : "ambari-qa",\
          "hadoop.rpc.protection" : ""\
        }\
      }\
    },\
    {\
      "ranger-admin-site" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "ranger.ldap.group.searchfilter" : "{{ranger_ug_ldap_group_searchfilter}}",\
          "ranger.ldap.group.searchbase" : "{{ranger_ug_ldap_group_searchbase}}",\
          "ranger.sso.enabled" : "false",\
          "ranger.externalurl" : "{{ranger_external_url}}",\
          "ranger.sso.browser.useragent" : "Mozilla,chrome",\
          "ranger.service.https.attrib.ssl.enabled" : "false",\
          "ranger.ldap.ad.referral" : "ignore",\
          "ranger.jpa.jdbc.url" : "jdbc:mysql://'$DB_SERVER':3306/ranger",\
          "ranger.https.attrib.keystore.file" : "/etc/ranger/admin/conf/ranger-admin-keystore.jks",\
          "ranger.ldap.user.searchfilter" : "{{ranger_ug_ldap_user_searchfilter}}",\
          "ranger.jpa.jdbc.driver" : "com.mysql.jdbc.Driver",\
          "ranger.authentication.method" : "UNIX",\
          "ranger.service.host" : "{{ranger_host}}",\
          "ranger.jpa.audit.jdbc.user" : "{{ranger_audit_db_user}}",\
          "ranger.ldap.referral" : "ignore",\
          "ranger.jpa.audit.jdbc.credential.alias" : "rangeraudit",\
          "ranger.service.https.attrib.keystore.pass" : "redhat",\
          "ranger.audit.solr.username" : "ranger_solr",\
          "ranger.sso.query.param.originalurl" : "originalUrl",\
          "ranger.service.http.enabled" : "true",\
          "ranger.audit.source.type" : "solr",\
          "ranger.ldap.url" : "{{ranger_ug_ldap_url}}",\
          "ranger.service.https.attrib.clientAuth" : "want",\
          "ranger.ldap.ad.domain" : "",\
          "ranger.ldap.ad.bind.dn" : "{{ranger_ug_ldap_bind_dn}}",\
          "ranger.credential.provider.path" : "/etc/ranger/admin/rangeradmin.jceks",\
          "ranger.jpa.audit.jdbc.driver" : "{{ranger_jdbc_driver}}",\
          "ranger.audit.solr.urls" : "",\
          "ranger.sso.publicKey" : "",\
          "ranger.ldap.bind.dn" : "{{ranger_ug_ldap_bind_dn}}",\
          "ranger.unixauth.service.port" : "5151",\
          "ranger.ldap.group.roleattribute" : "cn",\
          "ranger.jpa.jdbc.dialect" : "{{jdbc_dialect}}",\
          "ranger.sso.cookiename" : "hadoop-jwt",\
          "ranger.service.https.attrib.keystore.keyalias" : "rangeradmin",\
          "ranger.audit.solr.zookeepers" : "NONE",\
          "ranger.jpa.jdbc.user" : "{{ranger_db_user}}",\
          "ranger.jpa.jdbc.credential.alias" : "rangeradmin",\
          "ranger.ldap.ad.user.searchfilter" : "{{ranger_ug_ldap_user_searchfilter}}",\
          "ranger.ldap.user.dnpattern" : "uid={0},ou=users,dc=xasecure,dc=net",\
          "ranger.ldap.base.dn" : "dc=example,dc=com",\
          "ranger.service.http.port" : "6080",\
          "ranger.jpa.audit.jdbc.url" : "{{audit_jdbc_url}}",\
          "ranger.service.https.port" : "6182",\
          "ranger.sso.providerurl" : "",\
          "ranger.ldap.ad.url" : "{{ranger_ug_ldap_url}}",\
          "ranger.jpa.audit.jdbc.dialect" : "{{jdbc_dialect}}",\
          "ranger.unixauth.remote.login.enabled" : "true",\
          "ranger.ldap.ad.base.dn" : "dc=example,dc=com",\
          "ranger.unixauth.service.hostname" : "{{ugsync_host}}"\
        }\
      }\
    },\
    {\
      "dbks-site" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "ranger.ks.jpa.jdbc.url" : "jdbc:mysql://'$DB_SERVER':3306/rangerkms",\
          "hadoop.kms.blacklist.DECRYPT_EEK" : "hdfs",\
          "ranger.ks.jpa.jdbc.dialect" : "{{jdbc_dialect}}",\
          "ranger.ks.jdbc.sqlconnectorjar" : "{{ews_lib_jar_path}}",\
          "ranger.ks.jpa.jdbc.user" : "{{db_user}}",\
          "ranger.ks.jpa.jdbc.credential.alias" : "ranger.ks.jdbc.password",\
          "ranger.ks.jpa.jdbc.credential.provider.path" : "/etc/ranger/kms/rangerkms.jceks",\
          "ranger.ks.masterkey.credential.alias" : "ranger.ks.masterkey.password",\
          "ranger.ks.jpa.jdbc.driver" : "com.mysql.jdbc.Driver"\
        }\
      }\
    },\
    {\
      "kms-env" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "kms_log_dir" : "/var/log/ranger/kms",\
          "create_db_user" : "true",\
          "kms_group" : "kms",\
          "kms_user" : "kms",\
          "kms_port" : "9292"\
        }\
      }\
    },\
    {\
      "ranger-hdfs-security" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "ranger.plugin.hdfs.policy.source.impl" : "org.apache.ranger.admin.client.RangerAdminRESTClient",\
          "ranger.plugin.hdfs.policy.rest.url" : "http://'$RANGER_ADMIN_SERVER':6080"\
        }\
      }\
    },\
\
    {\
      "ranger-env" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "xml_configurations_supported" : "true",\
          "ranger_user" : "ranger",\
          "xasecure.audit.destination.hdfs.dir" : "hdfs://'$NN_SERVER':8020/ranger/audit",\
          "create_db_dbuser" : "true",\
          "ranger-hdfs-plugin-enabled" : "Yes",\
          "ranger_privelege_user_jdbc_url" : "jdbc:mysql://'$DB_SERVER':3306",\
          "ranger-knox-plugin-enabled" : "No",\
          "is_solrCloud_enabled" : "false",\
          "bind_anonymous" : "false",\
          "ranger-yarn-plugin-enabled" : "Yes",\
          "ranger-kafka-plugin-enabled" : "No",\
          "xasecure.audit.destination.hdfs" : "true",\
          "ranger-hive-plugin-enabled" : "No",\
          "xasecure.audit.destination.solr" : "false",\
          "xasecure.audit.destination.db" : "true",\
          "ranger_group" : "ranger",\
          "ranger_admin_username" : "amb_ranger_admin",\
          "ranger_admin_password" : "ambrangeradmin",\
          "ranger-hbase-plugin-enabled" : "No",\
          "admin_username" : "admin"\
        }\
      }\
    },\
\
    {\
      "kms-properties" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "REPOSITORY_CONFIG_USERNAME" : "keyadmin",\
          "KMS_MASTER_KEY_PASSWD" : "redhat",\
          "DB_FLAVOR" : "MYSQL",\
          "db_name" : "rangerkms",\
          "SQL_CONNECTOR_JAR" : "/usr/share/java/mysql-connector-java.jar",\
          "db_user" : "rangerkms",\
          "db_password" : "rangerkms",\
          "db_host" : "'$DB_SERVER':3306",\
          "db_root_user" : "root",\
          "db_root_password" : "redhat"\
        }\
      }\
    },\
\
    {\
      "ranger-yarn-security" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "ranger.plugin.yarn.policy.source.impl" : "org.apache.ranger.admin.client.RangerAdminRESTClient",\
          "ranger.plugin.yarn.policy.rest.url" : "http://'$RANGER_ADMIN_SERVER':6080"\
        }\
      }\
    },\
\
    {\
      "usersync-properties" : {\
        "properties_attributes" : { },\
        "properties" : { }\
      }\
    },\
\
    {\
      "ranger-hbase-security" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "ranger.plugin.hbase.policy.source.impl" : "org.apache.ranger.admin.client.RangerAdminRESTClient"\
        }\
      }\
    },\
    {\
      "hdfs-site" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "dfs.encryption.key.provider.uri" : "kms://http@'$RANGER_ADMIN_SERVER':9292/kms",\
          "dfs.namenode.inode.attributes.provider.class" : "org.apache.ranger.authorization.hadoop.RangerHdfsAuthorizer"\
        }\
      }\
    },\
    {\
      "ranger-yarn-plugin-properties" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "REPOSITORY_CONFIG_USERNAME" : "yarn",\
          "common.name.for.certificate" : "",\
          "ranger-yarn-plugin-enabled" : "Yes",\
          "policy_user" : "ambari-qa",\
          "hadoop.rpc.protection" : ""\
        }\
      }\
    },\
    {\
      "ranger-hbase-plugin-properties" : {\
        "properties_attributes" : { },\
        "properties" : {\
          "REPOSITORY_CONFIG_USERNAME" : "hbase",\
          "common.name.for.certificate" : "",\
          "ranger-hbase-plugin-enabled" : "No",\
          "policy_user" : "ambari-qa"\
        }\
      }\
    }' $LOC/cluster_config.json
}



installhdp()
{
#Install hdp using Ambari Blueprints
echo -e "\033[32m`timestamp` \033[32mInstalling HDP Using Blueprints\033[0m"

HDP_UTILS_VERSION=`echo $BASE_URL_UTILS| awk -F'/' '{print $7}'`

curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://$AMBARI_HOST:8080/api/v1/blueprints/$CLUSTERNAME -d @"$LOC"/cluster_config.json 2&>1 /tmp/curl_cc_json.txt
sleep 1
curl -H "X-Requested-By: ambari" -X PUT -u admin:admin http://$AMBARI_HOST:8080/api/v1/stacks/HDP/versions/$STACK_VERSION/operating_systems/redhat"$OS_VERSION"/repositories/HDP-$STACK_VERSION -d @$LOC/repo.json 2&>1 /tmp/repo_json.txt
sleep 1
curl -H "X-Requested-By: ambari" -X PUT -u admin:admin http://$AMBARI_HOST:8080/api/v1/stacks/HDP/versions/$STACK_VERSION/operating_systems/redhat"$OS_VERSION"/repositories/$HDP_UTILS_VERSION -d @$LOC/repo-utils.json 2&>1 /tmp/repo_utils_json.txt
sleep 1
curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTERNAME -d @$LOC/hostmap.json &> /tmp/hostmap_json.txt

}

######### Register VDF ##########
register_vdf()
{
curl -H "X-Requested-By:ambari" -X POST -u admin:admin http://$AMBARI_HOST:8080/api/v1/version_definitions -d '{ "VersionDefinition": { "version_url": "http://'"$REPO_SERVER"'/hdp/'"$OS_VERSION"'/HDP-'"$CLUSTER_VERSION"'/HDP-'"$CLUSTER_VERSION"'.xml" } }'
}

#################
# Main function #
################

#Register VDF

if [[ "${AMBARIVERSION:0:3}" > "2.6" ]] || [[ "${AMBARIVERSION:0:3}" == "2.6" ]]
  then
  # Required to register VDF for the specific build version
  register_vdf
fi


#################
# Main function #
################

#Generate hostmap
echo -e "\033[032m`timestamp` \033[32mGenerating hostmap json..\033[0m"
hostmap > $LOC/hostmap.json
echo -e "\033[032m`timestamp` \033[32mSaved $LOC/hostmap.json\033[0m"

#Generate cluster config json
echo -e "\033[032m`timestamp` \033[32mGenerating cluster configuration json\033[0m"
clustermap > $LOC/cluster_config.json
echo -e "\033[032m`timestamp` \033[32mSaved $LOC/cluster_config.json\033[0m"

#Add ranger settings to cluster config json
install=`grep -w INSTALL_RANGER $LOC/$PROPS  |awk -F "=" '{print $2}'`
if [ "$install" == "yes" ]
then
	echo "ranger is enabled" &>/dev/null
	ranger_config &> /tmp/ranger_config.txt
else
	echo "ranger is disabled" &>/dev/null
fi

#Create internal repo json 
echo -e "\033[032m`timestamp` \033[32mGenerating internal repositories json..\033[0m"
repobuilder 
echo -e "\033[032m`timestamp` \033[32mSaved $LOC/repo.json & $LOC/repo-utils.json\033[0m"



#Start hdp installation
installhdp

#!/bin/bash
#Author - Sagar Shimpi
#Contributor - xxxxxxxx
#Script will setup and configure ambari-server/ambari-agents and hdp cluster
##########################################################


#+++++++++++++++++++++++
# Usage Function
if [ $# -ne 1 ]
then
        printf "Usage $0 /path-to/cluster.props\nExample: $0 /opt/single_multinode_autodeploy/<cluster props File> \n"
        exit
fi
#+++++++++++++++++++++++

#Function to print timestamp
timestamp()
{
echo -e  "\033[36m`date +%Y-%m-%d-%H:%M:%S`\033[0m"
}


#Globals VARS

LOC=`pwd`
CLUSTER_PROPERTIES=$1
sed -i  's/[ \t]*$//'  $LOC/$CLUSTER_PROPERTIES
source $LOC/$CLUSTER_PROPERTIES 2>/dev/null
mosaic_path="mosaic"
CLUSTERNAME=`grep -w CLUSTERNAME $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
AMBARI_ADMIN_USER=admin
AMBARI_ADMIN_PASSWORD=admin
AMBARI_SERVER=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|head -1|cut -d'=' -f2`.$DOMAIN_NAME
AMBARI_AGENTS=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
USER=`grep -w SSH_USER $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
PASSWORD=`grep -w SSH_SERVER_PASSWORD $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
PVT_KEY=`grep -w SSH_SERVER_PRIVATE_KEY $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
IP=`grep -w IP[1-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2|head -n 1`
REPO_SERVER=`grep -w "REPO_SERVER" $LOC/$CLUSTER_PROPERTIES| sed /^#.*/d |awk -F"=" '{print $2}'`
JAVA_VERSION=`grep  -w JAVA  $LOC/$CLUSTER_PROPERTIES |cut -d'=' -f2`
JAVA_HOME=`grep  -w JAVA_HOME  $LOC/$CLUSTER_PROPERTIES |cut -d'=' -f2`
JAVA_JCE_PATH=`echo $JAVA_HOME/jre/lib/security/`
AS=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|head -1|cut -d'=' -f2`
AMBARI_SERVER_IP=`awk "/$AS/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
NUM_OF_HOSTS=`cat $LOC/$CLUSTER_PROPERTIES|grep -w HOST[1-50] |wc -l`
DB_ROOT_PASS=`cat $LOC/$CLUSTER_PROPERTIES| grep DB_ROOT_PASSWORD |awk -F "=" '{print $2}'`
RANGER_STATUS=`cat $LOC/$CLUSTER_PROPERTIES|grep INSTALL_RANGER | awk -F "=" '{print $2}'`
wget='wget --user $REPO_SERVER_WGET_USER --password $REPO_SERVER_WGET_PASS'


#+++++++++++++++++++++++
# Check NUM_OF_NODES and NUM_OF_HOSTS in proeprties file

if [[ $NUM_OF_NODES -eq $NUM_OF_HOSTS ]]
then
        echo "Both values are Equal" > /dev/null
else
        echo -e '\033[41mWARNING!!!!\033[0m \033[36m"NUM_OF_HOSTS" and "NUM_OF_NODES" defined in  $LOC/$CLUSTER_PROPERTIES are not equal. Please remove unwanted entries from file or correct "NUM_OF_NODES" value..\033[0m'
	exit 1;
fi

#+++++++++++++++++++++++


if [ -z $PVT_KEY ]
then
	echo -e "\033[32m`timestamp` \033[32mUsing Plain Password For Cluster Setup\033[0m"
	ssh_cmd="sshpass -p $PASSWORD ssh"
	scp_cmd="sshpass -p $PASSWORD scp"
else
	echo -e "\033[32m`timestamp` \033[32mUsing Private Key For Cluster Setup\033[0m"
	ssh_cmd="ssh -i $PVT_KEY"
	scp_cmd="scp -i $PVT_KEY"
	if [ -e $PVT_KEY ]
	then
		echo "File Exist" &> /dev/null
	else
		echo -e "\033[35mPrivate key is missing.. Please check!!!\033[0m"
		exit 1;
	fi
fi

prepare_hosts_file()
{
        echo -e  "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" > /tmp/hosts
for host in `grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
do
        host_ip=`awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
        echo $host_ip $host.$DOMAIN_NAME >> /tmp/hosts
	if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
	then
		sudo sed -i "/$host/d" /etc/hosts
		sudo bash -c "echo \"$host_ip $host.$DOMAIN_NAME\"  >> /etc/hosts"
	else
		sed -i "/$host/d" /etc/hosts
        	echo $host_ip $host.$DOMAIN_NAME >> /etc/hosts
	fi
done

}


generate_centos_repo()
{
#This will generate internal repo file for Ambari Setup
echo "[Centos7]
name=Centos7 - Updates
baseurl=http://maxiq:"Uns%40vedD0cument1"@$REPO_SERVER/repo/os/$OS/
gpgcheck=0
enabled=1
priority=1" > /tmp/centos7.repo

		if [ "$REPO_SERVER" = "public" ]
		then
			echo "repo is public" &> /dev/null
		else
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
		sudo cp /tmp/centos7.repo /etc/yum.repos.d &>/dev/null
		
	else
		cp /tmp/centos7.repo /etc/yum.repos.d &>/dev/null
	fi
		fi
}


generate_ambari_repo()
{
                if [ "$REPO_SERVER" = "public" ]
                then
			        for host in `echo $AMBARI_AGENTS`
        			do
                			AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
        		        	host_ip=` awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
	
			if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
                	then
                        	echo "repo is public" &> /dev/null
				sudo rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &> /dev/null
				sudo yum install sshpass -y &> /dev/null
				sudo mv /etc/yum.repos.d/ambari*.repo /tmp/ &> /dev/null
	        		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo yum -y install unzip wget 2&>1 /dev/null
				sudo wget -O /tmp/jce_policy-8.zip --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip" &> /tmp/jce_download.txt
				wait
				$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo wget -O /etc/yum.repos.d/ambari.repo http://public-repo-1.hortonworks.com/ambari/$OS/2.x/updates/$AMBARIVERSION/ambari.repo" &> /dev/null
			else
                        	echo "repo is local" &> /dev/null
				rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &> /dev/null
				yum install sshpass -y &> /dev/null
				mv /etc/yum.repos.d/ambari*.repo /tmp/
        			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "yum -y install unzip wget" &> /dev/null
				wget -O /tmp/jce_policy-8.zip --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip" &> /tmp/jce_download.txt
				wait
        			#$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm 2&>1 /dev/null
				 $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "wget -O /etc/yum.repos.d/ambari.repo http://public-repo-1.hortonworks.com/ambari/$OS/2.x/updates/$AMBARIVERSION/ambari.repo" &> /dev/null
			fi
				done
                else
                        #sudo rpm -ivh http://$REPO_SERVER/repo/custom_pkgs/sshpass-1.06-2.el7.x86_64.rpm &> /tmp/sshpass_install.txt
			sudo yum install sshpass jdk unzip wget -y 2&>1 /dev/null
			sudo $wget -O /tmp/jce_policy-8.zip http://$REPO_SERVER/repo/os/centos7/base/Packages/jce_policy-8.zip  &> /tmp/jce_download.txt
                        #This will generate internal repo file for Ambari Setup
echo "[Updates-ambari-$AMBARIVERSION]
name=ambari-$AMBARIVERSION - Updates
baseurl=http://maxiq:"Uns%40vedD0cument1"@$REPO_SERVER/repo/hadoop/hortonworks/ambari/$OS/Updates-ambari-$AMBARIVERSION/
gpgcheck=0
enabled=1
priority=1" > /tmp/ambari-$AMBARIVERSION.repo
		fi
}


localrepo_pre_rep ()
{
        for host in `echo $AMBARI_AGENTS`
        do
                AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
                host_ip=` awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
                if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
                then
        $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo mkdir /etc/yum.repos.d/bkp 2> /dev/null
                        wait
        $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bkp/"  2> /dev/null
                        wait
        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/ambari-"$AMBARIVERSION".repo $USER@$host_ip:/tmp/ambari-"$AMBARIVERSION".repo &> /dev/null
                        wait
        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo cp /tmp/ambari-"$AMBARIVERSION".repo /etc/yum.repos.d/ 2> /dev/null &
                        wait
        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/centos7.repo $USER@$host_ip:/tmp/centos7.repo &> /dev/null
                        wait
        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo cp /tmp/centos7.repo /etc/yum.repos.d/ 2> /dev/null
                        wait
                if [ "$REPO_SERVER" = "public" ]
                then	
			echo "ignoring mysql-community-release downlaod" &> /dev/null
		else
	        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo yum -y install mysql-community-release 2&>1 /dev/null
		fi	
                        wait
                else
        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip mkdir /etc/yum.repos.d/bkp  &> /dev/null
                        wait
        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip  mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bkp/  &> /dev/null
                        wait
        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip rm -rf /etc/yum.repos.d/ambari-*.repo 2> /dev/null  &
                        wait
        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/ambari-"$AMBARIVERSION".repo $USER@$host_ip:/etc/yum.repos.d/ 2> /dev/null &
                        wait
        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/centos7.repo $USER@$host_ip:/etc/yum.repos.d/ &> /dev/null &
                        wait
                if [ "$REPO_SERVER" = "public" ]
                then	
			echo "ignoring mysql-community-release downlaod" &> /dev/null
		else
			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip yum -y install mysql-community-release 2&>1 /dev/null
		fi	
                fi
	done
}

pre_rep()
{
        for host in `echo $AMBARI_AGENTS`
        do
                AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
		host_ip=` awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
			#echo "INSTALLING SSHPASS RPM..................."
			wait
			#$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo yum install sshpass -y 2&>1 /dev/null
			sudo wget -O /etc/yum.repos.d/ambari.repo http://public-repo-1.hortonworks.com/ambari/$OS/2.x/updates/$AMBARIVERSION/ambari.repo &> /dev/null
			#localrepo_pre-rep
                        wait
	        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo yum clean all 2&>1 /dev/null
                        wait
			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo mv /etc/yum.repos.d/mysql*.repo /tmp" &> /dev/null
                        wait
        else
                        #yum install sshpass -y &> /dev/null
			#localrepo_pre-rep
			wget -O /etc/yum.repos.d/ambari.repo http://public-repo-1.hortonworks.com/ambari/$OS/2.x/updates/$AMBARIVERSION/ambari.repo &> /dev/null
                        wait
	        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip yum clean all 2&>1 /dev/null
                        wait
                	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "mv /etc/yum.repos.d/mysql*.repo /tmp" &> /dev/null
                        wait
        fi
        done
}

check_java_install ()
{
	if type -p java &> /dev/null; then
    #echo found java executable in PATH
    _java=java &> /dev/null
elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
    #echo found java executable in JAVA_HOME     
    _java="$JAVA_HOME/bin/java" &> /dev/null
else
    #echo "Please install and set JAVA path.."
	echo -e  "\033[32m`timestamp` \033[31mWarning!!! JAVA PATH is not set\033[0m"
	for host in `echo $AMBARI_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
                if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
                then
			echo -e  "\033[32m`timestamp` \033[32mInstalling JAVA\033[0m"
                        $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$HOST sudo yum install -y java &> /tmp/java_install.txt
                else
			echo -e  "\033[32m`timestamp` \033[32mInstalling JAVA\033[0m"
                        $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$HOST yum install -y java &> /tmp/java_install.txt
                fi

        done
fi

}


install_java()
{
	echo -e "\033[32m`timestamp` \033[32mInstalling JAVA \033[0m"
	for host in `echo $AMBARI_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
		if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        	then
			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$HOST sudo yum install -y jdk &> /tmp/java_install.txt
		else
			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$HOST yum install -y jdk &> /tmp/java_install.txt
		fi
			
	done
}




bootstrap_hosts()
{
        echo -e "\033[32m`timestamp` \033[32mBootstrap Hosts \033[0m"
        for host in `echo $AMBARI_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
		host_ip=` awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
                if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
                then
                	wait
                	$scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/hosts $USER@$host_ip:/tmp/hosts.org &> /dev/null &
                	$scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/jce_policy-8.zip $USER@$host_ip:/tmp/ &> /dev/null &
                	wait
                	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo mv /tmp/hosts.org /etc/hosts 2> /dev/null &
                	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo sed -i.bak "s/$USERNAME-$HOST/$HOST/g" /etc/sysconfig/network  2> /dev/null &
                	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo echo HOSTNAME=$HOST >> /etc/sysconfig/network"  2> /dev/null &

                	printf "sudo hostname "$HOST" 2>/dev/null\nsudo hostnamectl set-hostname "$HOST"\nsudo hostnamectl set-hostname "$HOST" --static\nsudo systemctl restart systemd-hostnamed\nsudo systemctl stop firewalld.service 2>/dev/null\nsudo systemctl disable firewalld.service 2> /dev/null" > /tmp/commands_centos7
                	cat /tmp/commands_centos7|$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip 2>/dev/null			
		else
			wait 
			$scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/hosts $USER@$host_ip:/tmp/hosts.org &> /dev/null &
                	$scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/jce_policy-8.zip $USER@$host_ip:/tmp/ &> /dev/null &
			wait 
                        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo mv /tmp/hosts.org /etc/hosts 2> /dev/null &
                	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sed -i.bak "s/$USERNAME-$HOST/$HOST/g" /etc/sysconfig/network  2> /dev/null & 
			$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "echo HOSTNAME=$HOST >> /etc/sysconfig/network"  2> /dev/null &

                	printf "hostname "$HOST" 2>/dev/null\nhostnamectl set-hostname "$HOST"\nhostnamectl set-hostname "$HOST" --static\nsystemctl restart systemd-hostnamed\nsystemctl stop firewalld.service 2>/dev/null 2> /dev/null\nsystemctl disable firewalld.service 2> /dev/null" > /tmp/commands_centos7
                	cat /tmp/commands_centos7|$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip 2>/dev/null
		fi
        done
}



setup_ambari_server()
{
	echo -e "\033[32m`timestamp` \033[32mInstalling Ambari-Server\033[0m"

#        ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER yum -y install ambari-server
#        ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER ambari-server setup -s
#        ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER ambari-server start
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo yum -y install ambari-server 2&>1 /dev/null
        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo yum -y install ansible perl perl-Carp perl-Compress-Raw-Bzip2 perl-Compress-Raw-Zlib libaio perl-DBI perl-Data-Dumper perl-Encode perl-Exporter perl-File-Path perl-File-Temp perl-Filter perl-Getopt-Long perl-HTTP-Tiny perl-IO-Compress perl-Net-Daemon perl-PathTools perl-PlRPC perl-Pod-Escapes perl-Pod-Perldoc perl-Pod-Simple perl-Pod-Usage perl-Scalar-List-Utils perl-Socket perl-Storable perl-Text-ParseWords perl-Time-HiRes perl-Time-Local perl-constant perl-libs perl-macros perl-parent perl-podlators perl-threads perl-threads-shared 2&>1 /dev/null
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo yum remove -y mariadb-libs 2&>1 /dev/null
        	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo ambari-server setup -s --java-home=$JAVA_HOME &>/tmp/as_setup.txt
        	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo echo "api.csrfPrevention.enabled=false" | sudo tee --append  /etc/ambari-server/conf/ambari.properties &>/dev/null
        	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo ambari-server start &> /tmp/as_startup.txt	
        else

        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER yum -y install ansible perl perl-Carp perl-Compress-Raw-Bzip2 perl-Compress-Raw-Zlib libaio perl-DBI perl-Data-Dumper perl-Encode perl-Exporter perl-File-Path perl-File-Temp perl-Filter perl-Getopt-Long perl-HTTP-Tiny perl-IO-Compress perl-Net-Daemon perl-PathTools perl-PlRPC perl-Pod-Escapes perl-Pod-Perldoc perl-Pod-Simple perl-Pod-Usage perl-Scalar-List-Utils perl-Socket perl-Storable perl-Text-ParseWords perl-Time-HiRes perl-Time-Local perl-constant perl-libs perl-macros perl-parent perl-podlators perl-threads perl-threads-shared 2&>1 /dev/null
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER yum remove -y mariadb-libs 2&>1 /dev/null
        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER yum -y install ambari-server 2&>1 /dev/null
        	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER ambari-server setup -s --java-home=$JAVA_HOME &>/tmp/as_setup.txt
        	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER echo "api.csrfPrevention.enabled=false" | sudo tee --append  /etc/ambari-server/conf/ambari.properties &>/dev/null
		$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER ambari-server start &> /tmp/as_startup.txt
	fi
}


setup_ambari_agent()
{
	echo -en "\033[32m`timestamp` \033[32mInstalling Ambari-Agent\033[0m"
        for host in `echo $AMBARI_AGENTS`
        do
                AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
		host_ip=`awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
		
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT sudo yum -y install ambari-agent 2&>1 /tmp/aa_install.txt
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT sudo ambari-agent reset $AMBARI_SERVER &> /tmp/aa_reset.txt
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT sudo service ambari-agent start &> /tmp/aa_start.txt
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo cp /tmp/jce_policy-8.zip $JAVA_JCE_PATH"  2> /dev/null
	else
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT yum -y install ambari-agent 2&>1 /tmp/aa_install.txt
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT ambari-agent reset $AMBARI_SERVER &> /tmp/aa_reset.txt
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT service ambari-agent start 2&>1 /tmp/aa_start.txt
		$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip  cp /tmp/jce_policy-8.zip $JAVA_JCE_PATH  &> /dev/null
                #cat /tmp/commands_ambari_agent|$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT & 2&>1 /dev/null
	fi
        done
        wait
}

ranger_mysql_setup()
{
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then

                $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_SERVER "sudo rpm -ivh http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-client-5.6.39-2.el7.x86_64.rpm http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-libs-5.6.39-2.el7.x86_64.rpm  http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-common-5.6.39-2.el7.x86_64.rpm http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql-connector-java/mysql-connector-java-5.1.37-1.noarch.rpm  http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-server-5.6.39-2.el7.x86_64.rpm   http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-libs-5.6.39-2.el7.x86_64.rpm" &> /tmp/mysql_pkginstall.txt
		wait
		# printf "systemctl  start mysqld 2>/dev/null\n/usr/bin/mysql -e \"UPDATE mysql.user SET Password=PASSWORD('$DB_ROOT_PASS') WHERE User='root';\" 2>/dev/null\n/usr/bin/mysql -e \"flush privileges;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'root'@'$AMBARI_SERVER' identified by '$DB_ROOT_PASS';\" 2>/dev/null\n /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'root'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'rangeradmin'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'rangeradmin'@'$AMBARI_SERVER' identified by 'hadoop';\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'ranger'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"flush privileges;\" 2>/dev/null\n" > /tmp/commands_mysql
                printf "sudo systemctl  start mysqld 2>/dev/null\nsudo /usr/bin/mysql -e \"UPDATE mysql.user SET Password=PASSWORD('$DB_ROOT_PASS') WHERE User='root';\" 2>/dev/null\nsudo /usr/bin/mysql -e \"flush privileges;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'root'@'$AMBARI_SERVER' identified by '$DB_ROOT_PASS';\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'root'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'rangeradmin'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'rangeradmin'@'$AMBARI_SERVER' identified by 'hadoop';\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'ranger'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"flush privileges;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'hive'@'$AMBARI_SERVER' identified by 'hadoop';\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'hive'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"flush privileges;\" 2>/dev/null\nsudo systemctl  start mysqld 2>/dev/null\n"> /tmp/commands_mysql
                cat /tmp/commands_mysql|$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER &> /tmp/exec_commands_mysql
                $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_SERVER "sudo ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar" &>/dev/null


	else

                $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_SERVER "rpm -ivh http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-client-5.6.39-2.el7.x86_64.rpm http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-libs-5.6.39-2.el7.x86_64.rpm  http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-common-5.6.39-2.el7.x86_64.rpm http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql-connector-java/mysql-connector-java-5.1.37-1.noarch.rpm  http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-server-5.6.39-2.el7.x86_64.rpm   http://maxiq:"Uns%40vedD0cument1"@"$REPO_SERVER"/repo/hadoop/hortonworks/hdp/centos7/HDP-UTILS-1.1.0.21/mysql/mysql-community-libs-5.6.39-2.el7.x86_64.rpm" &> /tmp/mysql_pkginstall.txt
		wait

                #printf "sudo systemctl  start mysqld 2>/dev/null\nsudo /usr/bin/mysql -e \"UPDATE mysql.user SET Password=PASSWORD('$DB_ROOT_PASS') WHERE User='root';\" 2>/dev/null\nsudo /usr/bin/mysql -e \"flush privileges;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'root'@'$AMBARI_SERVER' identified by '$DB_ROOT_PASS';\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'root'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'rangeradmin'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'rangeradmin'@'$AMBARI_SERVER' identified by 'hadoop';\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'ranger'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\nsudo /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"flush privileges;\" 2>/dev/null\n "> /tmp/commands_mysql
		printf "systemctl  start mysqld 2>/dev/null\n/usr/bin/mysql -e \"UPDATE mysql.user SET Password=PASSWORD('$DB_ROOT_PASS') WHERE User='root';\" 2>/dev/null\n/usr/bin/mysql -e \"flush privileges;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'root'@'$AMBARI_SERVER' identified by '$DB_ROOT_PASS';\" 2>/dev/null\n /usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'root'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'rangeradmin'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'rangeradmin'@'$AMBARI_SERVER' identified by 'hadoop';\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'ranger'@'$AMBARI_SERVER' with grant option;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"flush privileges;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'hive'@'$AMBARI_SERVER' identified by 'hadoop';\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"grant all privileges on *.* to 'hive'@'$AMBARI_SERVER'  with grant option;\" 2>/dev/null\n/usr/bin/mysql -u root -p$DB_ROOT_PASS -e \"flush privileges;\" 2>/dev/null\nsystemctl  start mysqld 2>/dev/null\n" > /tmp/commands_mysql
                cat /tmp/commands_mysql|$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER &> /tmp/exec_commands_mysql
                $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_SERVER "ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar" &>/dev/null
	fi
}

setup_hdp()
{
        $LOC/generate_json.sh $CLUSTER_PROPERTIES $AMBARI_SERVER_IP
        #printf "\n$(tput setaf 2)Please hit http://$AMBARI_SERVER_IP:8080 in your browser and check installation status!\n\nIt would not take much time :)\n\nHappy Hadooping!\n$(tput sgr 0)"
#	echo -e  "\033[32m`timestamp` Please hit http://$AMBARI_SERVER_IP:8080 in your browser and check installation status"'!'"\033[0m"
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
		echo -e  "\033[32m`timestamp` \033[32mPlease hit\033[0m \033[44mhttp://$PUBLIC_IP:8080\033[0m \033[32min your browser and check installation status"'!'"\033[0m"
	else
		echo -e  "\033[32m`timestamp` \033[32mPlease hit\033[0m \033[44mhttp://$IP:8080\033[0m \033[32min your browser and check installation status"'!'"\033[0m"
	fi
		
#        mv ~/.ssh/known_hosts.bak ~/.ssh/known_hosts
        #end_time=`date +%s`
        #start_time=`cat /tmp/start_time`
        #runtime=`echo "($end_time-$start_time)/60"|bc -l`
        #printf "\n\n$(tput setaf 2)Script runtime(Including time taken for manual intervention) - $runtime minutes!\n$(tput sgr 0)"
        #TS=`date +%Y-%m-%d,%H:%M:%S`
        #echo "$TS|`whoami`|$runtime" > /tmp/usage_track_"$USER"_"$TS"
}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Function to provide HDFS params for Mosaic Props file
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
components="NAMENODE HIVE_SERVER HBASE_MASTER RESOURCEMANAGER ZOOKEEPER_SERVER OOZIE_SERVER"

serv_fun(){
                #echo "Service URL for $service is as below:"

                service_name=`cat $LOC/$CLUSTER_PROPERTIES |grep -w HOST[1-9]*_SERVICES |grep -i $service |cut -d"_" -f1|tr '\n' ' '`
                #echo $service_name
                service_host=`grep $service_name $LOC/$CLUSTER_PROPERTIES |head -n 1 |awk -F "=" '{print $2}'`
                #echo $service_host

}
mosaic_params(){

for service in $components
do
        if [ $service == NAMENODE ]
        then
                serv_fun
                service_url=$service_host.$DOMAIN_NAME:8020
                #echo $service_url
                sed -i "s/hdfs_default_system_path:.*/hdfs_default_system_path: $service_url/g" $LOC/$mosaic_path/group_vars/all_DEV
                sed -i "s/namenode_addr:.*/namenode_addr: $service_host.$DOMAIN_NAME/g" $LOC/$mosaic_path/group_vars/all_DEV
        elif [ $service == "ZOOKEEPER_SERVER" ]
        then
                                        rm -fr /tmp/test_var
                                        rm -fr /tmp/test_f_var
                                service_name=`cat $LOC/$CLUSTER_PROPERTIES |grep -w HOST[1-9]*_SERVICES |grep -i $service |cut -d"_" -f1|tr '\n' ' '`
                                for zk_server in $service_name
                                do
                                        service_host=`grep $zk_server $LOC/$CLUSTER_PROPERTIES |head -n 1 |awk -F "=" '{print $2}'`
                                        echo $service_host|tr '\n' ' ' >> /tmp/test_var
                                        cat /tmp/test_var |sed s'/.$//' | sed 's/ /,/g'> /tmp/test_f_var
                                done
                                        ZK_URL=`cat /tmp/test_f_var`
                                        #echo  "Service URL for $service is as below:"
                                        #echo $ZK_URL.$DOMAIN_NAME
                sed -i "s/zk_quorom:.*/zk_quorom: $ZK_URL.$DOMAIN_NAME/g" $LOC/$mosaic_path/group_vars/all_DEV
        elif [ $service == "RESOURCEMANAGER" ]
        then
                #echo "Service URL for $service is as below:"
                serv_fun
                #echo $service_host.$DOMAIN_NAME:8050
                sed -i "s/rm_addr:.*/rm_addr: $service_host.$DOMAIN_NAME:8050/g" $LOC/$mosaic_path/group_vars/all_DEV

        elif [ $service == "OOZIE_SERVER" ]
        then
                serv_fun
		#echo $service_host.$DOMAIN_NAME
                sed -i "s/oozieServerUrl:.*/oozieServerUrl: $service_host.$DOMAIN_NAME/g" $LOC/$mosaic_path/group_vars/all_DEV

        elif [ $service == "HIVE_SERVER" ]
        then
                serv_fun
		#echo $service_host.$DOMAIN_NAME
                sed -i "s/hive_server:.*/hive_server: $service_host.$DOMAIN_NAME/g" $LOC/$mosaic_path/group_vars/all_DEV

        elif [ $service == "HBASE_MASTER" ]
        then

                serv_fun
		#echo $service_host.$DOMAIN_NAME
                sed -i "s/hbase_master:.*/hbase_master: $service_host.$DOMAIN_NAME/g" $LOC/$mosaic_path/group_vars/all_DEV
        else
                serv_fun
                service_url=$service_host.$DOMAIN_NAME
                #echo $service_url
        fi

done
}


start_stop_cluster()
{
#stop all services
curl -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD  -i -H 'X-Requested-By: ambari' -X PUT \
   -d '{"RequestInfo":{"context":"_PARSE_.STOP.ALL_SERVICES","operation_level":{"level":"CLUSTER","cluster_name":"$ClusterName"}},"Body":{"ServiceInfo":{"state":"INSTALLED"}}}' \
   http://$AMBARI_SERVER:8080/api/v1/clusters/$CLUSTERNAME/services

sleep 60

#start all services
curl -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -H 'X-Requested-By: ambari' -X PUT \
   -d '{"RequestInfo":{"context":"_PARSE_.START.ALL_SERVICES","operation_level":{"level":"CLUSTER","cluster_name":"$ClusterName"}},"Body":{"ServiceInfo":{"state":"STARTED"}}}' \
   http://$AMBARI_SERVER:8080/api/v1/clusters/$CLUSTERNAME/services
}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

if [ $REPO_SERVER = "public" ]
then
        echo -e  "\033[32m`timestamp` \033[32mGetting Host and IP Details\033[0m"
        prepare_hosts_file
        echo -e  "\033[32m`timestamp` \033[32mSetting up Ambari Repository\033[0m"
        generate_ambari_repo
        echo -e  "\033[32m`timestamp` \033[32mGetting Setting Pre-requisites\033[0m"
        pre_rep
        check_java_install
else
        echo -e  "\033[32m`timestamp` \033[32mGetting Host and IP Details\033[0m"
        prepare_hosts_file
        echo -e  "\033[32m`timestamp` \033[32mSetting up Base OS Repository\033[0m"
        generate_centos_repo
        echo -e  "\033[32m`timestamp` \033[32mSetting up Ambari Repository\033[0m"
        generate_ambari_repo
        echo -e  "\033[32m`timestamp` \033[32mGetting Setting Pre-requisites\033[0m"
        localrepo_pre_rep
        pre_rep
        install_java
fi

bootstrap_hosts
setup_ambari_server
if [ $REPO_SERVER = "public" ]
then
        if [ $RANGER_STATUS == yes ]
        then
                ranger_mysql_setup
        else
                echo "No ranger installed" &> /dev/null
        fi
else
        if [ $RANGER_STATUS == yes ]
        then
                ranger_mysql_setup
        else
                echo "No ranger installed" &> /dev/null
        fi
fi
setup_ambari_agent
sudo systemctl  status mysqld &>/tmp/mysql_status
sudo systemctl  start mysqld &>/tmp/mysql_statup
setup_hdp
echo "Please wait .. sleep for 1min"
sleep 60
sh $LOC/post_script.sh $CLUSTER_PROPERTIES &> /tmp/post_install.txt
sleep 180
start_stop_cluster

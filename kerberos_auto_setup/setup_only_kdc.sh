#!/bin/bash
#Script to setup kerberos in one click! :)
#Author - Sagar Shimpi
#############

LOC=`pwd`
PROP=ambari.props
source $LOC/$PROP
PASSWORD=`grep -w SSH_SERVER_PASSWORD $LOC/$PROP|cut -d'=' -f2`
PVT_KEY=`grep -w SSH_SERVER_PRIVATE_KEY $LOC/$PROP|cut -d'=' -f2`
echo $PASSSWORD
JAVA_HOME=`grep  -w JAVA_HOME  $LOC/$PROP |cut -d'=' -f2`
JAVA_JCE_PATH=`echo $JAVA_HOME/jre/lib/security`
PVT_KEY=`grep -w SSH_SERVER_PRIVATE_KEY $LOC/$PROP|cut -d'=' -f2`
KDC_HOST=`grep -w KDC_HOST $LOC/$PROP|cut -d'=' -f2`
REALM=`grep -w REALM $LOC/$PROP|cut -d'=' -f2|sed '/#/d'`
sudo cp -ar  $LOC/krb5.conf.default.bak $LOC/krb5.conf.default
SHORT_REALM=`echo $REALM |tr "[A-Z]" "[a-z]"`

echo $KDC_HOST
#############

ts()
{
	echo "`date +%Y-%m-%d,%H:%M:%S`"
}


if [ -z $PVT_KEY ]
then
        echo -e "\033[32m`ts` \033[32mUsing Plain Password For Cluster Setup\033[0m"
        echo $PASSSWORD
        ssh_cmd="sshpass -p $PASSWORD ssh"
        scp_cmd="sshpass -p $PASSWORD scp"
else
        echo -e "\033[32m`ts` \033[32mUsing Private Key For Cluster Setup\033[0m"
        echo $PASSSWORD
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

download_jce(){

        echo -en "\033[32m`ts` \033[32mInstalling JCE policies\033[0m"
        for host in "${KERBEROS_CLIENTS[@]}"
        do
                KRB5_AGENT=`echo $host`
        #host_ip=`awk "/$host/{getline; print}"  $LOC/ambari.props|cut -d'=' -f 2`
        if [ "$SSH_USER" != "root" ]
        then
                wait
                $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$KRB5_AGENT "sudo /usr/bin/unzip -o -j -q $JAVA_JCE_PATH/jce_policy-8.zip -d $JAVA_JCE_PATH/"
        else
                wait
                $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$KRB5_AGENT "/usr/bin/unzip -o -j -q $JAVA_JCE_PATH/jce_policy-8.zip -d $JAVA_JCE_PATH/"
        fi
        done

	if [ "$SSH_USER" != "root" ]
        then
		sudo /etc/init.d/ambari-server restart &> /dev/null
	else
		/etc/init.d/ambari-server restart &> /dev/null
	fi

}

setup_kdc()
{

	echo -e "\n`ts` Installing kerberos RPMs"
	sudo yum -y install krb5-server krb5-libs krb5-workstation
        sudo cp $LOC/krb5.conf.default.bak.org $LOC/krb5.conf.default.bak
        sudo cp $LOC/krb5.conf.default.bak $LOC/krb5.conf.default
	echo -e "\n`ts` Configuring Kerberos"
	sed -i.bak "s/EXAMPLE.COM/$REALM/g" $LOC/krb5.conf.default
	sed -i.bak "s/kerberos.example.com/$KDC_HOST/g" $LOC/krb5.conf.default
	sed -i.bak "s/example.com/$SHORT_REALM/g" $LOC/krb5.conf.default
	sudo cat $LOC/krb5.conf.default |sudo tee /etc/krb5.conf
	sudo kdb5_util create -s -P hadoop
	echo -e "\n`ts` Starting KDC services"
	sudo service krb5kdc start
	sudo service kadmin start
	sudo chkconfig krb5kdc on
	sudo chkconfig kadmin on
	echo -e "\n`ts` Creating admin principal"
	sudo kadmin.local -q "addprinc -pw hadoop admin/admin"
	sudo sed -i.bak "s/EXAMPLE.COM/$REALM/g" /var/kerberos/krb5kdc/kadm5.acl
	sudo sed -i.bak "s/EXAMPLE.COM/$REALM/g" /var/kerberos/krb5kdc/kdc.conf
	echo -e "\n`ts` Restarting kadmin"
	sudo service kadmin restart
}



download_jce |tee -a $LOC/jce_setup.log
setup_kdc|tee -a $LOC/Kerb_setup.log
mv $LOC/doSet_version* /tmp &>/dev/null


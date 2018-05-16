#!/bin/bash

LOC=`pwd`
PROP=ldap.props
source $LOC/$PROP

timestamp()
{
        echo "`date +%Y-%m-%d,%H:%M:%S`"
}


if [ -z $SSH_SERVER_PRIVATE_KEY ]
then
        echo -e "\033[32m`timestamp` \033[32mUsing Plain Password For Cluster Setup\033[0m"
        #echo $PASSSWORD
        ssh_cmd="sshpass -p $SSH_SERVER_PASSWORD ssh"
        scp_cmd="sshpass -p $SSH_SERVER_PASSWORD scp"
else
        echo -e "\033[32m`timestamp` \033[32mUsing Private Key For Cluster Setup\033[0m"
        #echo $PASSSWORD
                ssh_cmd="ssh -i $SSH_SERVER_PRIVATE_KEY"
                scp_cmd="scp -i $SSH_SERVER_PRIVATE_KEY"
        if [ -e $SSH_SERVER_PRIVATE_KEY ]
        then
                echo "File Exist" &> /dev/null
        else
                echo -e "\033[35mPrivate key is missing.. Please check!!!\033[0m"
                exit 1;
        fi
fi


openldap_server(){

echo -e  "\033[32m`timestamp` \033[32mInstalling Openldap Server Packages \033[0m"
sudo yum install openldap-* mlocate migrationtools sshpass -y 2&>1 /dev/null
slappasswd=`slappasswd -s $OPENLDAP_SERVER_SLAPPASSWD`
sudo sed -i 's/my-domain/lti/g' /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}hdb.ldif
#sudo echo "olcRootPW: $slappasswd" >> /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}hdb.ldif
echo "olcRootPW: $slappasswd" | sudo tee --append /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}hdb.ldif &>/dev/null
sudo /bin/sed -i 's/my-domain/lti/g' /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{1\}monitor.ldif
sudo /bin/updatedb
sudo cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
sudo chown ldap:ldap -Rf /var/lib/ldap
sudo systemctl start slapd
sudo /bin/sed -i "s/ou=Group/ou=Groups/g" /usr/share/migrationtools/migrate_common.ph
sudo /bin/sed -i 's/DEFAULT_MAIL_DOMAIN = "padl.com"/DEFAULT_MAIL_DOMAIN = "lti.com"/g' /usr/share/migrationtools/migrate_common.ph
sudo /bin/sed -i 's/DEFAULT_BASE = "dc=padl,dc=com"/DEFAULT_BASE = "dc=lti,dc=com"/g' /usr/share/migrationtools/migrate_common.ph
sudo /bin/sed -i 's/EXTENDED_SCHEMA = 0/EXTENDED_SCHEMA = 1/g' /usr/share/migrationtools/migrate_common.ph

echo -e  "\033[32m`timestamp` \033[32mSetting Up Test Users and Groups \033[0m"
#Create LDIF file for base users
sudo mkdir /root/ldap/
#sudo /usr/share/migrationtools/migrate_base.pl >/root/ldap/base.ldif
sudo  /usr/share/migrationtools/migrate_base.pl | sudo tee --append /root/ldap/base.ldif &>/dev/null

#Create users,password and groups for LDAP user testing
sudo mkdir /home/ldap
sudo /usr/sbin/useradd -d /home/ldap/user1 -u 3100 user1
sudo /usr/sbin/useradd -d /home/ldap/user2 -u 3101 user2
sudo /usr/sbin/useradd -d /home/ldap/user3 -u 3102 user3

sudo /usr/bin/echo -e "user1\nuser1" |(passwd --stdin user1)
sudo /usr/bin/echo -e "user2\nuser2" |(passwd --stdin user2)
sudo /usr/bin/echo -e "user3\nuser3" |(passwd --stdin user3)
#sudo /bin/getent passwd |tail -n 3   >/root/ldap/users
sudo /bin/getent passwd |tail -n 3 | sudo tee --append /root/ldap/users &>/dev/null
#sudo /bin/getent shadow |tail -n 3  >/root/ldap/passwords
sudo /bin/getent shadow |tail -n 3 | sudo tee --append /root/ldap/passwords &>/dev/null
#sudo /bin/getent group |tail -n 3   >/root/ldap/groups
sudo /bin/getent group |tail -n 3 | sudo tee --append /root/ldap/groups &>/dev/null

#Create LDAP files for users
sudo /usr/share/migrationtools/migrate_passwd.pl /root/ldap/users | sudo tee --append /root/ldap/users.ldif &>/dev/null
sudo /usr/share/migrationtools/migrate_group.pl /root/ldap/groups | sudo tee --append /root/ldap/groups.ldif &>/dev/null

#Add schema
sudo /bin/ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f  /etc/openldap/schema/cosine.ldif
sudo /bin/ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f /etc/openldap/schema/nis.ldif
sudo /bin/ldapadd  -Y EXTERNAL -H ldapi:// -f /etc/openldap/schema/inetorgperson.ldif

#Add data to ldap servers
echo -e  "\033[32m`timestamp` \033[32mAdding test users and groups to LDAP \033[0m"
sudo /bin/ldapadd -x -w redhat -D "cn=Manager,dc=lti,dc=com" -f /root/ldap/base.ldif
sudo /bin/ldapadd -x -w redhat -D "cn=Manager,dc=lti,dc=com" -f /root/ldap/users.ldif
sudo /bin/ldapadd -x -w redhat -D "cn=Manager,dc=lti,dc=com" -f /root/ldap/groups.ldif

#Map users and groups
echo -e  "\033[32m`timestamp` \033[32mConfigure Users to Group Mappings \033[0m"
sudo bash -c 'cat <<EOF >> /tmp/groupsmap1.ldif
dn: cn=user1,ou=Groups,dc=lti,dc=com
changetype: modify
add: memberUid
memberUid: user1
EOF'

sudo bash -c 'cat <<EOF >> /tmp/groupsmap2.ldif
dn: cn=user2,ou=Groups,dc=lti,dc=com
changetype: modify
add: memberUid
memberUid: user2
EOF'

sudo bash -c 'cat <<EOF >> /tmp/groupsmap3.ldif
dn: cn=user3,ou=Groups,dc=lti,dc=com
changetype: modify
add: memberUid
memberUid: user3
EOF'

sudo /bin/ldapmodify -D "cn=Manager,dc=lti,dc=com" -w redhat < /tmp/groupsmap1.ldif
sudo /bin/ldapmodify -D "cn=Manager,dc=lti,dc=com" -w redhat < /tmp/groupsmap2.ldif
sudo /bin/ldapmodify -D "cn=Manager,dc=lti,dc=com" -w redhat < /tmp/groupsmap3.ldif

#Removing test users created locally
sudo /usr/sbin/userdel -r user1
sudo /usr/sbin/userdel -r user2
sudo /usr/sbin/userdel -r user3
echo -e  "\033[32m`timestamp` \033[32mOpenldap server setup completed successfully \033[0m"



}

openldap_clients(){


        for host in "${OPENLDAP_CLIENTS[@]}"
        do
                LDAP_CLIENT=`echo $host`
        #host_ip=`awk "/$host/{getline; print}"  $LOC/ambari.props|cut -d'=' -f 2`
        if [ "$SSH_USER" != "root" ]
        then
                wait
                $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $SSH_USER@$LDAP_CLIENT "sudo yum install openldap-clients openldap-devel nss-pam-ldapd pam_ldap authconfig authconfig-gtk openldap* -y 2&>1 /dev/null"
		wait
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $SSH_USER@$LDAP_CLIENT "sudo /sbin/authconfig  --enableldap --enableldapauth  --enablemkhomedir --ldapserver=ldap://$OPENLDAP_SERVER_HOSTNAME:389 --ldapbasedn="dc=lti,dc=com" --update"
		wait
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $SSH_USER@$LDAP_CLIENT "sudo systemctl restart nslcd &> /dev/null"
		echo -e  "\033[32m`timestamp` \033[32mOpenldap Client Setup Completed\033[0m"
		wait
        else
                wait
                $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $SSH_USER@$LDAP_CLIENT "yum install openldap-clients openldap-devel nss-pam-ldapd pam_ldap authconfig authconfig-gtk openldap* -y  2&>1 /dev/null"
		wait
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $SSH_USER@$LDAP_CLIENT "/sbin/authconfig  --enableldap --enableldapauth  --enablemkhomedir --ldapserver=ldap://$OPENLDAP_SERVER_HOSTNAME:389 --ldapbasedn="dc=lti,dc=com" --update"
		wait
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $SSH_USER@$LDAP_CLIENT "systemctl restart nslcd &> /dev/null"
        fi
        done

}

openldap_server
openldap_clients

#!/bin/sh

#Script arguments
domainHost=${1}
domainName=${2}
domainUser=${3}
domainPassword=${4}
nodeName=${5}
nodePort=${6}

dbType=${7}
dbName=${8}
dbUser=${9}
dbPassword=${10}
dbHost=${11}
dbPort=${12}

sitekeyKeyword=${13}

joinDomain=${14}
osUserName=${15}

storageName=${16}
storageKey=${17}

domainLicenseURL=${18}

mrsdbuser=${19}
mrsdbpwd=${20}
refdatadbuser=${21}
refdatadbpwd=${22}
profiledbuser=${23}
profiledbpwd=${24}

echo Starting Informatica setup...
echo Number of parameters $#
#echo $domainHost $domainName $domainUser $domainPassword $nodeName $nodePort $dbType $dbName $dbUser $dbPassword $dbHost $dbPort $sitekeyKeyword $joinDomain $osUserName $storageName $storageKey $domainLicenseURL

#Usage
if [ $# -ne 24 ]
then
	echo lininfainstaller.sh domainHost domainName domainUser domainPassword nodeName nodePort dbType dbName dbUser dbPassword dbHost dbPort sitekeyKeyword joinDomain  osUserName storageName storageKey domainLicenseURL mrsdbuser mrsdbpwd refdatadbuser refdatadbpwd profiledbuser profiledbpwd
	exit -1
fi

dbaddress=$dbHost:$dbPort
hostname=`hostname`

#preparing connection strings
dataacccessstring=$dbHost"@"$dbName
metadataaccessstring="'jdbc:informatica:sqlserver://"$dbaddress";SelectMethod=cursor;databaseName="$dbName"'"
mrscustomstring="jdbc:informatica:sqlserver://"$dbaddress";DatabaseName="$dbName";SnapshotSerializable=true"

informaticaopt=/opt/Informatica
infainstallerloc=$informaticaopt/Archive/server
utilityhome=$informaticaopt/Archive/utilities


infainstallionlocown=/home/Informatica
#mkdir -p $infainstallionlocown/10.1.1

echo Creating symbolic link to Informatica installation
ln -s $infainstallionlocown /home/$osUserName

infainstallionloc=\\/home\\/Informatica\\/10.1.1
defaultkeylocation=$infainstallionloc\\/isp\\/config\\/keys
licensekeylocation=\\/opt\\/Informatica\\/license.key

# Firewall configurations
echo Adding firewall rules for Informatica domain service ports
iptables -A IN_public_allow -p tcp -m tcp --dport 6005:6008 -m conntrack --ctstate NEW -j ACCEPT
iptables -A IN_public_allow -p tcp -m tcp --dport 6014:6114 -m conntrack --ctstate NEW -j ACCEPT
iptables -A IN_public_allow -p tcp -m tcp --dport 8085 -m conntrack --ctstate NEW -j ACCEPT

JRE_HOME="$infainstallerloc/source/java/jre"
export JRE_HOME		
PATH="$JRE_HOME/bin":"$PATH"
export PATH

chmod -R 777 $JRE_HOME

cloudsupportenable=1
if [ "$domainLicenseURL" != "nolicense" -a $joinDomain -eq 0 ]
then
	echo Getting Informatica license
	cd $utilityhome
	java -jar iadutility.jar downloadHttpUrlFile -url $domainLicenseURL -localpath $informaticaopt/license.key

	if [ -f $informaticaopt/license.key ]
	then
		cloudsupportenable=0
	else
		echo Error downloading license file from URL $domainLicenseURL
	fi
fi


createDomain=1
if [ $joinDomain -eq 1 ]
then
    createDomain=0
	# This is buffer time for master node to start
	sleep 300
else
	echo Creating shared directory on Azure storage
	cd $utilityhome
    java -jar iadutility.jar createAzureFileShare -storageaccesskey $storageKey -storagename $storageName
fi

echo Mounting the shared directory
mountdir=/mnt/infaaeshare
mkdir $mountdir
mount -t cifs //$storageName.file.core.windows.net/infaaeshare $mountdir -o vers=3.0,username=$storageName,password=$storageKey,dir_mode=0777,file_mode=0777
echo //$storageName.file.core.windows.net/infaaeshare $mountdir cifs vers=3.0,username=$storageName,password=$storageKey,dir_mode=0777,file_mode=0777 >> /etc/fstab

echo Editing Informatica silent installation file
sed -i s/^LICENSE_KEY_LOC=.*/LICENSE_KEY_LOC=$licensekeylocation/ $infainstallerloc/SilentInput.properties

sed -i s/^USER_INSTALL_DIR=.*/USER_INSTALL_DIR=$infainstallionloc/ $infainstallerloc/SilentInput.properties

sed -i s/^CREATE_DOMAIN=.*/CREATE_DOMAIN=$createDomain/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_DOMAIN=.*/JOIN_DOMAIN=$joinDomain/ $infainstallerloc/SilentInput.properties

sed -i s/^CLOUD_SUPPORT_ENABLE=.*/CLOUD_SUPPORT_ENABLE=$cloudsupportenable/ $infainstallerloc/SilentInput.properties

sed -i s/^ENABLE_USAGE_COLLECTION=.*/ENABLE_USAGE_COLLECTION=1/ $infainstallerloc/SilentInput.properties

sed -i s/^KEY_DEST_LOCATION=.*/KEY_DEST_LOCATION=$defaultkeylocation/ $infainstallerloc/SilentInput.properties

sed -i s/^PASS_PHRASE_PASSWD=.*/PASS_PHRASE_PASSWD=$(echo $sitekeyKeyword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

sed -i s/^SERVES_AS_GATEWAY=.*/SERVES_AS_GATEWAY=1/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_TYPE=.*/DB_TYPE=$dbType/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_UNAME=.*/DB_UNAME=$dbUser/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_PASSWD=.*/DB_PASSWD=$(echo $dbPassword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_SERVICENAME=.*/DB_SERVICENAME=$dbName/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_ADDRESS=.*/DB_ADDRESS=$dbaddress/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_NAME=.*/DOMAIN_NAME=$domainName/ $infainstallerloc/SilentInput.properties

sed -i s/^NODE_NAME=.*/NODE_NAME=$nodeName/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_PORT=.*/DOMAIN_PORT=$nodePort/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_NODE_NAME=.*/JOIN_NODE_NAME=$nodeName/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_HOST_NAME=.*/JOIN_HOST_NAME=$hostname/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_DOMAIN_PORT=.*/JOIN_DOMAIN_PORT=$nodePort/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_USER=.*/DOMAIN_USER=$domainUser/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_HOST_NAME=.*/DOMAIN_HOST_NAME=$domainHost/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_PSSWD=.*/DOMAIN_PSSWD=$(echo $domainPassword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_CNFRM_PSSWD=.*/DOMAIN_CNFRM_PSSWD=$(echo $domainPassword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

# To speed up installation
mv $infainstallerloc/source $infainstallerloc/source_temp
mkdir $infainstallerloc/source
mv $infainstallerloc/unjar_esd.sh $infainstallerloc/unjar_esd.sh_temp
head -1 $infainstallerloc/unjar_esd.sh_temp > $infainstallerloc/unjar_esd.sh
echo exit_value_unjar_esd=0 >> $infainstallerloc/unjar_esd.sh
chmod 777 $infainstallerloc/unjar_esd.sh

echo Installing Informatica domain
cd $infainstallerloc
echo Y Y | sh silentinstall.sh 


# Revert speed up changes
mv $infainstallerloc/source_temp/* $infainstallerloc/source
rm $infainstallerloc/unjar_esd.sh
mv $infainstallerloc/unjar_esd.sh_temp $infainstallerloc/unjar_esd.sh


echo Changing ownership of directories
chown -R $osUserName $infainstallionlocown
chown -R $osUserName $informaticaopt 
chown -R $osUserName $mountdir
chown -R $osUserName /home/$osUserName

function createDQServices {
    echo "Creating DQ services Start" >> $informaticaopt/InfaServiceLog.log
	
	echo "Creating STAGE connection" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh createConnection -dn $domainName -un $domainUser -pd $domainPassword -cn STAGE -cid STAGE -ct SQLSERVER -cun $refdatadbuser -cpd $refdatadbpwd -o CodePage='UTF-8' DataAccessConnectString=''$dataacccessstring'' MetadataAccessConnectString=''$metadataaccessstring'' &>> $informaticaopt/InfaServiceLog.log

	echo "Creating PROFILE connection" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh createConnection -dn $domainName -un $domainUser -pd $domainPassword -cn PROFILE -cid PROFILE -ct SQLSERVER -cun $profiledbuser -cpd $profiledbpwd -o CodePage='UTF-8' DataAccessConnectString=''$dataacccessstring'' MetadataAccessConnectString=''$metadataaccessstring'' &>> $informaticaopt/InfaServiceLog.log

	echo "Creating Model Repository Service" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh mrs createService -dn $domainName -nn $nodeName -un $domainUser -pd $domainPassword -sn ModelRepositoryService -du $mrsdbuser -dp $mrsdbpwd -dl $mrscustomstring -dt SQLSERVER &>> $informaticaopt/InfaServiceLog.log
	
	echo "Creating Data Integration Service" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh dis createService -dn $domainName -nn $nodeName -un $domainUser -pd $domainPassword -sn DataIntegrationService -rs ModelRepositoryService -rsun $domainUser -rspd $domainPassword -HttpPort 8095 &>> $informaticaopt/InfaServiceLog.log
	
	echo "Creating Content Management Service" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh cms createService -dn $domainName -nn $nodeName -un $domainUser -pd $domainPassword -sn ContentManagementService -ds DataIntegrationService -rs ModelRepositoryService -rsu $domainUser -rsp $domainPassword -rdl STAGE -HttpPort 8105 &>> $informaticaopt/InfaServiceLog.log
	
	echo "Creating Analyst Service" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh as createService -dn $domainName -nn $nodeName -un $domainUser -pd $domainPassword -sn AnalystService -ds DataIntegrationService -rs ModelRepositoryService -au $domainUser -ap $domainPassword -HttpPort 8085 &>> $informaticaopt/InfaServiceLog.log

}

createDQServices


if [ -f $informaticaopt/license.key ]
then
	
	echo "Removing License Key"
	rm $informaticaopt/license.key

	echo "Retrieving License Name from Domain" >> $informaticaopt/InfaServiceLog.log
	aamit=$(sh /home/Informatica/10.1.1/isp/bin/infacmd.sh listLicenses -dn $domainName -un $domainUser -pd $domainPassword)
	infalicense=$aamit|cut -d ' ' -f 1
	echo "License Name: " $infalicense >> $informaticaopt/InfaServiceLog.log

	echo "Assigning License to all the services" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh assignLicense -dn $domainName -un $domainUser -pd $domainPassword -ln $infalicense -sn ModelRepositoryService DataIntegrationService ContentManagementService AnalystService >> $informaticaopt/InfaServiceLog.log

	echo "Enabling Model Repository Service" >> $informaticaopt/InfaServiceLog.log
    sh /home/Informatica/10.1.1/isp/bin/infacmd.sh enableService -dn $domainName -un $domainUser -pd $domainPassword -sn ModelRepositoryService >> $informaticaopt/InfaServiceLog.log

	echo "Creating contents of Model Repository Service" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh mrs createContents -dn $domainName -un $domainUser -pd $domainPassword -sn ModelRepositoryService >> $informaticaopt/InfaServiceLog.log

    echo "Assiging Profile connection to Data Integration Service" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh dis updateServiceoptions -dn $domainName -un $domainUser -pd $domainPassword -sn DataIntegrationService -o "ProfilingServiceOptions.ProfileWarehouseConnectionName=PROFILE" >> $informaticaopt/InfaServiceLog.log
	
    echo "Enabling Data Integration Service" >> $informaticaopt/InfaServiceLog.log
    sh /home/Informatica/10.1.1/isp/bin/infacmd.sh enableService -dn $domainName -un $domainUser -pd $domainPassword -sn DataIntegrationService >> $informaticaopt/InfaServiceLog.log

    echo "Creating Contents for Profiling Warehouse DataBase" >> $informaticaopt/InfaServiceLog.log
	sh /home/Informatica/10.1.1/isp/bin/infacmd.sh ps createWH -dn $domainName -un $domainUser -pd $domainPassword -dsn DataIntegrationService >> $informaticaopt/InfaServiceLog.log

    echo "Enabling Content Management Service" >> $informaticaopt/InfaServiceLog.log
    sh /home/Informatica/10.1.1/isp/bin/infacmd.sh enableService -dn $domainName -un $domainUser -pd $domainPassword -sn ContentManagementService >> $informaticaopt/InfaServiceLog.log

	echo "Creating Audit Table" >> $informaticaopt/InfaServiceLog.log
    sh /home/Informatica/10.1.1/isp/bin/infacmd.sh cms createAuditTables -dn $domainName -un $domainUser -pd $domainPassword -sn ContentManagementService >> $informaticaopt/InfaServiceLog.log

    echo "Enabling Analyst Service" >> $informaticaopt/InfaServiceLog.log
    sh /home/Informatica/10.1.1/isp/bin/infacmd.sh enableService -dn $domainName -un $domainUser -pd $domainPassword -sn AnalystService >> $informaticaopt/InfaServiceLog.log

fi

echo Informatica setup Complete.
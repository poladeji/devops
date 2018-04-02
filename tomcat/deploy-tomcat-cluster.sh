#!/bin/bash -x

CENTOS_VERSION="6"
VERSION=8.5.29
BASE_VERSION=8
ARTIFACT_BASE=""

mkdirs(){
	for host in $NODES; do

	   if [ $(lxc list $host | grep -c ) -gt 0 ]; then
		  lxc delete $host --force ;
	   fi
	done
        if [ -z $ARTIFACT_BASE ]; then
            ARTIFACT_BASE="."
        fi
        CONF_DIR=$ARTIFACT_BASE/conf
    for dir in scripts ssh apps conf; do mkdir -p $ARTIFACT_BASE/$dir; done

}


# Prompt users for info to create nodes

query(){
	declare -a HTTP_PORT
	declare -a AJP_PORT
	declare -a REDIRECT_PORT
	declare -a SHUTDOWN_PORT

	read -p "Cluster Name: " clustname
	read -p "Prefix:[tcat]: " prefix
	read -p "Scaling Factor:[2] " scalefact
	read -p "Scaling Type [H]-Horizontal;[V]-Vertical:[V] " scaletype
	read -p "Starting HTTP Port:[8080] " http_port
	read -p "Starting AJP Port:[8009] " ajp_port
	read -p "Starting SHUTDOWN Port:[8005] " shutdown_port
	read -p "Starting Redirect Port:[8443] " redirect_port
	read -p "Tomcat User:[tomcat] " tcat_user
	read -p "Tomcat Group:[tomcat] " tcat_group
	read -p "Tomcat User password: " tcat_passwd


	# Convert Scaling Type Input to uppercase
	scaletype=$(echo ${scaletype}| tr [a-z] [A-Z])
	
	if [ -z ${tcat_user} ]; then
		tcat_user="tomcat"
	fi
	if [ -z ${tcat_group} ]; then
		tcat_group=${tcat_user}
	fi
	if [ -z ${tcat_passwd} ]; then
		tcat_passwd="tomcat"
	fi

	if [ -z $prefix ]; then
		prefix="tcat"
	fi
	if [ -z $scalefact ]; then
		scalefact=2
	fi
	if [ -z $scaletype ]; then
	   scaletype='V'
	   NODES=${prefix}-${clustname}-0
	else
		NODES=""
		for ((i=0; i < $scalefact; i++)) ;
		do
		   NODES="$NODES ${prefix}-${clustname}-${i}"
		done
	fi
	if [ -z $http_port ]; then
		http_port=8080
	fi
	if [ -z $ajp_port ]; then
		ajp_port=8009
	fi
	if [ -z $shutdown_port ]; then
		shutdown_port=8005
	fi
	if [ -z $redirect_port ]; then
		redirect_port=8443
	fi
}

# Generate Spaced-Ports for Vertical Instances
generateServerXML(){
	if [ $scaletype = 'V' ]; then

		HTTP_PORT[0]=$http_port
		AJP_PORT[0]=$ajp_port
		REDIRECT_PORT[0]=$redirect_port
		SHUTDOWN_PORT[0]=$shutdown_port
		
		echo "${clustname}-0:${http_port}:$ajp_port;$redirect_port;$shutdown_port"
		sed -e "s/{HTTP}/${HTTP_PORT[0]}/g" -e "s/{AJP}/${AJP_PORT[0]}/g" -e "s/{REDIRECT}/${REDIRECT_PORT[0]}/g" -e "s/{SHUTDOWN}/${SHUTDOWN_PORT[0]}/g" -e "s/{ROUTE}/jvm0/g"  ${CONF_DIR}/server-template.xml > ${CONF_DIR}/server-0.xml
		for ((i=1; i<$scalefact; i++ )); do
			
		#	cat server-template.xml > server-${i}.xml
			HTTP_PORT[$i]=$((http_port + ${i}))
			AJP_PORT[$i]=$((ajp_port + ${i}))
			REDIRECT_PORT[$i]=$((redirect_port + ${i}))
			SHUTDOWN_PORT[$i]=$((shutdown_port + ${i}))

			sed  -e "s/{HTTP}/${HTTP_PORT[$i]}/g" -e "s/{AJP}/${AJP_PORT[$i]}/g" -e "s/{REDIRECT}/${REDIRECT_PORT[$i]}/g" -e "s/{SHUTDOWN}/${SHUTDOWN_PORT[$i]}/g" -e "s/{ROUTE}/jvm${i}/g"  ${CONF_DIR}/server-template.xml > ${CONF_DIR}/server-${i}.xml
			echo "${clustname}-0:${HTTP_PORT[$i]}:${AJP_PORT[$i]};${REDIRECT_PORT};${SHUTDOWN_PORT[$i]}"
		done
	fi
}


mkdirs(){
for host in $NODES; do

   if [ $(lxc list $host | grep -c ) -gt 0 ]; then
      lxc delete $host --force ;
   fi
done
  for dir in scripts ssh apps conf; do mkdir -p $ARTIFACT_BASE/$dir; done
}

launchContainers(){

for host in $NODES; do
    if [ $(lxc list | grep ${host} -c ) -gt 0 ]; then
        echo "$host is already launched. Skipping .."
    else
      lxc launch images:centos/$CENTOS_VERSION/amd64 $host
    fi
done
export TOMCAT_BASE="/opt"
sleep 5

}

installUpdates(){

	for hosts in $NODES
	do
		lxc exec $hosts -- yum update -y
		lxc exec $hosts -- yum install -y java-1.8.0-openjdk  java-1.8.0-openjdk-devel openssh-server wget curl epel-release less which unzip zip httpd lsof glibc glibc-devel
	done

}

getTomcat(){
	if [ ! -e $ARTIFACT_BASE/apps/apache-tomcat-${VERSION}.zip ]; then
	  wget  http://www-us.apache.org/dist/tomcat/tomcat-${BASE_VERSION}/v${VERSION}/bin/apache-tomcat-${VERSION}.zip -O $ARTIFACT_BASE/apps/apache-tomcat-${VERSION}.zip
	fi
	if [ ! -e $ARTIFACT_BASE/apps/mod_jk.so ]; then
		wget https://archive.apache.org/dist/tomcat/tomcat-connectors/jk/binaries/win32/jk-1.2.23/mod_jk-apache-2.2.4.so -O $ARTIFACT_BASE/apps/mod_jk.so
	fi
	sleep 2

	for host in $NODES; do
		lxc file push $ARTIFACT_BASE/apps/apache-tomcat-${VERSION}.zip ${host}/tmp/apache-tomcat-${VERSION}.zip
		lxc file push $ARTIFACT_BASE/apps/mod_jk.so ${host}/etc/httpd/modules/
		lxc exec ${host} -- chmod 755 /etc/httpd/modules/mod_jk.so
		lxc exec ${host} -- unzip -qq -o $ARTIFACT_BASE/apache-tomcat-${VERSION}.zip -d /opt/
		
		if [ $scaletype = "V" ]; then
			lxc exec ${host} -- bash -c "rm -rf /opt/tomcat*"
			lxc exec ${host} -- mv /opt/apache-tomcat-${VERSION} /opt/tomcat-0
			lxc exec ${host} -- chown -R tomcat:tomcat /opt/tomcat-0
			lxc exec ${host} -- bash -c "chmod u+x /opt/tomcat-0/bin/*.sh"
		else
			lxc exec ${host} -- mv /opt/apache-tomcat-${VERSION} /opt/tomcat
			lxc exec ${host} -- chown -R tomcat:tomcat /opt/tomcat
			lxc exec ${host} -- bash -c "chmod u+x /opt/tomcat/bin/*.sh"
		fi
	done
}

createScripts(){

cat > $ARTIFACT_BASE/scripts/setup-user.sh << EOF
export JAVA_HOME="/usr/lib/jvm/java-1.8.0"
export PATH="\$PATH:\$JAVA_HOME/bin"
useradd -m -s /bin/bash -G wheel ${tcat_user}
echo "${tcat_user}:${tcat_passwd}" | /usr/sbin/chpasswd
su - ${tcat_user} -c "ssh-keygen -q -t rsa -f /home/${tcat_user}/.ssh/id_rsa -N ''" 
su -c "cat /home/${tcat_user}/.ssh/id_rsa.pub >> /home/${tcat_user}/.ssh/authorized_keys"
chown -R ${tcat_user}:${tcat_group} /home/${tcat_user}
EOF

echo "127.0.0.1 localhost" > $ARTIFACT_BASE/scripts/hosts
> $ARTIFACT_BASE/scripts/ssh.sh
for host in $NODES; do
        IP=$(lxc list ${host}| grep RUNNING | awk '{print $6}')
        echo "$IP   $host" >> $ARTIFACT_BASE/scripts/hosts
    echo "su - ${tcat_user} -c \"ssh -o 'StrictHostKeyChecking no' ${host} 'echo 1 > /dev/null'\"" >> $ARTIFACT_BASE/scripts/ssh.sh
done

cat > $ARTIFACT_BASE/scripts/set_env.sh << EOF
# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=


export JAVA_HOME=/usr/lib/jvm/java-1.8.0
export PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
EOF


cat > $ARTIFACT_BASE/scripts/source.sh << EOF
#!/bin/bash
export JAVA_HOME=/usr/lib/jvm/java-1.8.0
export PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin

cat /root/set_env.sh > /home/${tcat_user}/.bashrc
chown -R ${tcat_user}:${tcat_group} /home/${tcat_user}/
#su - ${tcat_user} -c "source /home/${tcat_user}/.bashrc"
EOF

}

setupUsers(){
	for host in $NODES; do
		lxc exec ${host} -- bash /root/setup-user.sh
		lxc exec ${host} -- service start sshd
	done
}

buildWorkers(){

  if [ $scaletype = "V" ]; then
	(for ((i=0; i < $scalefact ; i++)); 
	do
		echo worker.list=loadbalancer,status  
		echo worker.server${i}.port=${AJP_PORT[$i]}  
		echo  worker.server${i}.host=localhost  
		echo worker.server${i}.type=ajp13
		echo  worker.server${i}.ping_mode=A
		
	done) > $ARTIFACT_BASE/conf/workers.properties 
	
	workers="server0"
	for ((i=1; i < $scalefact; i++ ));
	do
		workers="$workers,server${i}"
	done
  else
    
	(for host in $NODES; do
		echo worker.list=loadbalancer,status  
		echo worker.${host}.port=8009  
		echo  worker.${host}.host=${host}
		echo worker.${host}.type=ajp13
		echo  worker.${host}.ping_mode=A
	done ) > $ARTIFACT_BASE/conf/workers.properties
	
	workers="${prefix}-${clustname}-0"
	for host in $NODES; do
	
		workers="$workers,${host}"
	done
  fi

cat >> $ARTIFACT_BASE/conf/workers.properties <<EOF
# Load-balancing behavior
worker.loadbalancer.type=lb
worker.loadbalancer.balance_workers=$workers
worker.loadbalancer.sticky_session=1

# Status worker for managing load balancer
worker.status.type=status
EOF

}

pushConfig(){

	if [ $scaletype = "V" ]; then
		lxc file push $ARTIFACT_BASE/conf/workers.properties ${NODES}/etc/httpd/conf.d/workers.properties
		lxc file push $ARTIFACT_BASE/conf/mod_jk.conf ${NODES}/etc/httpd/conf.d/mod_jk.conf
		for host in $NODES; do
			for ((i=1; i< $scalefact; i++ )); do
			   lxc exec ${host} -- cp -pR /opt/tomcat-0 /opt/tomcat-${i}
			   lxc file push ${CONF_DIR}/server-${i}.xml ${host}/opt/tomcat-${i}/conf/server.xml
			   lxc file push $ARTIFACT_BASE/scripts/set_env.sh ${host}/root/set_env.sh
			   lxc file push $ARTIFACT_BASE/scripts/source.sh  ${host}/root/source.sh
			   lxc exec ${host} -- chmod +x /root/source.sh
			   lxc exec ${host} -- /root/source.sh
			   lxc exec ${host} -- chown ${tcat_user}:${tcat_group} /opt/tomcat-${i}/conf/server.xml
			done
		done
#	else
#		for host in $NODES; do
#			lxc exec ${host} -- cp -pR /opt/tomcat-0 /opt/tomcat
#			lxc push ${CONF_DIR}/server.xml ${host}/opt/tomcat/conf/server.xml
#		done
	fi
}

pushScripts(){
	for host in $NODES; do
		lxc file push $ARTIFACT_BASE/scripts/setup-user.sh ${host}/root/setup-user.sh
		lxc exec ${host} -- chmod +x /root/setup-user.sh
	done
}

startWebServer()
{
   if [ $scaletype = "V" ]; then
	lxc exec $NODES -- service httpd restart
   else
	lxc exec ${prefix}-${clustname}-0 -- service httpd restart
   fi
}

startTomcat(){
	if [ $scaletype = "V" ]; then
		for ((i=0; i < $scalefact; i++)); do
			lxc exec $NODES -- su -l tomcat bash -c "/opt/tomcat-${i}/bin/shutdown.sh"
			lxc exec $NODES -- su -l tomcat bash -c "/opt/tomcat-${i}/bin/startup.sh"
		done
	else
	for host in $NODES; do
		lxc exec ${host} -- su -l tomcat bash -c "/opt/tomcat/bin/shutdown.sh"
		lxc exec ${host} -- su -l tomcat bash -c "/opt/tomcat/bin/startup.sh"
	done
	fi
}

mkdirs
query
if [ $scaletype = "V" ]; then
	generateServerXML
fi
launchContainers
installUpdates
createScripts
pushScripts
setupUsers
getTomcat
buildWorkers
pushConfig
startTomcat
startWebServer

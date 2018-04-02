export JAVA_HOME="/usr/lib/jvm/java-1.8.0"
export PATH="$PATH:$JAVA_HOME/bin"
useradd -m -s /bin/bash -G wheel tomcat
echo "tomcat:tomcat" | /usr/sbin/chpasswd
su - tomcat -c "ssh-keygen -q -t rsa -f /home/tomcat/.ssh/id_rsa -N ''" 
su -c "cat /home/tomcat/.ssh/id_rsa.pub >> /home/tomcat/.ssh/authorized_keys"
chown -R tomcat:tomcat /home/tomcat

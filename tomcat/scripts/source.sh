#!/bin/bash
export JAVA_HOME=/usr/lib/jvm/java-1.8.0
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/sbin:$HADOOP_HOME/bin

cat /root/set_env.sh > /home/tomcat/.bashrc
chown -R tomcat:tomcat /home/tomcat/
#su - tomcat -c "source /home/tomcat/.bashrc"

# Tomcat Cluster Deployer
deploy-tomcat-cluster.sh - Run this to create a [V]ertical or [H]orizonal Cluster. You will prompted for cluster type and cluster size.

#### Directories
* conf/ - Contains sample mod_jk.conf and server-template.xml that was used in testing the script. You can modify or create own
* apps/ - Contains a compiled mod_jk.so. This was compiled on CentOS 6 with Apache HTTP version 2.2.15. You may need to compile yours.  Download source from https://tomcat.apache.org/download-connectors.cgi. You will need glibc and glibc-devel to compile. 

## INSTRUCTIONS
Default Variables

- CENTOS_VERSION="6"  - CentOS 6 is used by default
- VERSION=8.5.29      - Version of Tomcat used
- BASE_VERSION=8      - Base Version of Tomcat, in this case Tomcat 8
- ARTIFACT_BASE=""    - Set this to specify alternate locations for the above listed directories and others that the script will generate

Default Values
- Prefix:[tcat]                               - This is the prefix for container name. The default is tcat. 
-	Scaling Factor:[2]                          - This is the size of the cluster. Default is 2
-	Scaling Type [H]orizontal;[V]ertical:[V]    - This is the type of the cluster.
-	Starting HTTP Port:[8080]                   - This is the Base (first) Tomcat HTTP Port number. It will be incremented by 1 for others.
-	Starting AJP Port:[8009]                    - This is the Base (first) Tomcat AJP Port number. It will be incremented by 1 for others.
-	Starting SHUTDOWN Port:[8005]               - This is the Base (first) Tomcat SHUTDOWN Port number. It will be incremented by 1 for others.
-	Starting Redirect Port:[8443]               - This is the Base (first) Tomcat RedirectPort number. It will be incremented by 1 for others.
-	Tomcat User:[tomcat]                        - This is the user you want to run Tomcat as. The default is tomcat
-	Tomcat Group:[tomcat]                       - This is the group you want to run Tomcat as. The default is tomcat

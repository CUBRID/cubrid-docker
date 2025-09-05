FROM centos:7

# Create user and group
RUN groupadd -r -g 1000 cubrid && \
    useradd -r -u 1000 -g cubrid -d /home/cubrid -m cubrid && \
    chmod 777 -R /tmp

# Set environment variables
ENV GOSU_VERSION="1.13" \
    CUBRID_VERSION="11.4-latest" \
    VERSION_PATH="11.4_latest" \
    CUBRID_USER_PATH="/home/cubrid" \
    CUBRID="/home/cubrid/CUBRID" \
    CUBRID_DATABASES="/var/lib/cubrid" \
    CUBRID_DB="cubdb" \
    CUBRID_VOLUME_SIZE="100M" \
    CUBRID_LOCALE="en_US" \
    CUBRID_COMPONENTS="ALL" \
    PATH="/home/cubrid/CUBRID/bin:$PATH" \
    LD_LIBRARY_PATH="/home/cubrid/CUBRID/lib" \
    # for k8s environment
    K8S_CUBRID_DATABASES="/home/cubrid/CUBRID/databases" \
    CUBRID_BACKUPDB="/home/cubrid/CUBRID/backupdb"

# Setup repositories and install base packages
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* && \
    yum -y update && \
    yum -y install epel-release && \
    yum -y install wget unzip zip htop lsof tzdata \
    net-tools iproute telnet bind-utils nmap traceroute socat tcpdump \
    httpie rsync openssh-clients openssh less nc && \ 
    yum clean all

# Install gosu
RUN wget -O /usr/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" && \
    chmod +x /usr/bin/gosu && \
    gosu nobody true

# Configure system settings for CUBRID
RUN echo "# CUBRID System Configuration" >> /etc/sysctl.conf && \
    # Remove existing settings if they exist and add new ones
    sed -i '/^vm\.swappiness=/d' /etc/sysctl.conf && \
    sed -i '/^net\.ipv4\.tcp_tw_reuse=/d' /etc/sysctl.conf && \
    sed -i '/^net\.core\.rmem_max=/d' /etc/sysctl.conf && \
    sed -i '/^net\.core\.rmem_default=/d' /etc/sysctl.conf && \
    sed -i '/^net\.core\.wmem_max=/d' /etc/sysctl.conf && \
    sed -i '/^net\.core\.wmem_default=/d' /etc/sysctl.conf && \
    sed -i '/^net\.ipv4\.tcp_rmem=/d' /etc/sysctl.conf && \
    sed -i '/^net\.ipv4\.tcp_wmem=/d' /etc/sysctl.conf && \
    sed -i '/^fs\.file-max/d' /etc/sysctl.conf && \
    sed -i '/^net\.core\.somaxconn/d' /etc/sysctl.conf && \
    sed -i '/^net\.ipv4\.tcp_max_syn_backlog/d' /etc/sysctl.conf && \
    sed -i '/^net\.core\.netdev_max_backlog/d' /etc/sysctl.conf && \
    sed -i '/^net\.ipv4\.tcp_syncookies/d' /etc/sysctl.conf && \
    sed -i '/^vm\.dirty_ratio/d' /etc/sysctl.conf && \
    sed -i '/^vm\.dirty_background_ratio/d' /etc/sysctl.conf && \
    sed -i '/^net\.ipv4\.tcp_fin_timeout/d' /etc/sysctl.conf && \
    sed -i '/^kernel\.shmmax/d' /etc/sysctl.conf && \
    sed -i '/^kernel\.shmall/d' /etc/sysctl.conf && \
    # Add new optimized settings
    echo "vm.swappiness=1" >> /etc/sysctl.conf && \
    echo "net.ipv4.tcp_tw_reuse=1" >> /etc/sysctl.conf && \
    echo "net.core.rmem_max=41943040" >> /etc/sysctl.conf && \
    echo "net.core.rmem_default=10485760" >> /etc/sysctl.conf && \
    echo "net.core.wmem_max=41943040" >> /etc/sysctl.conf && \
    echo "net.core.wmem_default=10485760" >> /etc/sysctl.conf && \
    echo "net.ipv4.tcp_rmem=4096 524288 41943040" >> /etc/sysctl.conf && \
    echo "net.ipv4.tcp_wmem=4096 524288 41943040" >> /etc/sysctl.conf && \
    echo "fs.file-max = 6815744" >> /etc/sysctl.conf && \
    echo "net.core.somaxconn = 4096" >> /etc/sysctl.conf && \
    echo "net.ipv4.tcp_max_syn_backlog = 4096" >> /etc/sysctl.conf && \
    echo "net.core.netdev_max_backlog = 2500" >> /etc/sysctl.conf && \
    echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf && \
    echo "vm.dirty_ratio = 10" >> /etc/sysctl.conf && \
    echo "vm.dirty_background_ratio = 5" >> /etc/sysctl.conf && \
    echo "net.ipv4.tcp_fin_timeout = 15" >> /etc/sysctl.conf && \
    echo "kernel.shmmax = 68719476736" >> /etc/sysctl.conf && \
    echo "kernel.shmall = 4294967296" >> /etc/sysctl.conf

# Download and setup CUBRID
RUN wget -O cubrid.tar.gz "http://ftp.cubrid.org/CUBRID_Engine/${VERSION_PATH}/CUBRID-${CUBRID_VERSION}-Linux.x86_64.tar.gz" && \
    tar -xzf cubrid.tar.gz -C /home/cubrid && \
    rm cubrid.tar.gz && \
    mkdir -p ${CUBRID_DATABASES} && \
    chown -R cubrid:cubrid ${CUBRID} ${CUBRID_DATABASES} && \
    # for k8s environment
    mkdir -p ${K8S_CUBRID_DATABASES} ${CUBRID_BACKUPDB} && \
    chown -R cubrid:cubrid ${K8S_CUBRID_DATABASES} ${CUBRID_BACKUPDB} && \
    chmod -R 755 /home/cubrid/CUBRID && \
    yum clean all && \
    rm -rf /var/cache/yum/* /tmp/* /var/tmp/*

# Copy scripts and set permissions
COPY operator_conf.sh backupdb.sh ${CUBRID}/share/scripts/
COPY cubrid.sh /tmp/.cubrid.sh
COPY docker-entrypoint.sh /tmp/docker-entrypoint.sh

RUN mkdir -p ${CUBRID}/share/scripts && \
    mv /tmp/.cubrid.sh ${CUBRID_USER_PATH}/.cubrid.sh && \
    mv /tmp/docker-entrypoint.sh ${CUBRID_USER_PATH}/entrypoint.sh && \
    chmod 755 ${CUBRID_USER_PATH}/.cubrid.sh && \
    chmod 755 ${CUBRID}/share/scripts/operator_conf.sh && \
    chmod 755 ${CUBRID}/share/scripts/backupdb.sh && \
    chmod +x ${CUBRID_USER_PATH}/entrypoint.sh && \
    chown -R cubrid:cubrid ${CUBRID}/share/scripts && \
    chown cubrid:cubrid ${CUBRID_USER_PATH}/.cubrid.sh && \
    chown cubrid:cubrid ${CUBRID_USER_PATH}/entrypoint.sh && \
    echo '#----------------------------------------------------------------' >> ${CUBRID_USER_PATH}/.bash_profile && \
    echo '# set CUBRID environment variables' >> ${CUBRID_USER_PATH}/.bash_profile && \
    echo '#----------------------------------------------------------------' >> ${CUBRID_USER_PATH}/.bash_profile && \
    echo 'if [ -f /home/cubrid/.cubrid.sh ];then' >> ${CUBRID_USER_PATH}/.bash_profile && \
    echo '. /home/cubrid/.cubrid.sh' >> ${CUBRID_USER_PATH}/.bash_profile && \
    echo 'fi' >> ${CUBRID_USER_PATH}/.bash_profile && \
    chown cubrid:cubrid ${CUBRID_USER_PATH}/.bash_profile

VOLUME $CUBRID_DATABASES

ENTRYPOINT ["/home/cubrid/entrypoint.sh"]

EXPOSE 33000

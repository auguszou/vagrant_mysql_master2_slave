#variables for master
export master_ip="192.168.2.20"
export master_ssh_login_user="ubuntu"
export master_ssh_login_passwd="vagrant"

export master_mysql_root_passwd="123"
export replication_user="copydb"
export replication_passwd="123"
export replication_db="test"

#variables for slave
export slave_ip=`ifconfig enp0s8| grep "inet addr" | awk '{ print $2}' | awk -F: '{print $2}'`
export slave_server_id=${slave_ip##*.}
export slave_mysql_root_passwd="123"
export slave_ssh_login_user="ubuntu"
export slave_ssh_login_passwd="vagrant"

cmd_ssh="sshpass -p ${master_ssh_login_passwd} ssh -o StrictHostKeyChecking=no -o CheckHostIP=no -o UserKnownHostsFile=/dev/null ${master_ssh_login_user}@${master_ip}"
cmd_status="mysql -uroot -p${master_mysql_root_passwd} -e 'show master status\G'"
export binlogname=`${cmd_ssh} ${cmd_status} | grep "File" | awk '{print $2}'`
export position=`${cmd_ssh} ${cmd_status} | grep "Position" | awk '{print $2}'`

mysql -uroot -p${slave_mysql_root_passwd} -e "drop database if exists ${replication_db};create database ${replication_db};"
mysql -uroot -p${slave_mysql_root_passwd} ${replication_db} < /vagrant/${replication_db}.sql

cat >> /etc/mysql/mysql.conf.d/mysqld.cnf <<EOF
server-id=${slave_server_id}
replicate-do-db=test
replicate-ignore-db=mysql
replicate-ignore-db=information_schema
relay-log=mysqld-relay-bin
log-slave-updates
slave-skip-errors=all
slave-net-timeout=60

log-bin=mysql-bin
slow_query_log=1
EOF

/etc/init.d/mysql restart

mysql -uroot -p${slave_mysql_root_passwd} <<EOF
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST="${master_ip}",
MASTER_PORT=3306,
MASTER_USER="${replication_user}",
MASTER_PASSWORD="${replication_passwd}",
MASTER_LOG_FILE="${binlogname}",
MASTER_LOG_POS=${position},
MASTER_CONNECT_RETRY=10;
START SLAVE;
EOF

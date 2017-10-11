cat >> /etc/mysql/mysql.conf.d/mysqld.cnf <<EOF
server-id=2
binlog-do-db=test
binlog-ignore-db=information_schema
binlog-ignore-db=mysql

slow_query_log=1
sync_binlog=1
log-bin=mysql-bin
EOF

#variables for master1
export master1_ip="192.168.2.10"
export master1_ssh_login_user="ubuntu"
export master1_ssh_login_passwd="vagrant"
export master1_mysql_root_passwd="123"

#variables for master2
export master2_ip="192.168.2.20"
export master2_mysql_root_passwd="123"

export replication_user="copydb"
export replication_passwd="123"
export replication_db="test"

mysql -uroot -p${master2_mysql_root_passwd} -e "drop database if exists ${replication_db};create database ${replication_db};"

{
mysql -uroot -p${master2_mysql_root_passwd} <<EOF
CREATE USER '$replication_user'@'%' IDENTIFIED BY '$replication_passwd';
GRANT REPLICATION SLAVE ON *.* TO '$replication_user'@'%' IDENTIFIED BY '$replication_passwd';
FLUSH PRIVILEGES;
FLUSH TABLES WITH READ LOCK;
SELECT SLEEP(10);
EOF
} &

#export the database sql data.
mysqldump -uroot -p${master2_mysql_root_passwd} ${replication_db} > /vagrant/master2_${replication_db}.sql

# import the database from master1
mysql -uroot -p${master1_mysql_root_passwd} ${replication_db} < /vagrant/master1_${replication_db}.sql

# set master2 as slave of master1
export cmd_ssh="sshpass -p ${master1_ssh_login_passwd} ssh -o StrictHostKeyChecking=no -o CheckHostIP=no -o UserKnownHostsFile=/dev/null ${master1_ssh_login_user}@${master1_ip}"
cmd_status="mysql -uroot -p${master1_mysql_root_passwd} -e 'show master status\G'"
export binlogname=`${cmd_ssh} ${cmd_status} | grep "File" | awk '{print $2}'`
export position=`${cmd_ssh} ${cmd_status} | grep "Position" | awk '{print $2}'`

cat >> /etc/mysql/mysql.conf.d/mysqld.cnf <<EOF
server-id=2
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

mysql -uroot -p${master2_mysql_root_passwd} <<EOF
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST="${master1_ip}",
MASTER_PORT=3306,
MASTER_USER="${replication_user}",
MASTER_PASSWORD="${replication_passwd}",
MASTER_LOG_FILE="${binlogname}",
MASTER_LOG_POS=${position},
MASTER_CONNECT_RETRY=10;
START SLAVE;
EOF

# set master1 as slave of master2
mysql_status="mysql -uroot -p${master2_mysql_root_passwd} -e 'show master status\G'"
export binlogname=`${mysql_status} | grep "File" | awk '{print $2}'`
export position=`${mysql_status} | grep "Position" | awk '{print $2}'`

`${cmd_ssh} sudo /etc/init.d/mysql restart`

mysql -uroot -p${master1_mysql_root_passwd} -h${master1_ip} <<EOF
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST="${master2_ip}",
MASTER_PORT=3306,
MASTER_USER="${replication_user}",
MASTER_PASSWORD="${replication_passwd}",
MASTER_LOG_FILE="${binlogname}",
MASTER_LOG_POS=${position},
MASTER_CONNECT_RETRY=10;
START SLAVE;
EOF

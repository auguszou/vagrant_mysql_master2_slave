echo "root:vagrant" | chpasswd

cat >> /etc/mysql/mysql.conf.d/mysqld.cnf <<EOF
server-id=1
binlog-do-db=test
binlog-ignore-db=information_schema
binlog-ignore-db=mysql

slow_query_log=1
sync_binlog=1
log-bin=mysql-bin

replicate-do-db=test
replicate-ignore-db=mysql
replicate-ignore-db=information_schema
relay-log=mysqld-relay-bin
log-slave-updates
slave-skip-errors=all
slave-net-timeout=60
EOF

#variables for master1
export master1_ip="192.168.2.10"
export master1_mysql_root_passwd="123"

export replication_user="copydb"
export replication_passwd="123"
export replication_db="test"

mysql -uroot -p${master1_mysql_root_passwd} -e "drop database if exists ${replication_db};create database ${replication_db};"

{
mysql -uroot -p${master1_mysql_root_passwd} <<EOF
CREATE USER '$replication_user'@'%' IDENTIFIED BY '$replication_passwd';
GRANT REPLICATION SLAVE ON *.* TO '$replication_user'@'%' IDENTIFIED BY '$replication_passwd';
FLUSH PRIVILEGES;

USE mysql;
UPDATE user SET host='%' WHERE user="root" AND host='localhost';

FLUSH TABLES WITH READ LOCK;
SELECT SLEEP(10);
EOF
} &

#export the database sql data.
mysqldump -uroot -p${master1_mysql_root_passwd} ${replication_db} > /vagrant/master1_${replication_db}.sql

/etc/init.d/mysql restart

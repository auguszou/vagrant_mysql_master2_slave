mysql 双主互备
=========================

### test
1. vagrant up
2. login master1, 执行sql
```sql
use test;
create table Person(id integer auto-increment, name varchar(256), primary key(id));
insert into Person(name) values("jack“),("tom");
```
3. login master2, 执行sql
```sql
use test;
show tables;
select * from Person;
insert into Person(name) values("lily“),("alice");
```
4. login master1, 执行sql
```sql
use test;
show tables;
select * from Person;
```

steps
=========================

### master1
0. login master1 server
1. 修改mysqld.conf, 添加如下内容
```
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
```

2. restart mysql, `sudo /etc/init.d/mysql restart`

3. 常见用来复制数据的用户
```sql
CREATE USER '$replication_user'@'%' IDENTIFIED BY '$replication_passwd';
GRANT REPLICATION SLAVE ON *.* TO '$replication_user'@'%' IDENTIFIED BY '$replication_passwd';
FLUSH PRIVILEGES;

USE mysql;
UPDATE user SET host='%' WHERE user="root" AND host='localhost';

drop database if exists ${replication_db};create database ${replication_db};

FLUSH TABLES WITH READ LOCK;
SELECT SLEEP(10);
```

4. mysqldump导出当前的数据库
```sql
mysqldump -uroot -p${master1_mysql_root_passwd} ${replication_db} > /vagrant/master1_${replication_db}.sql
```

5. 获得当前的binlogname(设为$binlogname1)和position(设为$position1)
```sql
mysql -uroot -p${master1_mysql_root_passwd} -e 'show master status\G'
```

### master2
0. login master2 server
1. 修改mysqld.conf, 添加如下内容
```
server-id=2
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
```

2. 设置master2作为master1的从服务器
```sql
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST="${master1_ip}",
MASTER_PORT=3306,
MASTER_USER="${replication_user}",
MASTER_PASSWORD="${replication_passwd}",
MASTER_LOG_FILE="${binlogname1}",
MASTER_LOG_POS=${position2},
MASTER_CONNECT_RETRY=10;
START SLAVE;
```

3. 导入master1的数据
```sql
mysql -uroot -p${master2_mysql_root_passwd} ${replication_db} < /vagrant/master1_${replication_db}.sql
```

4. 获得master2当前的binlogname(设为$binlogname2)和position(设为$position2)
```sql
mysql -uroot -p${master2_mysql_root_passwd} -e 'show master status\G'
```

5. restart mysql, `sudo /etc/init.d/mysql restart`

6. login master1 server, 设置master1作为master2的从服务器
```sql
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST="${master2_ip}",
MASTER_PORT=3306,
MASTER_USER="${replication_user}",
MASTER_PASSWORD="${replication_passwd}",
MASTER_LOG_FILE="${binlogname2}",
MASTER_LOG_POS=${position2},
MASTER_CONNECT_RETRY=10;
START SLAVE;
```

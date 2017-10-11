debconf-set-selections <<< 'mysql-server-5.7 mysql-server/root_password password 123'
debconf-set-selections <<< 'mysql-server-5.7 mysql-server/root_password_again password 123'
apt-get install -yy mysql-server-5.7

sed -i 's/^bind-address.*$/bind-address = 0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf

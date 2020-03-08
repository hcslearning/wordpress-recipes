# variables
CANT_INSTALL=3
WP_INSTALL_BASE=/var/www/wp


# instalar software necesario
sudo yum install firewalld
sudo yum install nginx
sudo yum install mariadb mariadb-server
sudo yum install wget curl
sudo yum install php php-fpm
sudo yum install php-mysqlnd php-gd php-xml php-xmlrpc php-mbstring php-snmp php-soap
sudo yum install ImageMagick ImageMagick-devel


# iniciar servicios
sudo systemctl start nginx
sudo systemctl start mariadb
sudo systemctl start php-fpm


# activar servicios para que partan sobre cada inicio
sudo systemctl enable nginx
sudo systemctl enable php-fpm
sudo systemctl enable mariadb


# configuración para conectar sin tener que escribir la password de MySQL
MYSQL_PASSWD_CONFIG=~/.my.cnf
cat /dev/null > $MYSQL_PASSWD_CONFIG
echo "[mysql]" >> $MYSQL_PASSWD_CONFIG
echo "user=root" >> $MYSQL_PASSWD_CONFIG
# crear archivo que contenga la pass
MYSQL_PASSWD=`cat ~/.mysqlpass`
echo "password=$MYSQL_PASSWD" >> $MYSQL_PASSWD_CONFIG
chmod 0600 $MYSQL_PASSWD_CONFIG

# descargar wordpress
cd
wget https://es.wordpress.org/latest-es_ES.tar.gz


# crear carpetas
for i in $(seq 1 $CANT_INSTALL)
do
    dir=$WP_INSTALL_BASE/s$i
    sudo mkdir -p $dir
    sudo chown vultr:apache -R $dir
    sudo chmod g+rwx -R $dir
    tar -C $dir -xvf $HOME/latest-es_ES.tar.gz
    
    # crear base de datos
    BD_NAME="s$i"
    echo "drop database if exists $BD_NAME; create database $BD_NAME;" | mysql -u root
done


# configurar firewall
sudo firewall-cmd --state
sudo firewall-cmd --get-default-zone
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-services
sudo firewall-cmd --zone=public --permanent --add-service=http
sudo firewall-cmd --zone=public --permanent --add-service=https
sudo systemctl restart firewalld
sudo firewall-cmd --zone=public --list-services
   

# permisos de directorios
cd ${wpinstall}/wp-content 
sudo chown vultr:apache -R plugins themes uploads languages upgrade
sudo chmod g+rwx -R plugins themes uploads languages upgrade

# configurar selinux
sudo sestatus 
sudo setsebool -P httpd_can_network_connect on
sudo semanage fcontext -l
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www(/.*)*/uploads(/.*)?"
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www(/.*)*/wp-content(/.*)?"
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www(/.*)*/wp_backups(/.*)?"
sudo restorecon -RFvv /var/www



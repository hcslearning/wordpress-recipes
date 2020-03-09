# variables
CANT_INSTALL=3
WP_URL="https://es.wordpress.org/latest-es_ES.tar.gz"
WP_TAR="latest-es_ES.tar.gz"
WP_CLI_URL="https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
WP_INSTALL_BASE=/var/www/wp
WP_USER_PREFIX=`cat ~/.wpuser`
WP_PASSWD=`cat ~/.wppass`
MAIN_DOMAIN=`cat ~/.wpmaindomain`
MYSQL_USER=root
MYSQL_PASSWD=`cat ~/.mysqlpass`
MYSQL_PASSWD_CONFIG=~/.my.cnf


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
cat /dev/null > $MYSQL_PASSWD_CONFIG
echo "[mysql]" >> $MYSQL_PASSWD_CONFIG
echo "user=$MYSQL_USER" >> $MYSQL_PASSWD_CONFIG
echo "password=$MYSQL_PASSWD" >> $MYSQL_PASSWD_CONFIG
chmod 0600 $MYSQL_PASSWD_CONFIG

# descargar wordpress
cd
wget $WP_URL


# Instalo wp-cli para poder instalar de manera headless
curl -O $WP_CLI_URL

# crear sitios
for i in $(seq 1 $CANT_INSTALL)
do
    dir=$WP_INSTALL_BASE/s$i
    domain=s$i.$MAIN_DOMAIN
    
    sudo mkdir -p $dir    
    sudo chown vultr:apache -R $dir
    sudo chmod g+rwx -R $dir
    tar -C $dir -xvf $HOME/$WP_TAR
    
    # crear base de datos
    BD_NAME="s$i"
    echo "drop database if exists $BD_NAME; create database $BD_NAME;" | mysql -u root
    
    # instalacion headless con wp-cli
    wp core config --dbhost=localhost --dbname=$BD_NAME --dbuser=$MYSQL_USER --dbpass=$MYSQL_PASSWD --extra-php="define('FS_METHOD', true);"
    wp core install --url=$domain --title="Sitio $i" --admin_name="$WP_USER_PREFIX$i" --admin_password="$WP_PASSWD" --admin_email="wp-s$i@$MAIN_DOMAIN"

    # sobrescribo configuración para descarga directar de plugins y themes
    #ex -s -c '20i|define("FS_METHOD", "direct");' -c x wp-config.php

    # permisos post instalación    
    cd $dir/wordpress/wp-content 
    sudo chown vultr:apache -R plugins themes uploads languages upgrade
    sudo chmod g+rwx -R plugins themes uploads languages upgrade
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
   

# configurar selinux
sudo sestatus 
sudo setsebool -P httpd_can_network_connect on
sudo semanage fcontext -l
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www(/.*)*/uploads(/.*)?"
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www(/.*)*/wp-content(/.*)?"
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www(/.*)*/wp_backups(/.*)?"
sudo restorecon -RFvv /var/www

# mostrar errores
sudo cat /var/log/php-fpm/www-error.log

#!/usr/bin/env bash

set -o errexit
set -o nounset

##################
# Setup          #
##################

MYSQL_ROOT_PASSWORD_SET=${MYSQL_ROOT_PASSWORD:-}

if [ -z "${MYSQL_ROOT_PASSWORD_SET}" ]; then
    echo "Please set the MySQL root password:"
    echo "    docker run -e MYSQL_ROOT_PASSWORD=<mysecret> ... kuralabs/docker-drupal:latest ..."
    echo "See README.rst for more information on usage."
    exit 1
fi

DRUPAL_APP_SET=${DRUPAL_APP:-}

if [ -z "${DRUPAL_APP}" ]; then
    echo "Please set Drupal application name:"
    echo "    docker run -e DRUPAL_APP=<myapp> ... kuralabs/docker-drupal:latest ..."
    echo "See README.rst for more information on usage."
    exit 1
fi

# Logging
for i in mysql,mysql nginx,root supervisor,root; do

    IFS=',' read directory owner <<< "${i}"

    if [ ! -d "/var/log/${directory}" ]; then
        echo "Setting up /var/log/${directory} ..."
        mkdir -p "/var/log/${directory}"
        chown "${owner}:adm" "/var/log/${directory}"
    else
        echo "Directory /var/log/${directory} already setup ..."
    fi
done

##################
# Waits          #
##################

function wait_for_mysql {

    echo -n "Waiting for MySQL "
    for i in {10..0}; do
        if mysqladmin ping > /dev/null 2>&1; then
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""

    if [ "$i" == 0 ]; then
        echo >&2 "FATAL: MySQL failed to start"
        echo "Showing content of /var/log/mysql/error.log ..."
        cat /var/log/mysql/error.log || true
        exit 1
    fi
}

function wait_for_php_fpm {

    echo -n "Waiting for php-fpm "
    for i in {10..0}; do
        if [ -S "/run/php/php7.0-fpm.sock" ]; then
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""

    if [ "$i" == 0 ]; then
        echo >&2 "FATAL: php-fpm failed to start"
        echo "Showing content of /var/log/supervisor/php-fpm.log ..."
        cat /var/log/supervisor/php-fpm.log || true
        exit 1
    fi
}

# Copy configuration files if new mount
if find /var/www/drupal/sites/default -mindepth 1 | read; then
    echo "Site is mounted. Skipping copy ..."
else
    echo "Site is empty. Copying base files ..."
    cp -R /var/www/drupal/sites/.default/* /var/www/drupal/sites/default
    chown -R www-data:www-data /var/www/drupal/sites/default
    chmod u+w /var/www/drupal/sites/default

    cat > /var/www/drupal/sites/default/composer.json <<DELIM
{
    "name": "${DRUPAL_APP}",
    "description": "A Drupal Website",
    "type": "project",
    "license": "GPL-2.0+",
    "repositories": {
        "drupal": {
            "type": "composer",
            "url": "https://packages.drupal.org/8"
        }
    },
    "extra": {
        "installer-paths": {
            "../../core": ["type:drupal-core"],
            "modules/contrib/{\$name}": ["type:drupal-module"],
            "themes/contrib/{\$name}": ["type:drupal-theme"]
        }
    },
    "require": {
        "composer/installers": "^1.5",
        "drupal/ctools": "^3.0"
    }
}
DELIM
    chown www-data:www-data /var/www/drupal/sites/default/composer.json

fi

##################
# Initialization #
##################

# MySQL boot

# Workaround for issue #72 that makes MySQL to fail to
# start when using docker's overlay2 storage driver:
#   https://github.com/docker/for-linux/issues/72
find /var/lib/mysql -type f -exec touch {} \;

# Initialize /var/lib/mysql if empty (first --volume mount)
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Empty /var/lib/mysql/ directory. Initializing MySQL structure ..."

    echo "MySQL user has uid $(id -u mysql). Changing /var/lib/mysql ownership ..."
    chown -R mysql:mysql /var/lib/mysql

    echo "Initializing MySQL ..."
    echo "UPDATE mysql.user
        SET authentication_string = PASSWORD('${MYSQL_DEFAULT_PASSWORD}'), password_expired = 'N'
        WHERE User = 'root' AND Host = 'localhost';
        FLUSH PRIVILEGES;" > /tmp/mysql-init.sql

    /usr/sbin/mysqld \
        --initialize-insecure \
        --init-file=/tmp/mysql-init.sql || cat /var/log/mysql/error.log

    rm /tmp/mysql-init.sql
fi

##################
# Supervisord    #
##################

echo "Starting supervisord ..."
# Note: stdout and stderr are redirected to /dev/null as logs are already being
#       saved in /var/log/supervisor/supervisord.log
supervisord --nodaemon -c /etc/supervisor/supervisord.conf > /dev/null 2>&1 &

# Wait for MySQL to start
wait_for_mysql

# Wait for PHP FPM to start
wait_for_php_fpm

##################
# MySQL          #
##################

# Check if password was changed
echo "\
[client]
user=root
password=${MYSQL_DEFAULT_PASSWORD}
" > ~/.my.cnf

if echo "SELECT 1;" | mysql &> /dev/null; then

    echo "Securing MySQL installation ..."
    mysql_secure_installation --use-default

    echo "Changing root password ..."
    echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
          FLUSH PRIVILEGES;" | mysql
else
    echo "Root password already set. Continue ..."
fi

# Start using secure credentials
echo "\
[client]
user=root
password=${MYSQL_ROOT_PASSWORD}
" > ~/.my.cnf

# Create database
if ! echo "USE ${DRUPAL_APP};" | mysql &> /dev/null; then
    echo "Creating ${DRUPAL_APP} database ..."
    echo "CREATE DATABASE ${DRUPAL_APP};" | mysql
else
    echo "Database already exists. Continue ..."
fi

##################
# Drupal      #
##################

if echo "SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_schema = '${DRUPAL_APP}';" | mysql | grep 0 &> /dev/null; then

    echo "Database is empty, installing Drupal for the first time ..."

    # Create standard user and grant permissions
    MYSQL_USER_PASSWORD=$(openssl rand -base64 32)

    if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${DRUPAL_APP}';" | mysql | grep 1 &> /dev/null; then

        echo "Creating drupal database user ..."

        echo "CREATE USER '${DRUPAL_APP}'@'localhost' IDENTIFIED BY '${MYSQL_USER_PASSWORD}';
              GRANT ALL PRIVILEGES ON ${DRUPAL_APP}.* TO '${DRUPAL_APP}'@'localhost';
              FLUSH PRIVILEGES;" | mysql
    else
        echo "Drupal not installed but user was created. Resetting password ..."

        echo "ALTER USER '${DRUPAL_APP}'@'localhost' IDENTIFIED BY '${MYSQL_USER_PASSWORD}';
              FLUSH PRIVILEGES;" | mysql
    fi

    GREEN='\033[0;32m'
    NO_COLOR='\033[0m'

    echo -e "${GREEN}"
    echo "*****************************************************************"
    echo "IMPORTANT!! GO TO THE WEB INTERFACE TO FINISH INSTALLATION!"
    echo ""
    echo "Use the following parameters in 'Database Setup':"
    echo ""
    echo "Hostname:     127.0.0.1:3306"
    echo "Username:     ${DRUPAL_APP}"
    echo "Database:     ${DRUPAL_APP}"
    echo "Password:     ${MYSQL_USER_PASSWORD}"
    echo ""
    echo "Please securely store these credentials!"
    echo "*****************************************************************"
    echo -e "${NO_COLOR}"
else
    echo "Drupal already installed. Continue ..."
fi

##################
# NGINX          #
##################

# Start service
echo "Starting NGINX ..."
supervisorctl start nginx

##################
# Finish         #
##################

# Display final status
supervisorctl status

# Security clearing
rm ~/.my.cnf

unset MYSQL_DEFAULT_PASSWORD
unset MYSQL_ROOT_PASSWORD
unset MYSQL_USER_PASSWORD

history -c
history -w

if [ -z "$@" ]; then
    echo "Done booting up. Waiting on supervisord pid $(supervisorctl pid) ..."
    wait $(supervisorctl pid)
else
    echo "Running user command : $@"
    exec "$@"
fi

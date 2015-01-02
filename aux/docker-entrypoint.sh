#!/bin/bash
set -e

KOHA_ADMINUSER=kohaadmin
KOHA_ADMINPASS=koha@dev
DB=koha
USER=koha-dev

service mysql start
if [ ! -f /root/lock ]; then
    echo "127.0.0.1 db" >> /etc/hosts
    echo "CREATE USER '$KOHA_ADMINUSER'@'localhost' IDENTIFIED BY '$KOHA_ADMINPASS' ;
CREATE DATABASE IF NOT EXISTS $DB ; \
GRANT ALL ON $DB.* TO '$KOHA_ADMINUSER'@'%' WITH GRANT OPTION ; \
FLUSH PRIVILEGES ;" | mysql -u root
    touch /root/lock

    a2ensite koha
fi

service apache2 start
/etc/init.d/cron start
/etc/init.d/koha-index-daemon-ctl.sh start
/etc/init.d/koha-zebra-ctl.sh start

/usr/bin/tail -f /var/log/apache2/access.log \
              /home/$USER/koha-dev/var/log/koha-error_log \
              /home/$USER/koha-dev/var/log/koha-opac-error_log \
              /home/$USER/koha-dev/var/log/koha-zebradaemon.err \
              /home/$USER/koha-dev/var/log/koha-index-daemon.err \
              /var/log/apache2/other_vhosts_access.log

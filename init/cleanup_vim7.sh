#!/bin/bash
cd /etc/apache2/sites-available
rm letsencrypt1.com.conf

a2dissite letsencrypt1.com.conf
cd /etc/php5/fpm/pool.d/
rm letsencrypt1.conf

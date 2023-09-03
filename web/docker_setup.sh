#!/bin/bash

apt-get install gettext-base
envsubst '$$FLAZA_SERVER_NAME' < /etc/nginx/templates/flaza.conf > /etc/nginx/nginx.conf
nginx -g 'daemon off;'

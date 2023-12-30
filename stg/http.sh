#!/bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y

# Instalar Nginx
sudo apt-get install nginx -y

# Iniciar Nginx y esperar a que se complete la inicialización
sudo service nginx start
while ! nc -z localhost 80; do sleep 1; done

#echo "<h1>HELLO from $(hostname -f)</h1>" > /var/www/html/index.html



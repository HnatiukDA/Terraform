#!/bin/bash
sudo su
apt update -y
apt install nginx-light -y
systemctl start nginx
systemctl enable nginx
echo 'Welcome to Instance' >> /var/www/html/index.html
# sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
# systemctl restart sshd

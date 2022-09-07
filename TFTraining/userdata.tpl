#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras enable epel -y
sudo yum install epel-release -y
sudo yum install nginx -y
sudo service nginx start
echo '<h1>Dyl Webserver</h1>' > /usr/share/nginx/html/index.html
-- MySQL 数据库初始化脚本
CREATE DATABASE IF NOT EXISTS allinone DEFAULT CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS 'allinone_user'@'%' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON allinone.* TO 'allinone_user'@'%';
FLUSH PRIVILEGES;

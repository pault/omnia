# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'user'
#
CREATE TABLE user (
  user_id int(11) DEFAULT '0' NOT NULL,
  nick varchar(20),
  passwd varchar(10),
  realname varchar(40),
  email varchar(40),
  lasttime datetime,
  karma int(11) DEFAULT '0',
  inside_workspace int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (user_id)
);

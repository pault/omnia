# MySQL dump 6.4
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.27-log

#
# Table structure for table 'user'
#
CREATE TABLE user (
  user_id int(11) DEFAULT '0' NOT NULL auto_increment,
  nick varchar(20),
  passwd varchar(10),
  realname varchar(40),
  email varchar(40),
  lasttime datetime,
  karma int(11) DEFAULT '0',
  PRIMARY KEY (user_id)
);

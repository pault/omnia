# MySQL dump 7.1
#
# Host: localhost    Database: Ron
#--------------------------------------------------------
# Server version	3.22.32

#
# Table structure for table 'setting'
#
CREATE TABLE setting (
  setting_id int(11) DEFAULT '0' NOT NULL auto_increment,
  vars text NOT NULL,
  PRIMARY KEY (setting_id)
);

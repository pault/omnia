# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'setting'
#

CREATE TABLE setting (
  setting_id int(11) NOT NULL auto_increment,
  vars text DEFAULT '' NOT NULL,
  PRIMARY KEY (setting_id)
);

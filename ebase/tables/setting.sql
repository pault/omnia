# MySQL dump 6.0
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.25

#
# Table structure for table 'setting'
#
CREATE TABLE setting (
  setting_id int(11) DEFAULT '0' NOT NULL auto_increment,
  vars text NOT NULL,
  PRIMARY KEY (setting_id)
);

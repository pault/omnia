# MySQL dump 7.1
#
# Host: localhost    Database: paco
#--------------------------------------------------------
# Server version	3.22.32

#
# Table structure for table 'themesetting'
#
CREATE TABLE themesetting (
  themesetting_id int(11) DEFAULT '0' NOT NULL,
  parent_theme int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (themesetting_id)
);

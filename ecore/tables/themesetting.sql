# MySQL dump 6.0
#
# Host: localhost    Database: new
#--------------------------------------------------------
# Server version	3.22.25

#
# Table structure for table 'themesetting'
#
CREATE TABLE themesetting (
  themesetting_id int(11) DEFAULT '0' NOT NULL,
  parent_theme int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (themesetting_id)
);

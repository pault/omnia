# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'themesetting'
#

CREATE TABLE themesetting (
  themesetting_id int(11) DEFAULT '0' NOT NULL,
  parent_theme int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (themesetting_id)
);

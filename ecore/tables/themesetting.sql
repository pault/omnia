# MySQL dump 6.4
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.27-log

#
# Table structure for table 'themesetting'
#
CREATE TABLE themesetting (
  themesetting_id int(11) DEFAULT '0' NOT NULL,
  parent_theme int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (themesetting_id)
);

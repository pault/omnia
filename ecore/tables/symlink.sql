# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'symlink'
#

CREATE TABLE symlink (
  symlink_id int(11) DEFAULT '0' NOT NULL,
  symlink_node int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (symlink_id)
);

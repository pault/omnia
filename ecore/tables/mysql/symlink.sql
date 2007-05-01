# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'symlink'
#
CREATE TABLE symlink (
  symlink_id int(11) DEFAULT '0' NOT NULL,
  symlink_node int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (symlink_id)
);

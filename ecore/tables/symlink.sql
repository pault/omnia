# MySQL dump 6.0
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.25

#
# Table structure for table 'symlink'
#
CREATE TABLE symlink (
  symlink_id int(11) DEFAULT '0' NOT NULL,
  symlink_node int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (symlink_id)
);

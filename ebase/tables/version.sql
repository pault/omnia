# MySQL dump 6.0
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.25

#
# Table structure for table 'version'
#

CREATE TABLE version (
  version_id int(11) DEFAULT '0' NOT NULL,
  version int(11) DEFAULT '1' NOT NULL,
  PRIMARY KEY (version_id)
);

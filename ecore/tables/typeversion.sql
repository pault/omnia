# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'typeversion'
#

CREATE TABLE typeversion (
  typeversion_id int(11) DEFAULT '0' NOT NULL,
  version int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (typeversion_id)
);
# MySQL dump 7.1
#
# Host: localhost    Database: test
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'typeversion'
#
CREATE TABLE typeversion (
  typeversion_id int(11) DEFAULT '0' NOT NULL,
  version int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (typeversion_id)
);

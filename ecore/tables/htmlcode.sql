# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'htmlcode'
#

CREATE TABLE htmlcode (
  htmlcode_id int(11) NOT NULL auto_increment,
  code text,
  PRIMARY KEY (htmlcode_id)
);

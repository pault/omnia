# MySQL dump 6.0
#
# Host: localhost    Database: new
#--------------------------------------------------------
# Server version	3.22.25

#
# Table structure for table 'htmlcode'
#
CREATE TABLE htmlcode (
  htmlcode_id int(11) DEFAULT '0' NOT NULL auto_increment,
  code text,
  PRIMARY KEY (htmlcode_id)
);

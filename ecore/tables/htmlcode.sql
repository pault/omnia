# MySQL dump 6.4
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.27-log

#
# Table structure for table 'htmlcode'
#
CREATE TABLE htmlcode (
  htmlcode_id int(11) DEFAULT '0' NOT NULL auto_increment,
  code text,
  PRIMARY KEY (htmlcode_id)
);

# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'htmlcode'
#
CREATE TABLE htmlcode (
  htmlcode_id int(11) DEFAULT '0' NOT NULL,
  code text,
  PRIMARY KEY (htmlcode_id)
);

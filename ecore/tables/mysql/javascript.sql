# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'javascript'
#
CREATE TABLE javascript (
  javascript_id int(11) DEFAULT '0' NOT NULL,
  code text NOT NULL,
  comment text NOT NULL,
  PRIMARY KEY (javascript_id)
);

# MySQL dump 7.1
#
# Host: localhost    Database: pogo
#--------------------------------------------------------
# Server version	3.22.32

#
# Table structure for table 'nodemethod'
#
CREATE TABLE nodemethod (
  nodemethod_id int(11) DEFAULT '0' NOT NULL,
  supports_nodetype int(11) DEFAULT '0' NOT NULL,
  code text NOT NULL,
  PRIMARY KEY (nodemethod_id)
);

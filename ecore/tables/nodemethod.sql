# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'nodemethod'
#

CREATE TABLE nodemethod (
  nodemethod_id int(11) DEFAULT '0' NOT NULL,
  supports_nodetype int(11) DEFAULT '0' NOT NULL,
  code text DEFAULT '' NOT NULL,
  PRIMARY KEY (nodemethod_id)
);

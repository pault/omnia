# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'nodegroup'
#

CREATE TABLE nodegroup (
  nodegroup_id int(11) NOT NULL auto_increment,
  rank int(11) DEFAULT '0' NOT NULL,
  node_id int(11) DEFAULT '0' NOT NULL,
  orderby int(11),
  PRIMARY KEY (nodegroup_id,rank)
);

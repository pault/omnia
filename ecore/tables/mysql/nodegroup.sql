# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'nodegroup'
#
CREATE TABLE nodegroup (
  nodegroup_id int(11) DEFAULT '0' NOT NULL,
  rank int(11) DEFAULT '0' NOT NULL,
  node_id int(11) DEFAULT '0' NOT NULL,
  orderby int(11),
  PRIMARY KEY (nodegroup_id,rank)
);

# MySQL dump 6.4
#
# Host: localhost    Database: everyalpha
#--------------------------------------------------------
# Server version	3.22.27

#
# Table structure for table 'nodegroup'
#
CREATE TABLE nodegroup (
  nodegroup_id int(11) DEFAULT '0' NOT NULL auto_increment,
  rank int(11) DEFAULT '0' NOT NULL,
  node_id int(11) DEFAULT '0' NOT NULL,
  orderby int(11),
  PRIMARY KEY (nodegroup_id,rank)
);

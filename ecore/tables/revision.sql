# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'revision'
#

CREATE TABLE revision (
  node_id int(11) DEFAULT '0' NOT NULL,
  revision_id int(11) NOT NULL auto_increment,
  inside_workspace int(11) DEFAULT '0' NOT NULL,
  data text DEFAULT '' NOT NULL,
  tstamp timestamp(14),
  PRIMARY KEY (node_id,revision_id,inside_workspace)
);

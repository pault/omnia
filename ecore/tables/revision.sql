# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'revision'
#

CREATE TABLE revision (
  revision_id int(11) NOT NULL auto_increment,
  node_id int(11) DEFAULT '0' NOT NULL,
  inside_workspace int(11) DEFAULT '0' NOT NULL,
  data text DEFAULT '' NOT NULL,
  tstamp timestamp(14),
  PRIMARY KEY (revision_id,node_id,inside_workspace)
);

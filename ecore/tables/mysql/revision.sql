# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'revision'
#
CREATE TABLE revision (
  node_id int(11) DEFAULT '0' NOT NULL,
  inside_workspace int(11) DEFAULT '0' NOT NULL,
  revision_id int(11) DEFAULT '0' NOT NULL,
  xml text NOT NULL,
  tstamp timestamp(14),
  PRIMARY KEY (node_id,inside_workspace,revision_id)
);

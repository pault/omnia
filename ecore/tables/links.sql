# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'links'
#

CREATE TABLE links (
  from_node int(11) DEFAULT '0' NOT NULL,
  to_node int(11) DEFAULT '0' NOT NULL,
  linktype int(11) DEFAULT '0' NOT NULL,
  hits int(11) DEFAULT '0',
  food int(11) DEFAULT '0',
  PRIMARY KEY (from_node,to_node,linktype)
);

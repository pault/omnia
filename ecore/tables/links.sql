# MySQL dump 7.1
#
# Host: localhost    Database: Ron
#--------------------------------------------------------
# Server version	3.22.32

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

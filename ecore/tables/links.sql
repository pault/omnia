# MySQL dump 6.4
#
# Host: localhost    Database: everyalpha
#--------------------------------------------------------
# Server version	3.22.27

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

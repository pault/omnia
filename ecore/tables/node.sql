# MySQL dump 6.4
#
# Host: localhost    Database: everyalpha
#--------------------------------------------------------
# Server version	3.22.27

#
# Table structure for table 'node'
#
CREATE TABLE node (
  node_id int(11) DEFAULT '0' NOT NULL auto_increment,
  type_nodetype int(11) DEFAULT '0' NOT NULL,
  title char(240) DEFAULT '' NOT NULL,
  author_user int(11) DEFAULT '0' NOT NULL,
  createtime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  hits int(11) DEFAULT '0',
  reputation int(11) DEFAULT '0' NOT NULL,
  lockedby_user int(11) DEFAULT '0' NOT NULL,
  locktime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  core char(1) DEFAULT '0',
  package int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (node_id),
  KEY title (title,type_nodetype),
  KEY author (author_user),
  KEY type (type_nodetype)
);

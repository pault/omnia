# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'node'
#

CREATE TABLE node (
  node_id int(11) NOT NULL auto_increment,
  type_nodetype int(11) DEFAULT '0' NOT NULL,
  title char(240) DEFAULT '' NOT NULL,
  author_user int(11) DEFAULT '0' NOT NULL,
  createtime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  hits int(11) DEFAULT '0',
  loc_location int(11) DEFAULT '0',
  reputation int(11) DEFAULT '0' NOT NULL,
  lockedby_user int(11) DEFAULT '0' NOT NULL,
  locktime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  authoraccess char(4) DEFAULT 'iiii' NOT NULL,
  groupaccess char(5) DEFAULT 'iiiii' NOT NULL,
  otheraccess char(5) DEFAULT 'iiiii' NOT NULL,
  guestaccess char(5) DEFAULT 'iiiii' NOT NULL,
  dynamicauthor_permission int(11) DEFAULT '-1' NOT NULL,
  dynamicgroup_permission int(11) DEFAULT '-1' NOT NULL,
  dynamicother_permission int(11) DEFAULT '-1' NOT NULL,
  dynamicguest_permission int(11) DEFAULT '-1' NOT NULL,
  group_usergroup int(11) DEFAULT '-1' NOT NULL,
  PRIMARY KEY (node_id),
  KEY title (title,type_nodetype),
  KEY author (author_user),
  KEY type (type_nodetype)
);

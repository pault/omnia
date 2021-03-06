# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'nodetype'
#
CREATE TABLE nodetype (
  nodetype_id int(11) DEFAULT '0' NOT NULL,
  restrict_nodetype int(11) DEFAULT '0',
  extends_nodetype int(11) DEFAULT '0',
  restrictdupes int(11) DEFAULT '0',
  sqltable char(255),
  grouptable char(40) DEFAULT '',
  defaultauthoraccess char(4) DEFAULT 'iiii' NOT NULL,
  defaultgroupaccess char(5) DEFAULT 'iiiii' NOT NULL,
  defaultotheraccess char(5) DEFAULT 'iiiii' NOT NULL,
  defaultguestaccess char(5) DEFAULT 'iiiii' NOT NULL,
  defaultgroup_usergroup int(11) DEFAULT '-1' NOT NULL,
  defaultauthor_permission int(11) DEFAULT '-1' NOT NULL,
  defaultgroup_permission int(11) DEFAULT '-1' NOT NULL,
  defaultother_permission int(11) DEFAULT '-1' NOT NULL,
  defaultguest_permission int(11) DEFAULT '-1' NOT NULL,
  maxrevisions int(11) DEFAULT '-1' NOT NULL,
  canworkspace int(11) DEFAULT '-1' NOT NULL,
  PRIMARY KEY (nodetype_id)
);

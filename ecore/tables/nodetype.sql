# MySQL dump 6.4
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.27-log

#
# Table structure for table 'nodetype'
#
CREATE TABLE nodetype (
  nodetype_id int(11) DEFAULT '0' NOT NULL auto_increment,
  readers_user int(11) DEFAULT '0',
  writers_user int(11) DEFAULT '0',
  deleters_user int(11) DEFAULT '0',
  restrict_nodetype int(11) DEFAULT '0',
  extends_nodetype int(11) DEFAULT '0',
  restrictdupes int(11) DEFAULT '0',
  sqltable char(255),
  grouptable char(40) DEFAULT '',
  PRIMARY KEY (nodetype_id)
);

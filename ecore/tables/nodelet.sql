# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'nodelet'
#
CREATE TABLE nodelet (
  nodelet_id int(11) DEFAULT '0' NOT NULL auto_increment,
  nltext text,
  nlcode text,
  nlgoto int(11),
  parent_container int(11),
  lastupdate int(11) DEFAULT '0' NOT NULL,
  updateinterval int(11) DEFAULT '0' NOT NULL,
  mini_nodelet int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (nodelet_id)
);

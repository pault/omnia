# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'container'
#

CREATE TABLE container (
  container_id int(11) NOT NULL auto_increment,
  context text,
  parent_container int(11),
  PRIMARY KEY (container_id)
);

# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'container'
#
CREATE TABLE container (
  container_id int(11) DEFAULT '0' NOT NULL,
  context text,
  parent_container int(11),
  PRIMARY KEY (container_id)
);

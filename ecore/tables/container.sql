# MySQL dump 7.1
#
# Host: localhost    Database: Ron
#--------------------------------------------------------
# Server version	3.22.32

#
# Table structure for table 'container'
#
CREATE TABLE container (
  container_id int(11) DEFAULT '0' NOT NULL auto_increment,
  context text,
  parent_container int(11),
  PRIMARY KEY (container_id)
);

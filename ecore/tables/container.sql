# MySQL dump 6.4
#
# Host: localhost    Database: everyalpha
#--------------------------------------------------------
# Server version	3.22.27

#
# Table structure for table 'container'
#
CREATE TABLE container (
  container_id int(11) DEFAULT '0' NOT NULL auto_increment,
  context text,
  parent_container int(11),
  PRIMARY KEY (container_id)
);

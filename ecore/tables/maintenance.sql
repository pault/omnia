# MySQL dump 6.0
#
# Host: localhost    Database: new
#--------------------------------------------------------
# Server version	3.22.25

#
# Table structure for table 'maintenance'
#
CREATE TABLE maintenance (
  maintenance_id int(11) DEFAULT '0' NOT NULL,
  maintain_nodetype int(11) DEFAULT '0' NOT NULL,
  maintaintype char(32) DEFAULT '' NOT NULL,
  PRIMARY KEY (maintenance_id)
);

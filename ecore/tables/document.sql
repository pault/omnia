# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'document'
#

CREATE TABLE document (
  document_id int(11) NOT NULL auto_increment,
  doctext text,
  PRIMARY KEY (document_id)
);

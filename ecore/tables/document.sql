# MySQL dump 7.1
#
# Host: localhost    Database: test
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'document'
#
CREATE TABLE document (
  document_id int(11) DEFAULT '0' NOT NULL auto_increment,
  doctext text,
  PRIMARY KEY (document_id)
);

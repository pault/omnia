# MySQL dump 6.4
#
# Host: localhost    Database: everyalpha
#--------------------------------------------------------
# Server version	3.22.27

#
# Table structure for table 'document'
#
CREATE TABLE document (
  document_id int(11) DEFAULT '0' NOT NULL auto_increment,
  doctext text,
  PRIMARY KEY (document_id)
);

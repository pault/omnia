# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'document'
#
CREATE TABLE document (
  document_id int(11) DEFAULT '0' NOT NULL,
  doctext text,
  PRIMARY KEY (document_id)
);

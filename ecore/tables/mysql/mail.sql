# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'mail'
#
CREATE TABLE mail (
  mail_id int(11) DEFAULT '0' NOT NULL,
  from_address char(80) DEFAULT '' NOT NULL,
  PRIMARY KEY (mail_id)
);

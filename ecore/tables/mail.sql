# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'mail'
#

CREATE TABLE mail (
  mail_id int(11) DEFAULT '0' NOT NULL,
  from_address char(80) DEFAULT '' NOT NULL,
  attachment_file int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (mail_id)
);

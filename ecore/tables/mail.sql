# MySQL dump 6.4
#
# Host: localhost    Database: everyalpha
#--------------------------------------------------------
# Server version	3.22.27

#
# Table structure for table 'mail'
#
CREATE TABLE mail (
  mail_id int(11) DEFAULT '0' NOT NULL,
  from_address char(80) DEFAULT '' NOT NULL,
  attachment_file int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (mail_id)
);

# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'message'
#

CREATE TABLE message (
  message_id int(11) NOT NULL auto_increment,
  msgtext char(255) DEFAULT '' NOT NULL,
  author_user int(11) DEFAULT '0' NOT NULL,
  tstamp timestamp(14),
  for_user int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (message_id)
);

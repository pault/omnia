# MySQL dump 7.1
#
# Host: localhost    Database: demo
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'event'
#
CREATE TABLE event (
  event_id int(11) DEFAULT '0' NOT NULL,
  starttime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  endtime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  private int(11) DEFAULT '0' NOT NULL,
  repeat char(40) DEFAULT '' NOT NULL,
  PRIMARY KEY (event_id)
);

# MySQL dump 7.1
#
# Host: localhost    Database: demo
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'address'
#
CREATE TABLE address (
  address_id int(11) DEFAULT '0' NOT NULL,
  company char(64) DEFAULT '' NOT NULL,
  companytitle char(64) DEFAULT '' NOT NULL,
  work char(15) DEFAULT '' NOT NULL,
  home char(15) DEFAULT '' NOT NULL,
  fax char(15) DEFAULT '' NOT NULL,
  mobile char(15) DEFAULT '' NOT NULL,
  pager char(15) DEFAULT '' NOT NULL,
  email char(64) DEFAULT '' NOT NULL,
  address char(255) DEFAULT '' NOT NULL,
  city char(64) DEFAULT '' NOT NULL,
  state char(64) DEFAULT '' NOT NULL,
  zip char(15) DEFAULT '' NOT NULL,
  country char(64) DEFAULT '' NOT NULL,
  lastname char(64) DEFAULT '' NOT NULL,
  firstname char(64) DEFAULT '' NOT NULL,
  PRIMARY KEY (address_id)
);

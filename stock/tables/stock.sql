# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'stock'
#

CREATE TABLE stock (
  stock_id int(11) DEFAULT '0' NOT NULL,
  market char(64) DEFAULT 'nyse' NOT NULL,
  PRIMARY KEY (stock_id)
);

# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'image'
#

CREATE TABLE image (
  image_id int(11) NOT NULL auto_increment,
  src varchar(255),
  alt varchar(255),
  thumbsrc varchar(255),
  description text,
  PRIMARY KEY (image_id)
);

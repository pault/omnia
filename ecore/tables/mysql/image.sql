# MySQL dump 7.1
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'image'
#
CREATE TABLE image (
  image_id int(11) DEFAULT '0' NOT NULL,
  src varchar(255),
  alt varchar(255),
  thumbsrc varchar(255),
  description text,
  PRIMARY KEY (image_id)
);

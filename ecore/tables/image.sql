# MySQL dump 6.0
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.25

#
# Table structure for table 'image'
#
CREATE TABLE image (
  image_id int(11) DEFAULT '0' NOT NULL auto_increment,
  src varchar(255),
  alt varchar(255),
  thumbsrc varchar(255),
  description text,
  PRIMARY KEY (image_id)
);

# MySQL dump 6.4
#
# Host: localhost    Database: everyalpha
#--------------------------------------------------------
# Server version	3.22.27

#
# Table structure for table 'htmlpage'
#
CREATE TABLE htmlpage (
  htmlpage_id int(11) DEFAULT '0' NOT NULL auto_increment,
  pagetype_nodetype int(11),
  displaytype varchar(20),
  page text,
  parent_container int(11),
  PRIMARY KEY (htmlpage_id)
);

# MySQL dump 8.11
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.28-gamma-log

#
# Table structure for table 'htmlpage'
#

CREATE TABLE htmlpage (
  htmlpage_id int(11) NOT NULL auto_increment,
  pagetype_nodetype int(11),
  displaytype varchar(20),
  page text,
  parent_container int(11),
  ownedby_theme int(11) DEFAULT '0' NOT NULL,
  permissionneeded char(1) DEFAULT 'r' NOT NULL,
  PRIMARY KEY (htmlpage_id)
);

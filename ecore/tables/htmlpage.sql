# MySQL dump 6.0
#
# Host: localhost    Database: test
#--------------------------------------------------------
# Server version	3.22.25

#
# Table structure for table 'htmlpage'
#
CREATE TABLE htmlpage (
  htmlpage_id int(11) DEFAULT '0' NOT NULL auto_increment,
  pagetype_nodetype int(11),
  displaytype varchar(20),
  page text,
  parent_container int(11),
  ownedby_theme int(11) DEFAULT '0' NOT NULL,
  permissionneeded char(1) DEFAULT 'r' NOT NULL,
  MIMEtype varchar(255) DEFAULT 'text/html' NOT NULL,
  PRIMARY KEY (htmlpage_id)
);

# MySQL dump 6.4
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.27-log

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
  PRIMARY KEY (htmlpage_id)
);

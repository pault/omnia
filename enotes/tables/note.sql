# MySQL dump 6.4
#
# Host: localhost    Database: everyalpha
#--------------------------------------------------------
# Server version	3.22.27

#
# Table structure for table 'note'
#
CREATE TABLE note (
  note_id int(11) DEFAULT '0' NOT NULL auto_increment,
  parent_node int(11) DEFAULT '0' NOT NULL,
  position int(11),
  PRIMARY KEY (note_id)
);

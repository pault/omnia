# MySQL dump 7.1
#
# Host: localhost    Database: oostendo
#--------------------------------------------------------
# Server version	3.22.32

#
# Table structure for table 'task_update'
#
CREATE TABLE task_update (
  task_update_id int(11) DEFAULT '0' NOT NULL,
  updatetime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  update_type char(40) DEFAULT '' NOT NULL,
  parent_task int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (task_update_id)
);

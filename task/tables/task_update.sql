# MySQL dump 6.0
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.25

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

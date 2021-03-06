# MySQL dump 6.0
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.22.25

#
# Table structure for table 'task'
#
CREATE TABLE task (
  task_id int(11) DEFAULT '0' NOT NULL,
  category char(40) DEFAULT 'none' NOT NULL,
  rating char(40) DEFAULT 'normal' NOT NULL,
  owner int(11) DEFAULT '0' NOT NULL,
  due_date date DEFAULT '0000-00-00' NOT NULL,
  status char(40) DEFAULT 'open' NOT NULL,
  PRIMARY KEY (task_id)
);

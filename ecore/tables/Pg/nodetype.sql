-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:18 2004
-- 
--
-- Table: nodetype
--

CREATE TABLE "nodetype" (
  "nodetype_id" serial NOT NULL,
  "restrict_nodetype" bigint DEFAULT '0',
  "extends_nodetype" bigint DEFAULT '0',
  "restrictdupes" bigint DEFAULT '0',
  "sqltable" character(255),
  "grouptable" character(40) DEFAULT '',
  "defaultauthoraccess" character(4) DEFAULT 'iiii' NOT NULL,
  "defaultgroupaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "defaultotheraccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "defaultguestaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "defaultgroup_usergroup" bigint DEFAULT '-1' NOT NULL,
  "defaultauthor_permission" bigint DEFAULT '-1' NOT NULL,
  "defaultgroup_permission" bigint DEFAULT '-1' NOT NULL,
  "defaultother_permission" bigint DEFAULT '-1' NOT NULL,
  "defaultguest_permission" bigint DEFAULT '-1' NOT NULL,
  "maxrevisions" bigint DEFAULT '-1' NOT NULL,
  "canworkspace" bigint DEFAULT '-1' NOT NULL,
  PRIMARY KEY ("nodetype_id")
);


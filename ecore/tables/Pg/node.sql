-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:10 2004
-- 
--
-- Table: node
--

CREATE TABLE "node" (
  "node_id" serial NOT NULL,
  "type_nodetype" bigint DEFAULT '0' NOT NULL,
  "title" character(240) DEFAULT '' NOT NULL,
  "author_user" bigint DEFAULT '0' NOT NULL,
  "createtime" timestamp NOT NULL,
  "modified" timestamp NOT NULL,
  "hits" bigint DEFAULT '0',
  "loc_location" bigint DEFAULT '0',
  "reputation" bigint DEFAULT '0' NOT NULL,
  "lockedby_user" bigint DEFAULT '0' NOT NULL,
  "locktime" timestamp NOT NULL,
  "authoraccess" character(4) DEFAULT 'iiii' NOT NULL,
  "groupaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "otheraccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "guestaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "dynamicauthor_permission" bigint DEFAULT '-1' NOT NULL,
  "dynamicgroup_permission" bigint DEFAULT '-1' NOT NULL,
  "dynamicother_permission" bigint DEFAULT '-1' NOT NULL,
  "dynamicguest_permission" bigint DEFAULT '-1' NOT NULL,
  "group_usergroup" bigint DEFAULT '-1' NOT NULL,
  PRIMARY KEY ("node_id")
);

CREATE INDEX "title" on node ("title", "type_nodetype");

CREATE INDEX "author" on node ("author_user");

CREATE INDEX "type" on node ("type_nodetype");


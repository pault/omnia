-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:42 2004
-- 
--
-- Table: symlink
--

CREATE TABLE "symlink" (
  "symlink_id" bigint DEFAULT '0' NOT NULL,
  "symlink_node" bigint DEFAULT '0' NOT NULL,
  PRIMARY KEY ("symlink_id")
);


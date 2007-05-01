-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:45 2004
-- 
--
-- Table: nodegroup
--

CREATE TABLE "nodegroup" (
  "nodegroup_id" bigint NOT NULL,
  "rank" bigint DEFAULT '0' NOT NULL,
  "node_id" bigint DEFAULT '0' NOT NULL,
  "orderby" bigint,
  PRIMARY KEY ("nodegroup_id", "rank")
);


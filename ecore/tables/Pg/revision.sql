-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:27 2004
-- 
--
-- Table: revision
--

CREATE TABLE "revision" (
  "node_id" bigint DEFAULT '0' NOT NULL,
  "inside_workspace" bigint DEFAULT '0' NOT NULL,
  "revision_id" bigint DEFAULT '0' NOT NULL,
  "xml" text NOT NULL,
  "tstamp" timestamp(6),
  PRIMARY KEY ("node_id", "inside_workspace", "revision_id")
);


-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:25 2004
-- 
--
-- Table: links
--

CREATE TABLE "links" (
  "from_node" bigint DEFAULT '0' NOT NULL,
  "to_node" bigint DEFAULT '0' NOT NULL,
  "linktype" bigint DEFAULT '0' NOT NULL,
  "hits" bigint DEFAULT '0',
  "food" bigint DEFAULT '0',
  PRIMARY KEY ("from_node", "to_node", "linktype")
);


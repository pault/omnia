-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:02 2004
-- 
--
-- Table: nodemethod
--

CREATE TABLE "nodemethod" (
  "nodemethod_id" bigint DEFAULT '0' NOT NULL,
  "supports_nodetype" bigint DEFAULT '0' NOT NULL,
  "code" text NOT NULL,
  PRIMARY KEY ("nodemethod_id")
);


-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:05:36 2004
-- 
--
-- Table: container
--

CREATE TABLE "container" (
  "container_id" serial NOT NULL,
  "context" text,
  "parent_container" bigint,
  PRIMARY KEY ("container_id")
);


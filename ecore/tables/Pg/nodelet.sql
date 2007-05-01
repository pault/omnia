-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:54 2004
-- 
--
-- Table: nodelet
--

CREATE TABLE "nodelet" (
  "nodelet_id" bigint NOT NULL,
  "nltext" text,
  "nlcode" text,
  "parent_container" bigint,
  "lastupdate" bigint DEFAULT '0' NOT NULL,
  "updateinterval" bigint DEFAULT '0' NOT NULL,
  "mini_nodelet" bigint DEFAULT '0' NOT NULL,
  PRIMARY KEY ("nodelet_id")
);


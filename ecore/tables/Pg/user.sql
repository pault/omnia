-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:08:06 2004
-- 
--
-- Table: user_
--

CREATE TABLE "user" (
  "user_id" serial NOT NULL,
  "nick" character varying(20),
  "passwd" character varying(10),
  "realname" character varying(40),
  "email" character varying(40),
  "lasttime" timestamp,
  "karma" bigint DEFAULT '0',
  "inside_workspace" bigint DEFAULT '0' NOT NULL,
  PRIMARY KEY ("user_id")
);


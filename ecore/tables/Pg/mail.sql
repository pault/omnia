-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:35 2004
-- 
--
-- Table: mail
--

CREATE TABLE "mail" (
  "mail_id" bigint DEFAULT '0' NOT NULL,
  "from_address" character(80) DEFAULT '' NOT NULL,
  PRIMARY KEY ("mail_id")
);


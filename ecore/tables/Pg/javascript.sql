-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:17 2004
-- 
--
-- Table: javascript
--

CREATE TABLE "javascript" (
  "javascript_id" bigint DEFAULT '0' NOT NULL,
  "code" text NOT NULL,
  "comment" text DEFAULT '',
  PRIMARY KEY ("javascript_id")
);


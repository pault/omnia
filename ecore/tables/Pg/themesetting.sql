-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:51 2004
-- 
--
-- Table: themesetting
--

CREATE TABLE "themesetting" (
  "themesetting_id" bigint DEFAULT '0' NOT NULL,
  "parent_theme" bigint DEFAULT '0' NOT NULL,
  PRIMARY KEY ("themesetting_id")
);


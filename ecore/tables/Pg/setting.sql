-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:35 2004
-- 
--
-- Table: setting
--

CREATE TABLE "setting" (
  "setting_id" NOT NULL,
  "vars" text default '',
  PRIMARY KEY ("setting_id")
);


-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:05:45 2004
-- 
--
-- Table: document
--

CREATE TABLE "document" (
  "document_id" bigint NOT NULL,
  "doctext" text,
  PRIMARY KEY ("document_id")
);


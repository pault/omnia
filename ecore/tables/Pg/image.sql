-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:09 2004
-- 
--
-- Table: image
--

CREATE TABLE "image" (
  "image_id" serial NOT NULL,
  "src" character varying(255),
  "alt" character varying(255),
  "thumbsrc" character varying(255),
  "description" text,
  PRIMARY KEY ("image_id")
);


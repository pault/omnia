-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:01 2004
-- 
--
-- Table: htmlpage
--

CREATE TABLE "htmlpage" (
  "htmlpage_id" bigint NOT NULL,
  "pagetype_nodetype" bigint,
  "displaytype" character varying(20),
  "page" text,
  "parent_container" bigint,
  "ownedby_theme" bigint DEFAULT '0' NOT NULL,
  "permissionneeded" character(1) DEFAULT 'r' NOT NULL,
  "MIMEtype" character varying(255) DEFAULT 'text/html' NOT NULL,
  PRIMARY KEY ("htmlpage_id")
);


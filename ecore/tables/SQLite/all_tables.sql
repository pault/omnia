-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Tue Dec 12 16:12:36 2006
-- 
BEGIN TRANSACTION;


--
-- Table: mail
--
DROP TABLE IF EXISTS mail;
CREATE TABLE mail (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:35 2004
-- Table: mail
--

  mail_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  from_address char(80) DEFAULT ''
);


--
-- Table: image
--
DROP TABLE IF EXISTS image;
CREATE TABLE image (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:09 2004
-- Table: image
--

  image_id INTEGER PRIMARY KEY NOT NULL,
  src varchar(255),
  alt varchar(255),
  thumbsrc varchar(255),
  description text
);


--
-- Table: container
--
DROP TABLE IF EXISTS container;
CREATE TABLE container (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:05:36 2004
-- Table: container
--

  container_id INTEGER PRIMARY KEY NOT NULL,
  context text,
  parent_container integer(20)
);


--
-- Table: node
--

CREATE TABLE node (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:10 2004
-- Table: node
--

  node_id INTEGER PRIMARY KEY NOT NULL,
  type_nodetype integer(20) NOT NULL DEFAULT '0',
  title char(240) NOT NULL DEFAULT '',
  author_user integer(20) NOT NULL DEFAULT '0',
  createtime timestamp NOT NULL,
  modified timestamp NOT NULL DEFAULT '0000-00-00',
  hits integer(20) DEFAULT '0',
  loc_location integer(20) DEFAULT '0',
  reputation integer(20) NOT NULL DEFAULT '0',
  lockedby_user integer(20) NOT NULL DEFAULT '0',
  locktime timestamp NOT NULL DEFAULT '0',
  authoraccess char(4) NOT NULL DEFAULT 'iiii',
  groupaccess char(5) NOT NULL DEFAULT 'iiiii',
  otheraccess char(5) NOT NULL DEFAULT 'iiiii',
  guestaccess char(5) NOT NULL DEFAULT 'iiiii',
  dynamicauthor_permission integer(20) NOT NULL DEFAULT '-1',
  dynamicgroup_permission integer(20) NOT NULL DEFAULT '-1',
  dynamicother_permission integer(20) NOT NULL DEFAULT '-1',
  dynamicguest_permission integer(20) NOT NULL DEFAULT '-1',
  group_usergroup integer(20) NOT NULL DEFAULT '-1'
);


--
-- Table: symlink
--
DROP TABLE IF EXISTS symlink;
CREATE TABLE symlink (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:42 2004
-- Table: symlink
--

  symlink_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  symlink_node integer(20) NOT NULL DEFAULT '0'
);


--
-- Table: nodemethod
--
DROP TABLE IF EXISTS nodemethod;
CREATE TABLE nodemethod (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:02 2004
-- Table: nodemethod
--

  nodemethod_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  supports_nodetype integer(20) NOT NULL DEFAULT '0',
  code text NOT NULL DEFAULT ''
);


--
-- Table: nodetype
--
CREATE TABLE nodetype (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:18 2004
-- Table: nodetype
--

  nodetype_id INTEGER PRIMARY KEY NOT NULL,
  restrict_nodetype integer(20) DEFAULT '0',
  extends_nodetype integer(20) DEFAULT '0',
  restrictdupes integer(20) DEFAULT '0',
  sqltable char(255),
  grouptable char(40) DEFAULT '',
  defaultauthoraccess char(4) NOT NULL DEFAULT 'iiii',
  defaultgroupaccess char(5) NOT NULL DEFAULT 'iiiii',
  defaultotheraccess char(5) NOT NULL DEFAULT 'iiiii',
  defaultguestaccess char(5) NOT NULL DEFAULT 'iiiii',
  defaultgroup_usergroup integer(20) NOT NULL DEFAULT '-1',
  defaultauthor_permission integer(20) NOT NULL DEFAULT '-1',
  defaultgroup_permission integer(20) NOT NULL DEFAULT '-1',
  defaultother_permission integer(20) NOT NULL DEFAULT '-1',
  defaultguest_permission integer(20) NOT NULL DEFAULT '-1',
  maxrevisions integer(20) NOT NULL DEFAULT '-1',
  canworkspace integer(20) NOT NULL DEFAULT '-1'
);


--
-- Table: typeversion
--
DROP TABLE IF EXISTS typeversion;
CREATE TABLE typeversion (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:58 2004
-- Table: typeversion
--

  typeversion_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  version integer(20) NOT NULL DEFAULT '0'
);


--
-- Table: nodelet
--
DROP TABLE IF EXISTS nodelet;
CREATE TABLE nodelet (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:54 2004
-- Table: nodelet
--

  nodelet_id INTEGER PRIMARY KEY NOT NULL,
  nltext text,
  nlcode text,
  parent_container integer(20),
  lastupdate integer(20) NOT NULL DEFAULT '0',
  updateinterval integer(20) NOT NULL DEFAULT '0',
  mini_nodelet integer(20) NOT NULL DEFAULT '0'
);


--
-- Table: revision
--
DROP TABLE IF EXISTS revision;
CREATE TABLE revision (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:27 2004
-- Table: revision
--

  node_id integer(20) NOT NULL DEFAULT '0',
  inside_workspace integer(20) NOT NULL DEFAULT '0',
  revision_id integer(20) NOT NULL DEFAULT '0',
  xml text NOT NULL,
  tstamp timestamp,
  PRIMARY KEY (node_id, inside_workspace, revision_id)
);


--
-- Table: workspace
--
DROP TABLE IF EXISTS workspace;
CREATE TABLE workspace (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:08:14 2004
-- Table: workspace
--

  workspace_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0'
);


--
-- Table: htmlcode
--
DROP TABLE IF EXISTS htmlcode;
CREATE TABLE htmlcode (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:05:53 2004
-- Table: htmlcode
--

  htmlcode_id INTEGER PRIMARY KEY NOT NULL,
  code text
);


--
-- Table: themesetting
--
DROP TABLE IF EXISTS themesetting;
CREATE TABLE themesetting (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:51 2004
-- Table: themesetting
--

  themesetting_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  parent_theme integer(20) NOT NULL DEFAULT '0'
);


--
-- Table: htmlpage
--
DROP TABLE IF EXISTS htmlpage;
CREATE TABLE htmlpage (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:01 2004
-- Table: htmlpage
--

  htmlpage_id INTEGER PRIMARY KEY NOT NULL,
  pagetype_nodetype integer(20),
  displaytype varchar(20),
  page text,
  parent_container integer(20),
  ownedby_theme integer(20) NOT NULL DEFAULT '0',
  permissionneeded char(1) NOT NULL DEFAULT 'r',
  MIMEtype varchar(255) NOT NULL DEFAULT 'text/html'
);


--
-- Table: nodegroup
--
DROP TABLE IF EXISTS nodegroup;
CREATE TABLE nodegroup (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:45 2004
-- Table: nodegroup
--

  nodegroup_id integer NOT NULL,
  rank integer(20) NOT NULL DEFAULT '0',
  node_id integer(20) NOT NULL DEFAULT '0',
  orderby integer(20),
  PRIMARY KEY (nodegroup_id, rank)
);


--
-- Table: javascript
--
DROP TABLE IF EXISTS javascript;
CREATE TABLE javascript (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:17 2004
-- Table: javascript
--

  javascript_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  code text NOT NULL DEFAULT '',
  comment text DEFAULT '',
  dynamic integer(20) NOT NULL DEFAULT '0'
);


--
-- Table: setting
--
CREATE TABLE setting (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:07:35 2004
-- Table: setting
--

  setting_id INTEGER PRIMARY KEY NOT NULL,
  vars text DEFAULT ''
);


--
-- Table: document
--
DROP TABLE IF EXISTS document;
CREATE TABLE document (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:05:45 2004
-- Table: document
--

  document_id INTEGER PRIMARY KEY NOT NULL,
  doctext text
);


--
-- Table: user
--
DROP TABLE IF EXISTS user;
CREATE TABLE user (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:08:06 2004
-- Table: user_
--

  user_id INTEGER PRIMARY KEY NOT NULL,
  nick varchar(20),
  passwd varchar(10),
  realname varchar(40),
  email varchar(40),
  lasttime timestamp,
  karma integer(20) DEFAULT '0',
  inside_workspace integer(20) NOT NULL DEFAULT '0'
);


--
-- Table: links
--
DROP TABLE IF EXISTS links;
CREATE TABLE links (
-- Comments: 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:25 2004
-- Table: links
--

  from_node integer(20) NOT NULL DEFAULT '0',
  to_node integer(20) NOT NULL DEFAULT '0',
  linktype integer(20) NOT NULL DEFAULT '0',
  hits integer(20) DEFAULT '0',
  food integer(20) DEFAULT '0',
  PRIMARY KEY (from_node, to_node, linktype)
);


COMMIT;

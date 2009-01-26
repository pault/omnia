CREATE TABLE node (
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
  group_usergroup integer(20) NOT NULL DEFAULT '-1'
)
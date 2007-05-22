CREATE TABLE nodetype (
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
)
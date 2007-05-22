CREATE TABLE user (
  user_id INTEGER PRIMARY KEY NOT NULL,
  nick varchar(20),
  passwd varchar(10),
  realname varchar(40),
  email varchar(40),
  lasttime timestamp,
  karma integer(20) DEFAULT '0',
  inside_workspace integer(20) NOT NULL DEFAULT '0'
)
CREATE TABLE htmlpage (
  htmlpage_id INTEGER PRIMARY KEY NOT NULL,
  pagetype_nodetype integer(20),
  displaytype varchar(20),
  page text,
  parent_container integer(20),
  ownedby_theme integer(20) NOT NULL DEFAULT '0',
  permissionneeded char(1) NOT NULL DEFAULT 'r',
  MIMEtype varchar(255) NOT NULL DEFAULT 'text/html'
)
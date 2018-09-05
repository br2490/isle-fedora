CREATE DATABASE IF NOT EXISTS {{getv "/fedora/db"}} CHARACTER SET utf8 COLLATE utf8_general_ci;
ALTER USER IF EXISTS {{getv "/fedora/db/user"}} IDENTIFIED BY '{{getv "/fedora/db/pass"}}';
CREATE USER IF NOT EXISTS '{{getv "/fedora/db/user"}}'@'%' IDENTIFIED BY '{{getv "/fedora/db/pass"}}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, ALTER ROUTINE, CREATE ROUTINE, CREATE TEMPORARY TABLES, CREATE VIEW, EVENT, EXECUTE, LOCK TABLES, REFERENCES, SHOW VIEW, TRIGGER ON {{getv "/fedora/db"}}.* TO '{{getv "/fedora/db/user"}}'@'%';
FLUSH PRIVILEGES;

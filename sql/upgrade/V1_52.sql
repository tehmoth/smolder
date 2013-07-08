
-- modify column text default ''
-- add column vcs_rev_url text default ''
BEGIN TRANSACTION;
DROP INDEX i_project_name_project;

ALTER TABLE project RENAME TO project_orig;

CREATE TABLE project (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    name                TEXT NOT NULL,
    start_date          TEXT DEFAULT '',
    public              INTEGER DEFAULT 1,
    enable_feed         INTEGER DEFAULT 1,
    default_platform    TEXT DEFAULT '',
    default_arch        TEXT DEFAULT '',
    graph_start         TEXT DEFAULT 'project',
    allow_anon          INTEGER DEFAULT 0,
    max_reports         INTEGER DEFAULT 100,
    extra_css           TEXT DEFAULT '',
    vcs_rev_url         TEXT DEFAULT ''
);

INSERT INTO project SELECT *, '' FROM project_orig;

CREATE UNIQUE INDEX i_project_name_project on project (name);
COMMIT;


-- modify column added text default ''
BEGIN TRANSACTION;
DROP INDEX i_project_smoke_report;
DROP INDEX i_developer_smoke_report;

ALTER TABLE smoke_report RENAME TO smoke_report_orig;

CREATE TABLE smoke_report  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    project         INTEGER NOT NULL,
    developer       INTEGER NOT NULL,
    added           TEXT DEFAULT '',
    architecture    TEXT DEFAULT '',
    platform        TEXT DEFAULT '',
    pass            INTEGER DEFAULT 0,
    fail            INTEGER DEFAULT 0,
    skip            INTEGER DEFAULT 0,
    todo            INTEGER DEFAULT 0,
    todo_pass       INTEGER DEFAULT 0,
    test_files      INTEGER DEFAULT 0,
    total           INTEGER DEFAULT 0,
    comments        BLOB DEFAULT '',
    invalid         INTEGER DEFAULT 0,
    invalid_reason  BLOB DEFAULT '',
    duration        INTEGER DEFAULT 0,
    purged          INTEGER DEFAULT 0,
    failed          INTEGER DEFAULT 0,
    revision        TEXT DEFAULT '',
    CONSTRAINT 'fk_smoke_report_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_smoke_report_developer' FOREIGN KEY ('developer') REFERENCES 'developer' ('id') ON DELETE CASCADE
);

INSERT INTO smoke_report SELECT * FROM smoke_report_orig;

CREATE INDEX i_project_smoke_report ON smoke_report (project);
CREATE INDEX i_developer_smoke_report ON smoke_report (developer);


COMMIT;


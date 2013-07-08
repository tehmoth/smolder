ALTER TABLE project
    MODIFY COLUMN start_date TEXT DEFAULT '';

ALTER TABLE project
    ADD COLUMN vcs_rev_url TEXT DEFAULT '';

ALTER TABLE smoke_report
    MODIFY COLUMN added TEXT DEFAULT '';


---------------------------------------------
-- ARAS BASELINE PREPARATION SCRIPT
-- Source DB → Clean Clone → Baseline.bak
-- For DB: Innovator_SG
---------------------------------------------

DECLARE 
    @SourceDB NVARCHAR(128) = 'Innovator_SG',
    @CloneDB  NVARCHAR(128) = 'Innovator_SG_BASELINE_WORK',
    @BackupFile NVARCHAR(260) = 'C:\Users\krantik\Desktop\aras-baseline-deployment\Baseline\DB\Baseline.bak';

PRINT '========================================';
PRINT ' STEP-1 : Creating clean clone database';
PRINT '========================================';

IF DB_ID(@CloneDB) IS NOT NULL
BEGIN
    PRINT 'Dropping existing clone DB...';
    ALTER DATABASE [Innovator_SG_BASELINE_WORK] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [Innovator_SG_BASELINE_WORK];
END

EXEC('CREATE DATABASE [' + @CloneDB + ']');
PRINT 'Empty clone DB created';


------------------------------------------------
-- Copy SCHEMA ONLY (tables, views, constraints)
------------------------------------------------
PRINT 'Copying schema from source...';

DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql = @sql + '
SELECT * INTO ' + QUOTENAME(@CloneDB) + '.dbo.' + QUOTENAME(t.name) + '
FROM ' + QUOTENAME(@SourceDB) + '.dbo.' + QUOTENAME(t.name) + ' WHERE 1=0;'
FROM sys.tables t;

EXEC(@sql);

PRINT 'Schema copy completed';


----------------------------------------
-- STEP-2 : Copy mandatory seed tables
----------------------------------------
PRINT 'Copying required seed data...';

INSERT INTO Innovator_SG_BASELINE_WORK.dbo.[IDENTITY]
SELECT * FROM Innovator_SG.dbo.[IDENTITY];

INSERT INTO Innovator_SG_BASELINE_WORK.dbo.[USER]
SELECT * FROM Innovator_SG.dbo.[USER];

INSERT INTO Innovator_SG_BASELINE_WORK.dbo.[VAULT]
SELECT * FROM Innovator_SG.dbo.[VAULT];

INSERT INTO Innovator_SG_BASELINE_WORK.dbo.[VAULT_FOLDER]
SELECT * FROM Innovator_SG.dbo.[VAULT_FOLDER];

INSERT INTO Innovator_SG_BASELINE_WORK.dbo.[PARTITION]
SELECT * FROM Innovator_SG.dbo.[PARTITION];

INSERT INTO Innovator_SG_BASELINE_WORK.dbo.[ITEMTYPE]
SELECT * FROM Innovator_SG.dbo.[ITEMTYPE];

INSERT INTO Innovator_SG_BASELINE_WORK.dbo.[RELATIONSHIPTYPE]
SELECT * FROM Innovator_SG.dbo.[RELATIONSHIPTYPE];

PRINT 'Seed data copied';


----------------------------------------
-- STEP-3 : Optional cleanup
----------------------------------------
PRINT 'Keeping only admin user...';

DELETE FROM Innovator_SG_BASELINE_WORK.dbo.[USER]
WHERE login_name <> 'admin';


----------------------------------------
-- STEP-4 : Validate baseline DB
----------------------------------------
PRINT 'Validating clone DB...';

USE Innovator_SG_BASELINE_WORK;

SELECT COUNT(*) AS Users   FROM [USER];
SELECT COUNT(*) AS Types   FROM [ITEMTYPE];

PRINT 'Validation complete';


----------------------------------------
-- STEP-5 : Backup to Baseline.bak
----------------------------------------
PRINT 'Creating baseline backup...';

BACKUP DATABASE Innovator_SG_BASELINE_WORK
TO DISK = @BackupFile
WITH INIT, FORMAT;

PRINT '========================================';
PRINT '  BASELINE.BAK CREATED SUCCESSFULLY 🎯';
PRINT '  File: ' + @BackupFile;
PRINT '========================================';

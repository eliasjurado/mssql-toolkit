CREATE PROC xFormat_K4 (@strvalsearch NVARCHAR(100))
AS
BEGIN
	CREATE TABLE #result (
		columnname NVARCHAR(370)
		,columnvalue NVARCHAR(3630)
		)

	SET NOCOUNT ON

	DECLARE @tablename NVARCHAR(256)
		,@columnname NVARCHAR(128)
		,@strvalsearch2 NVARCHAR(110)

	SET @tablename = ''
	SET @strvalsearch2 = quotename(@strvalsearch, '''')

	WHILE @tablename IS NOT NULL
	BEGIN
		SET @columnname = ''
		SET @tablename = (
				SELECT min(quotename(table_schema) + '.' + quotename(table_name))
				FROM information_schema.tables
				WHERE table_type = 'base table'
					AND quotename(table_schema) + '.' + quotename(table_name) > @tablename
					AND objectproperty(object_id(quotename(table_schema) + '.' + quotename(table_name)), 'ismsshipped') = 0
				)

		WHILE (@tablename IS NOT NULL)
			AND (@columnname IS NOT NULL)
		BEGIN
			SET @columnname = (
					SELECT min(quotename(column_name))
					FROM information_schema.columns
					WHERE table_schema = parsename(@tablename, 2)
						AND table_name = parsename(@tablename, 1)
						AND data_type IN (
							'char'
							,'varchar'
							,'nchar'
							,'nvarchar'
							)
						AND quotename(column_name) > @columnname
					)

			IF @columnname IS NOT NULL
			BEGIN
				INSERT INTO #result
				EXEC (
						'select top(100) ''' + @tablename + '.' + @columnname + ''', left(' + @columnname + ', 3630)
              from ' + @tablename + ' (nolock) ' + ' where ' + @columnname + ' = ' + @strvalsearch2
						)
			END
		END
	END

	SELECT columnname
		,columnvalue
	FROM #result
END
GO

CREATE PROCEDURE xFormat_K5 @tablename NVARCHAR(100)
AS
BEGIN
	DECLARE @sql NVARCHAR(500);
	DECLARE @p1 NVARCHAR(500);
	DECLARE @pk NVARCHAR(500);

	IF charindex(',', @tablename) > 0
	BEGIN
		SET @p1 = substring(@tablename, charindex(',', @tablename) + 1, len(@tablename))
		SET @tablename = substring(@tablename, 1, charindex(',', @tablename) - 1)
		SET @pk = (
				SELECT name
				FROM sys.columns
				WHERE object_id = (
						SELECT object_id
						FROM sys.tables
						WHERE name = @tablename
							AND column_id = 1
						)
				)

		PRINT @p1
		PRINT @tablename
		PRINT @pk
	END

	SET @sql = 'select top(100) * from ' + @tablename + ' order by 1 desc'

	IF @p1 IS NOT NULL
	BEGIN
		SET @sql = @sql + ' where ' + @pk + ' = ''' + @p1 + ''' order by 1 desc'
	END

	EXEC sys.[sp_executesql] @sql
END
GO

CREATE PROCEDURE xFormat_K6 @tablename VARCHAR(4000)
AS
BEGIN
	SELECT clmns.column_id AS [id]
		,clmns.name AS [name]
		--,isnull(dc.name, '') as [defaultconstraintname]
		--,clmns.is_nullable
		,CASE 
			WHEN clmns.is_nullable = 1
				THEN 'null'
			ELSE 'not null'
			END AS [nullable]
		--,cast(isnull(cik.index_column_id, 0) as bit)
		,CASE 
			WHEN cast(isnull(cik.index_column_id, 0) AS BIT) = 1
				THEN 'primary key'
			ELSE ''
			END AS [inprimarykey]
		--,clmns.is_identity
		,CASE 
			WHEN clmns.is_identity = 1
				THEN 'identity'
			ELSE ''
			END AS [identity]
		,usrt.name AS [datatype]
		--,isnull(baset.name, '') as [systemtype]
		,cast(CASE 
				WHEN baset.name IN (
						'nchar'
						,'nvarchar'
						)
					AND clmns.max_length <> - 1
					THEN clmns.max_length / 2
				ELSE clmns.max_length
				END AS INT) AS [length]
		,cast(clmns.precision AS INT) AS [numericprecision]
	--,cast(clmns.scale as int) as [numericscale]
	--,isnull(xscclmns.name, '') as [xmlschemanamespace]
	--,isnull(s2clmns.name, '') as [xmlschemanamespaceschema]
	--,isnull( (case clmns.is_xml_document when 1 then 2 else 1 end), 0) as [xmldocumentconstraint]
	--,s1clmns.name as [datatypeschema]
	--,clmns.is_computed as [computed]
	FROM sys.tables AS tbl
	INNER JOIN sys.all_columns AS clmns ON clmns.object_id = tbl.object_id
	LEFT OUTER JOIN sys.default_constraints AS dc ON clmns.default_object_id = dc.object_id
	LEFT OUTER JOIN sys.indexes AS ik ON ik.object_id = clmns.object_id
		AND 1 = ik.is_primary_key
	LEFT OUTER JOIN sys.index_columns AS cik ON cik.index_id = ik.index_id
		AND cik.column_id = clmns.column_id
		AND cik.object_id = clmns.object_id
		AND 0 = cik.is_included_column
	LEFT OUTER JOIN sys.types AS usrt ON usrt.user_type_id = clmns.user_type_id
	LEFT OUTER JOIN sys.types AS baset ON (
			baset.user_type_id = clmns.system_type_id
			AND baset.user_type_id = baset.system_type_id
			)
		OR (
			(baset.system_type_id = clmns.system_type_id)
			AND (baset.user_type_id = clmns.user_type_id)
			AND (baset.is_user_defined = 0)
			AND (baset.is_assembly_type = 1)
			)
	LEFT OUTER JOIN sys.xml_schema_collections AS xscclmns ON xscclmns.xml_collection_id = clmns.xml_collection_id
	LEFT OUTER JOIN sys.schemas AS s2clmns ON s2clmns.schema_id = xscclmns.schema_id
	LEFT OUTER JOIN sys.schemas AS s1clmns ON s1clmns.schema_id = usrt.schema_id
	WHERE (tbl.name = @tablename) -- and schema_name(tbl.schema_id)='dbo')
	ORDER BY tbl.object_id
		,[id] ASC
END
GO

CREATE PROCEDURE xFormat_K7 @tablename AS VARCHAR(255)
AS
BEGIN
	SELECT DISTINCT table_schema
		,table_name
	FROM information_schema.columns
	WHERE table_name LIKE '%' + @tablename + '%'
END
GO

CREATE PROCEDURE xFormat_K8 @columnname AS VARCHAR(255)
AS
BEGIN
	SELECT table_name
		,column_name
	FROM information_schema.columns
	WHERE column_name LIKE '%' + @columnname + '%'
END
GO

CREATE PROCEDURE xFormat_K9 @tablename VARCHAR(255)
AS
BEGIN
	SELECT name --, object_definition(object_id) 
	FROM sys.procedures
	WHERE object_definition(object_id) LIKE '%' + @tablename + '%'
	ORDER BY modify_date DESC
END
GO

CREATE PROCEDURE xFormat_K0
AS
PRINT (
		'help key shortcuts
----------------------------------------------------------------------------------------------------------------
ctrl+3	  sp_helptext	fetch object definition by stored procedure name
ctrl+4    xFormat_K4 	find last 10 records in database by keyword
ctrl+5    xFormat_K5    fetch last 100 rows by table name
ctrl+6    xFormat_K6    fetch column type description by table name
ctrl+7    xFormat_K7    find tables by keyword 
ctrl+8    xFormat_K8    find tables by column name keyword
ctrl+9    xFormat_K9    find stored procedures by keyword
ctrl+0    xFormat_K0    help
----------------------------------------------------------------------------------------------------------------'
		);
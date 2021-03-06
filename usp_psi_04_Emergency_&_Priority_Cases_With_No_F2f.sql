BRANDON
USE [idb_datastore]
GO
/****** Object:  StoredProcedure [dbo].[usp_psi_04_Emergency_&_Priority_Cases_With_No_F2f]    Script Date: 6/13/2022 2:21:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[usp_psi_04_Emergency_&_Priority_Cases_With_No_F2f]
AS
SET ANSI_WARNINGS OFF
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN --MAIN
	--************************************************************************************************************************
	--EMPTYING OUT TABLES
	--************************************************************************************************************************             
	TRUNCATE TABLE [04_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F]
	TRUNCATE TABLE [Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04]
	TRUNCATE TABLE Temp_User_Record_Processed_04

	DECLARE @loopVar INT
	DECLARE @loop_Temp_Bucket_days INT
	DECLARE @var_client_id INT
	DECLARE @var_QUESTION_ID INT
	DECLARE @totalNumberOfRecords INT
	DECLARE @var_exploitation_type_non_financial_type INT
	DECLARE @var_exploitation_type_STUFF VARCHAR(100)
	DECLARE @update_client_record_processed VARCHAR(1000)
	DECLARE @update_Temp_Bucket_days_processed VARCHAR(1000)
	DECLARE @var_number_of_days VARCHAR(10)
	DECLARE @var_temp_id VARCHAR(50)
	DECLARE @var_session_uuid VARCHAR(1000)
	DECLARE @update_final_category_logic VARCHAR(500)
	DECLARE @final_category VARCHAR(500)
	DECLARE @update_f2f_logic VARCHAR(500)
	DECLARE @DAY_BUCKET_TO_F2F VARCHAR(100)
	DECLARE @RESPONSE_DAYS_F2F VARCHAR(100)
	DECLARE @table_name_to_update VARCHAR(100)
	DECLARE @transaction_table_name_to_update VARCHAR(100)
	DECLARE @dynSQL VARCHAR(MAX)
	DECLARE @debug INT

	SET @debug = 0 -- 1 YES/ 0 NO  
	SET @loopVar = 1
	SET @table_name_to_update = '[04_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F]'

	IF @debug > 0
		PRINT CHAR(13) + 'table_name_to_update: ' + @table_name_to_update;

	SET @transaction_table_name_to_update = '[Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04]'

	IF @debug > 0
		PRINT CHAR(13) + '@transaction_table_name_to_update: ' + @transaction_table_name_to_update;

	--****************************************************************************************************************************************
	-- CREATE DYNAMIC QUERY TO SELECT THE RELEVANT DATA BASED ON THE CONDITION GIVEN IN WORD FOR  04_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F     
	--****************************************************************************************************************************************
	SET @dynSQL = 
		'                   SELECT 
                                    DISTINCT SESSION_UUID, CLIENT_ID, ''0'' AS RECORD_PROCESSED,
                                    (SELECT QUESTION_ID FROM Assessment WHERE SESSION_UUID = a1.SESSION_UUID AND CLIENT_ID = a1.CLIENT_ID AND QUESTION_ID =1731) AS QUESTION_ID_1731
                             FROM
                                        Assessment a1
                             WHERE
                                                          QUESTION_ID = 1145 AND
                                                          RESPONSE_DATA = ''19'' AND
                                                          SESSION_UUID IN
                                                          (
                                                                        SELECT DISTINCT            
                                                                                      Assessment.SESSION_UUID
                                                                        FROM
                                                                                      Demographic_Enrollment
                                                                        JOIN Assessment ON
                                                                                      Demographic_Enrollment.CLIENT_ID = Assessment.CLIENT_ID
                                                                        WHERE
                                                                                      Demographic_Enrollment.ENROLLMENT_STATUS = ''Active'' AND
                                                                                      Demographic_Enrollment.CARE_PROGRAM_NAME = ''Protective Services'' AND
                                                                                      ASSESSFORM_FILENAME LIKE ''%PS Investigation.afm%'' AND
                                                                                      (CREATE_DATETIME >= Demographic_Enrollment.ENROLLMENT_START_DATE)
                                                                                      --AND
                                                                                      --QUESTION_ID = 4574 AND
                                                                                      --CHOICE_ID IN (''1'',''2'',''4'',''5'',''6'',''7'',''8'')
                                                          )            
                                                          --AND
                                                          --a1.CLIENT_ID NOT IN (SELECT client_id FROM Temp_Client_With_Multiple_SessionID)
                             ORDER BY
                                           CLIENT_ID
              '

	IF @debug > 0
		PRINT + CHAR(13) + CHAR(13) + 'INSERT INTO Temp_User_Record_Processed_04 FROM QUERY OUTPUT dynSQL: ' + @dynSQL;

	--RETURN
	--****************************************************************************************************************************
	-- WE ARE INSERTING DATA IN "Temp_User_Record_Processed_04" TABLE SO WE CAN LOOP OVER IT
	--****************************************************************************************************************************                             
	INSERT INTO Temp_User_Record_Processed_04
	EXEC (@dynSQL)

	SET @dynSQL = ''
	SET @totalNumberOfRecords = (
			SELECT COUNT(ID)
			FROM Temp_User_Record_Processed_04
			)

	IF @debug > 0
		PRINT CHAR(13) + 'Total # of records in Temp_User_Record_Processed_04  = ' + CAST(@totalNumberOfRecords AS VARCHAR);

	--RETURN
	--************************************************************************************************
	--ADD ALL THE USERS WHO DOES NOT HAVE QUESTION ID 1731 IN THEIR PROFILE 
	--*************************************************************************************************
	SET @dynSQL = 
		'
							SELECT DISTINCT SESSION_UUID
						,CLIENT_ID
						,'' 1731 '' AS Question_ID
						,(
							SELECT TOP 1 FIRST_NAME + '' '' + LAST_NAME
							FROM [dbo].[Demographic_Enrollment]
							WHERE CLIENT_ID = T1.CLIENT_ID
							) AS CONSUMER_NAME
						,(
							SELECT STUFF((
										SELECT DISTINCT ''
											,'' + CAST(Description AS VARCHAR(1000))
										FROM Reason_Overdue
										WHERE ''
											,'' + (
												SELECT STUFF((
															SELECT DISTINCT ''
																,'' + CAST(CHOICE_ID AS VARCHAR(1000))
															FROM Assessment
															WHERE QUESTION_ID = 16282
																AND SESSION_UUID = T1.SESSION_UUID
															FOR XML PATH('''')
															), 1, 2, '''')
												) + ''
											,'' LIKE ''
											,'' + CAST(ID AS VARCHAR(255)) + ''
											,''
										FOR XML PATH('''')
										), 1, 2, '''')
							) AS Reason_Overdue
						,(
							SELECT TOP 1 CASE 
									WHEN RESPONSE_DATA != '' NULL ''
										OR RESPONSE_DATA IS NOT NULL
										OR RESPONSE_DATA <> ''''
										THEN PROVIDER_NAME
									ELSE AGENCY_NAME
									END
							FROM Assessment
							WHERE QUESTION_ID = 10812
								AND Client_ID = T1.Client_ID
								AND SESSION_UUID = T1.SESSION_UUID
							) AS Investigating_Agency_OR_Provider_Name
						,(
							SELECT TOP 1 CASE 
									WHEN PROVIDER_NAME = '' NULL ''
										OR PROVIDER_NAME IS NULL
										OR PROVIDER_NAME = ''''
										THEN '' Error – Missing Investigative Agency ''
									ELSE PROVIDER_NAME
									END
							FROM Assessment
							WHERE Client_ID = T1.Client_ID
								AND SESSION_UUID = T1.SESSION_UUID
							) AS PROVIDER_NAME_AS_AGENCY_NAME
						,(
							SELECT TOP 1 CASE 
									WHEN SUBPROVIDER_NAME = '' NULL ''
										OR SUBPROVIDER_NAME IS NULL
										OR SUBPROVIDER_NAME = ''''
										THEN '' Error – Missing Caseworker ''
									ELSE SUBPROVIDER_NAME
									END
							FROM Assessment
							WHERE Client_ID = T1.Client_ID
								AND SESSION_UUID = T1.SESSION_UUID
							) AS SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER
						,'' 01 / 01 / 1900 '' AS RON_DATE_1A1
						,(
							SELECT TOP 1 AGENCY_NAME
							FROM Assessment
							WHERE SESSION_UUID = T1.SESSION_UUID
							) AS AGENCY_NAME
						,(
							SELECT TOP 1 ASSESSOR_NAME
							FROM Assessment
							WHERE SESSION_UUID = T1.SESSION_UUID
							) AS ASSESSOR_NAME
						,(
							SELECT TOP 1 CREATE_DATETIME
							FROM Assessment
							WHERE SESSION_UUID = T1.SESSION_UUID
							) AS CREATE_DATETIME
					FROM Temp_User_Record_Processed_04 T1
					WHERE QUESTION_ID_1731 IS NULL'
	IF @debug > 0
		PRINT 'INSERT INTO Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04 FROM QUERY OUTPUT dynSQL: ' + @dynSQL;

	--RETURN
	INSERT INTO [Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04] (
		SESSION_UUID
		,CLIENT_ID
		,Question_ID
		,Consumer_Name
		,Reason_Overdue
		,Investigating_Agency_OR_Provider_Name
		,PROVIDER_NAME_AS_AGENCY_NAME
		,SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER
		,RON_DATE_1A1
		,AGENCY_NAME
		,ASSESSOR_NAME
		,ASSESSMENT_CREATE_DATETIME
		)
	EXEC (@dynSQL)

	SET @dynSQL = ''

	IF @debug > 0
		PRINT CHAR(13) + CHAR(13) + 'RETURN - Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04 LINE# 287:'

	--RETURN
	--************************************************************************************************************************************************************
	--LOOP OVER THE RECORDS, ONE CLIENT ID AT A TIME ONCE PROCESSES MARK Record_Processed TO 1 SO WE DO NOT USE IT AGAIN
	--************************************************************************************************************************************************************
	--WHILE (@loopVar <= 200)
	WHILE (@loopVar <= @totalNumberOfRecords)
	BEGIN
		SET @var_temp_id = (
				SELECT TOP (1) ID
				FROM Temp_User_Record_Processed_04
				WHERE Record_Processed <> 1
				)

		IF @debug > 0
			PRINT CHAR(13) + @var_temp_id;

		SET @var_client_id = (
				SELECT Client_ID
				FROM Temp_User_Record_Processed_04
				WHERE ID = @var_temp_id
				)

		IF @debug > 0
			PRINT CHAR(13) + CAST(@var_client_id AS VARCHAR(100));

		SET @var_session_uuid = (
				SELECT SESSION_UUID
				FROM Temp_User_Record_Processed_04
				WHERE ID = @var_temp_id
				)

		IF @debug > 0
			PRINT CHAR(13) + CAST(@var_session_uuid AS VARCHAR(100));

		--******************************************************************************************************************************************************************
		-- COLLECT DATA FOR CLIENT ID AND DUMP INTO [Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04]
		--******************************************************************************************************************************************************************                                          
		SET @dynSQL = 
			'  
								SELECT SESSION_UUID
						,Assessment.CLIENT_ID
						,FIRST_NAME + '' '' + LAST_NAME AS '' Consumer_Name ''
						,QUESTION_ID
						,Choice_ID
						,(
							SELECT STUFF((
										SELECT DISTINCT ''
											,'' + CAST(Description AS VARCHAR(1000))
										FROM Reason_Overdue
										WHERE ''
											,'' + (
												SELECT STUFF((
															SELECT DISTINCT ''
																,'' + CAST(CHOICE_ID AS VARCHAR(1000))
															FROM Assessment
															WHERE QUESTION_ID = 16282
																AND SESSION_UUID = ''' 	+ CAST(@var_session_uuid AS VARCHAR(500)) + 	'''
															FOR XML PATH('''')
															), 1, 2, '''')
												) + ''
											,'' LIKE ''
											,'' + CAST(ID AS VARCHAR(255)) + ''
											,''
										FOR XML PATH('''')
										), 1, 2, '''')
							) AS Reason_Overdue
						,(
							SELECT TOP 1 CASE 
									WHEN RESPONSE_DATA != '' NULL ''
										OR RESPONSE_DATA IS NOT NULL
										OR RESPONSE_DATA <> ''''
										THEN PROVIDER_NAME
									ELSE AGENCY_NAME
									END
							FROM Assessment
							WHERE QUESTION_ID = 10812
								AND Client_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + '''
								AND SESSION_UUID = ''' + CAST(@var_session_uuid AS VARCHAR(100)) + 
								'''
							) AS Investigating_Agency_OR_Provider_Name
						,AGENCY_NAME
						,(
							SELECT TOP 1 CASE 
									WHEN PROVIDER_NAME = '' NULL ''
										OR PROVIDER_NAME IS NULL
										OR PROVIDER_NAME = ''''
										THEN '' Error – Missing Investigative Agency ''
									ELSE PROVIDER_NAME
									END
							FROM Assessment
							WHERE Client_ID = '''  + CAST(@var_client_id AS VARCHAR(100)) + '''
								AND SESSION_UUID = ''' + CAST(@var_session_uuid AS VARCHAR(100)) +  '''
							) AS PROVIDER_NAME_AS_AGENCY_NAME
						,(
							SELECT TOP 1 CASE 
									WHEN SUBPROVIDER_NAME = '' NULL ''
										OR SUBPROVIDER_NAME IS NULL
										OR SUBPROVIDER_NAME = ''''
										THEN '' Error – Missing Caseworker ''
									ELSE SUBPROVIDER_NAME
									END
							FROM Assessment
							WHERE Client_ID = ''' 	+ CAST(@var_client_id AS VARCHAR(100)) + '''
								AND SESSION_UUID = ''' + CAST(@var_session_uuid AS VARCHAR(100)) +  '''
							) AS SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER
						,ASSESSOR_NAME
						,(
							--ISNULL(
							SELECT TOP 1 RESPONSE_DATA
							FROM Assessment
							WHERE QUESTION_ID = 1731
								AND SESSION_UUID = ''' + CAST(@var_session_uuid AS VARCHAR(100)) + '''
								--, 0)
							) AS RON_DATE_1A1
						,'''' AS RESPONSE_DAYS_F2F
						,'''' AS DAY_BUCKET_TO_F2F
						,'''' AS PRIORITY_FINAL_CATEGORY_LOGIC
						,CREATE_DATETIME
					FROM Assessment
					JOIN Demographic_Enrollment ON Demographic_Enrollment.CLIENT_ID = Assessment.CLIENT_ID
					WHERE
						--Demographic_Enrollment.ENROLLMENT_STATUS = ''Active'' AND
						--Demographic_Enrollment.CARE_PROGRAM_NAME = ''Protective Services'' AND
						Assessment.CLIENT_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + '''
						AND SESSION_UUID = ''' + CAST(@var_session_uuid AS VARCHAR(100)) + '''
						AND QUESTION_ID IN (
							1731
							,16282
							,10812
							,4072
							,4730
							,4455
							,11489
							,4574
							,1145
							)
					ORDER BY QUESTION_ID
			  '

		IF @debug > 0
			PRINT CHAR(13) + CHAR(13) + 'dynSQL insert into [Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04] : ' + @dynSQL;

		--return
		INSERT INTO [Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04] (
			SESSION_UUID
			,CLIENT_ID
			,Consumer_Name
			,QUESTION_ID
			,Choice_ID
			,REASON_OVERDUE
			,INVESTIGATING_AGENCY_OR_PROVIDER_NAME
			,AGENCY_NAME
			,PROVIDER_NAME_AS_AGENCY_NAME
			,SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER
			,ASSESSOR_NAME
			,RON_DATE_1A1
			,RESPONSE_DAYS_F2F
			,DAY_BUCKET_TO_F2F
			,PRIORITY_FINAL_CATEGORY_LOGIC
			,ASSESSMENT_CREATE_DATETIME
			)
		EXEC (@dynSQL)

		SET @dynSQL = ''
		-- *********************************************************************************
		--            FINAL CATEGORY LOGIC: CALL udf_final_category_Logic function
		-- *********************************************************************************
		SET @final_category = dbo.udf_psi_final_category_Logic(@var_session_uuid, @var_client_id)

		IF @debug > 0
			PRINT CHAR(13) + '@final_category: ' + @final_category;

		SET @update_final_category_logic = '
            UPDATE ' + @transaction_table_name_to_update + ' SET
                        PRIORITY_FINAL_CATEGORY_LOGIC = ''' + @final_category + '''
            WHERE
                        Client_ID = ' + CAST(@var_client_id AS VARCHAR(100)) + ' AND
                        SESSION_UUID  = ''' + CAST(@var_session_uuid AS VARCHAR(100)) + ''' AND
                        QUESTION_ID = 1731'
		IF @debug > 0
			PRINT CHAR(13) + 'update_final_category_logic: ' + @update_final_category_logic;

		EXEC (@update_final_category_logic);

		SET @update_final_category_logic = ''

		IF @debug > 0
			PRINT CHAR(13) + CHAR(13) + '@final_category completed from [usp_04_Emergency_&_Priority_Cases_With_No_F2f]';

		--GET ALL EXPLOITATION/Allegations
		SET @var_exploitation_type_non_financial_type = 0
		SET @var_exploitation_type_STUFF = '0'
		SET @var_exploitation_type_STUFF = (
				SELECT STUFF((
							SELECT DISTINCT ', ' + CAST(Choice_ID AS VARCHAR(255))
							FROM [Transaction_Table_Emergency_&_Priority_Cases_With_No_F2f_04]
							WHERE SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(100)) + ''
								AND QUESTION_ID = 4574
							FOR XML PATH('')
							), 1, 2, '')
				)

		IF (
				@var_exploitation_type_STUFF = 'NULL'
				OR @var_exploitation_type_STUFF IS NULL
				)
		BEGIN
			IF @debug > 0
				PRINT CHAR(13) + CHAR(13) + '@var_exploitation_type_STUFF 1 NULL-----+++';
		END
		ELSE
		BEGIN
			IF @debug > 0
				PRINT CHAR(13) + CHAR(13) + '@var_exploitation_type_STUFF 2 NOT  NULL';

			SET @var_exploitation_type_non_financial_type = CHARINDEX('8', @var_exploitation_type_STUFF)

			IF (@var_exploitation_type_non_financial_type > 0)
				SET @var_exploitation_type_non_financial_type = 0 --mean financial allegation present AS PER            -- @var_exploitation_type_non_financial_type = 0 )  -- 60-DAY COUNTDOWN LOGIC 
			ELSE
				SET @var_exploitation_type_non_financial_type = 1
		END

		IF @debug > 0
			PRINT CHAR(13) + CHAR(13) + '@var_exploitation_type_non_financial_type : ' + CAST(@var_exploitation_type_non_financial_type AS VARCHAR);

		--            ***************************************
		--            F2F LOGIC : CALL sp_f2f_Logic function
		--            ***************************************
		IF (
				@var_exploitation_type_STUFF = 'NULL'
				OR @var_exploitation_type_STUFF IS NULL
				)
		BEGIN
			SET @update_f2f_logic = '
					UPDATE ' + @transaction_table_name_to_update + ' SET
						DAY_BUCKET_TO_F2F =  '''',   
						RESPONSE_DAYS_F2F =  ''''
					WHERE
						Client_ID = ' + CAST(@var_client_id AS VARCHAR(100)) + ' AND
						SESSION_UUID  = ''' +  CAST(@var_session_uuid AS VARCHAR(100)) + ''' AND	
						QUESTION_ID = 1731'

			IF @debug > 0
				PRINT CHAR(13) + '@update_f2f_logic: ' + @update_f2f_logic;

			EXEC (@update_f2f_logic);

			SET @update_f2f_logic = ''

			IF @debug > 0
				PRINT CHAR(13) + CHAR(13) + 'usp_f2f_Logic completed from [usp_04_Emergency_&_Priority_Cases_With_No_F2f]';
		END
		ELSE
		BEGIN
			EXEC usp_psi_f2f_Logic @var_client_id
				,@var_session_uuid
				,@DAY_BUCKET_TO_F2F OUTPUT
				,@RESPONSE_DAYS_F2F OUTPUT
				,@table_name_to_update
				,@transaction_table_name_to_update
				,@final_category
				,@var_exploitation_type_STUFF
				,@var_exploitation_type_non_financial_type

			SET @update_f2f_logic = '
						UPDATE ' + @transaction_table_name_to_update + ' SET
								DAY_BUCKET_TO_F2F = ''' + @DAY_BUCKET_TO_F2F + ''' ,
								RESPONSE_DAYS_F2F = ''' + @RESPONSE_DAYS_F2F + ''' 
						WHERE
								Client_ID = ' + CAST(@var_client_id AS VARCHAR(100)) + 	' AND
								SESSION_UUID  = ''' + @var_session_uuid + ''' AND
								QUESTION_ID = 1731'
			IF @debug > 0
				PRINT CHAR(13) + '@update_f2f_logic: ' + @update_f2f_logic;

			EXEC (@update_f2f_logic);

			SET @update_f2f_logic = ''

			IF @debug > 0
				PRINT CHAR(13) + CHAR(13) + 'usp_f2f_Logic completed from [usp_04_Emergency_&_Priority_Cases_With_No_F2f]';
		END

		SET @update_client_record_processed = '
			UPDATE Temp_User_Record_Processed_04 SET
					Record_Processed = 1
			WHERE
					ID  = ' + CAST(@var_temp_id AS VARCHAR)

		IF @debug > 0
			PRINT '@update_client_record_processed: ' + @update_client_record_processed;

		EXEC (@update_client_record_processed);

		SET @update_client_record_processed = ''
		SET @loopVar = @loopVar + 1;
	END -- WHILE (@loopVar <= @totalNumberOfRecords)

	----***************************************************************************************************
	---- Transfer data to 04_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F
	----***************************************************************************************************
	SET @dynSQL = 	'
                             SELECT 
                            DISTINCT SESSION_UUID,
                            CLIENT_ID,                      
                            CONSUMER_NAME,          
                            SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER AS INVESTIGATOR_NAME_1A3,
                            [RON_DATE_1A1],  
                            ( 
								SELECT TOP 1
										PRIORITY_FINAL_CATEGORY_LOGIC
								FROM
										[Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04]  
								WHERE
										QUESTION_ID = 1731 AND
										SESSION_UUID = tt.SESSION_UUID          
                            ) AS PRIORITY,
                            ( 
                                SELECT TOP 1
                                            DAY_BUCKET_TO_F2F
                                FROM
                                        [Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04]  
                                WHERE
                                    QUESTION_ID = 1731 AND
                                    SESSION_UUID = tt.SESSION_UUID     
                            ) AS DAY_LEFT_TO_MAKE_F2F,                
                            INVESTIGATING_AGENCY_OR_PROVIDER_NAME,
                            AGENCY_NAME,
                            PROVIDER_NAME_AS_AGENCY_NAME,
                            ( 
								SELECT TOP 1
										RESPONSE_DAYS_F2F
								FROM
										[Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04]  
								WHERE
										QUESTION_ID = 1731 AND
										SESSION_UUID = tt.SESSION_UUID       
                            ) AS RESPONSE_DAYS_F2F,
                            ASSESSMENT_CREATE_DATETIME
              FROM
                [Transaction_Table_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F_04] tt
              WHERE
                   QUESTION_ID = 1731
              '

	IF @debug > 0
		PRINT CHAR(13) + CHAR(13) + 'INSERT INTO OUTPUT TABLE 04_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F: ' + @dynSQL;

	INSERT INTO [04_EMERGENCY_&_PRIORITY_CASES_WITH_NO_F2F]
	EXEC (@dynSQL)

	SET @dynSQL = ''

	EXEC usp_psi_05_Total_Investigations_By_County
END --MAIN
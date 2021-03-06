USE [idb_datastore]
GO
/****** Object:  StoredProcedure [dbo].[usp_psi_01_Abuse_And_Neglect_Cases]    Script Date: 6/13/2022 3:44:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[usp_psi_01_Abuse_And_Neglect_Cases]
AS
SET NOCOUNT ON 
SET ANSI_WARNINGS OFF
SET ANSI_NULLS ON 
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN  --MAIN
--************************************************************************************************************************
--EMPTYING OUT THE TABLES
--************************************************************************************************************************
	TRUNCATE TABLE [01_ABUSE_AND_NEGLECT_CASES]
	TRUNCATE TABLE Transaction_Table_Abuse_Neglect_Cases_01   
	TRUNCATE TABLE Temp_User_Record_Processed_01
	TRUNCATE TABLE Temp_Bucket_days	
	TRUNCATE TABLE Temp_Client_With_Multiple_SessionID
		
	DECLARE @loopVar INT
	DECLARE @loop_Temp_Bucket_days INT
	DECLARE @var_client_id INT
	DECLARE @var_QUESTION_ID INT
	DECLARE @var_Temp_Bucket_days_id INT	 
	DECLARE @totalNumberOfRecords INT
	DECLARE @totalNumberOfRecords_Temp_Bucket_days INT	
	DECLARE @var_exploitation_type_non_financial_type INT
	DECLARE @Determination_Complete_value INT 
	DECLARE @debug INT
	DECLARE @var_Temp_Bucket_days_Client_ID varchar(100)  
	DECLARE @update_client_record_processed  varchar(1000) 
	DECLARE @update_Temp_Bucket_days_processed  varchar(1000) 
	DECLARE @var_Temp_Bucket_days_SESSION_UUID varchar(1000) 
	DECLARE @var_number_of_days varchar(10)  
	DECLARE @calculate_var_number_of_days varchar(10)
	DECLARE @var_days_remaining_bucket_narrative varchar(250) 
	DECLARE @var_exploitation_type varchar(50) 
	DECLARE @var_temp_user_record_processed_id varchar(50)
	DECLARE @var_temp_user_record_processed_client_id  varchar(500)
	DECLARE @var_temp_user_record_processed_session_uuid varchar(1000)
	DECLARE @var_is_financial_type varchar(150)	
	DECLARE @var_exploitation_type_STUFF varchar(150)
	DECLARE @table_name_to_update VARCHAR(100) 
	DECLARE @transaction_table_name_to_update VARCHAR(100) 
	DECLARE @var_question_ids_TEMP varchar(500) 
	DECLARE @dynSQL varchar(MAX)
	DECLARE @processsing varchar(MAX) 
	DECLARE @determination_complete varchar(MAX) 
	DECLARE @chk_determination_not_complete varchar(MAX)   
	DECLARE @Questions_Without_Determination_Date varchar(MAX)  
	DECLARE @update_determination_Complete  NVARCHAR(MAX) 

	SET @debug  = 0 -- 1 YES/ 0 NO	 
	SET @loopVar = 1
	SET @loop_Temp_Bucket_days = 1   	

	SET @table_name_to_update =	'01_ABUSE_AND_NEGLECT_CASES'
	IF @debug > 0 PRINT CHAR(13) + 'table_name_to_update: ' +  @table_name_to_update;	

	SET @transaction_table_name_to_update =	'Transaction_Table_Abuse_Neglect_Cases_01'
	IF @debug > 0 PRINT CHAR(13) + '@transaction_table_name_to_update: ' +  @transaction_table_name_to_update;
	
--*****************************************************************************************************************************************************************************
-- CLIENT'S REQUIREMENT, IF THERE IS NO DEMOGRAPHIC_ENROLLMENT.ENROLLMENT_START_DATE THEN PUT SOME DUMMY DATE AS 01/01/1900
--******************************************************************************************************************************************************************************
	UPDATE Demographic_Enrollment SET 
		ENROLLMENT_START_DATE = (SELECT DateAdd(yy, -150, GetDate()))   -- -150 years, client asked to enter dummy date if ENROLLMENT_START_DATE is null or empty
	WHERE 
		(  
			 ENROLLMENT_START_DATE IS NULL OR 
			 ENROLLMENT_START_DATE = ''
		) 		
	SET @dynSQL = ''

--*********************************************************************
-- filter the list of client id which has multiple session_id 
--*********************************************************************
	SET @dynSQL = '
			SELECT   	 
					CLIENT_ID 
			FROM  
			 (
				SELECT  
						DISTINCT SESSION_UUID, CLIENT_ID 
				FROM
						Assessment
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
									(SESSION_DATE >= Demographic_Enrollment.ENROLLMENT_START_DATE) 
									
									AND 
									QUESTION_ID = 4574 AND 
									CHOICE_ID IN (''1'',''2'',''4'',''5'',''6'',''7'',''8'') 

					)
			 ) AS Q1
			GROUP BY
					CLIENT_ID
			HAVING 
					COUNT(CLIENT_ID) > 1 
	'
	IF @debug > 0 PRINT 'the list of client ids with the initial investigation having multiple session_id dynSQL: ' + @dynSQL; 

	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 127:'
	--RETURN

--***********************************************************************************
-- WE ARE INSERTING DATA IN "Temp_Client_With_Multiple_SessionID"
--**********************************************************************************
	INSERT INTO Temp_Client_With_Multiple_SessionID
	EXEC (@dynSQL)
	SET @dynSQL = ''

--************************************************************************************************************** 
-- GET THE LIST OF CLIENT IDS WITH THE INITIAL INVESTIGATION HAVING SINGLE  SESSION_ID
--*************************************************************************************************************** 
	SET @dynSQL = '	 
			SELECT  
					DISTINCT SESSION_UUID, CLIENT_ID, ''0'' AS RECORD_PROCESSED, 
					(SELECT QUESTION_ID FROM Assessment WHERE SESSION_UUID = a1.SESSION_UUID AND CLIENT_ID =a1.CLIENT_ID AND QUESTION_ID =1731) AS QUESTION_ID_1731
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
								
								AND 
								QUESTION_ID = 4574 AND 
								CHOICE_ID IN (''1'',''2'',''4'',''5'',''6'',''7'',''8'') 
					)	
					
					AND a1.CLIENT_ID NOT IN (SELECT client_id FROM Temp_Client_With_Multiple_SessionID) 
			
			ORDER BY 
					CLIENT_ID
		'
	IF @debug > 0 PRINT 'INSERT INTO Temp_User_Record_Processed_01 FROM QUERY OUTPUT dynSQL: ' + @dynSQL; 

	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - Temp_User_Record_Processed_01 LINE# 171:'
	--RETURN

--******************************************************************************************************************
-- WE ARE INSERTING DATA IN "Temp_User_Record_Processed_01" TABLE SO WE CAN LOOP OVER IT
--********************************************************************************************************************** 
	INSERT INTO Temp_User_Record_Processed_01
	EXEC (@dynSQL)
	SET @dynSQL = ''
		
	SET @totalNumberOfRecords = (SELECT COUNT(ID) FROM Temp_User_Record_Processed_01) 
	IF @debug > 0 PRINT CHAR(13)+'Total # of records in Temp_User_Record_Processed_01  = ' + CAST(@totalNumberOfRecords AS VARCHAR);	

	--************************************************************************************************
	--ADD ALL THE USERS WHO DOES NOT HAVE QUESTION ID 1731 IN THEIR PROFILE 
	--************************************************************************************************
	SET @dynSQL = '	 					
				SELECT 
						DISTINCT SESSION_UUID,
						CLIENT_ID, 
						''1731'' AS Question_ID, 
						''01/01/1900'' AS RESPONSE_DATA , 
						(SELECT TOP 1 FIRST_NAME +'' '' + LAST_NAME FROM [dbo].[Demographic_Enrollment] WHERE CLIENT_ID = T1.CLIENT_ID) as CONSUMER_NAME, 
						(SELECT TOP 1  SUBPROVIDER_NAME  FROM Assessment WHERE SESSION_UUID = T1.SESSION_UUID) as SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER,
						(SELECT TOP 1  AGENCY_NAME FROM Assessment WHERE SESSION_UUID = T1.SESSION_UUID) as AGENCY_NAME,
						(SELECT TOP 1  PROVIDER_NAME FROM Assessment WHERE SESSION_UUID = T1.SESSION_UUID) as PROVIDER_NAME_AS_AGENCY_NAME,
						(SELECT TOP 1  ASSESSOR_NAME FROM Assessment WHERE SESSION_UUID = T1.SESSION_UUID) as ASSESSOR_NAME,
							(SELECT TOP 1 CREATE_DATETIME FROM Assessment WHERE SESSION_UUID = T1.SESSION_UUID) AS CREATE_DATETIME  
				 FROM 
						Temp_User_Record_Processed_01 T1
				WHERE 
						 QUESTION_ID_1731  IS NULL
			' 
	IF @debug > 0 PRINT 'INSERT INTO Transaction_Table_Abuse_Neglect_Cases_01 FROM QUERY OUTPUT dynSQL: ' + @dynSQL; 
	--RETURN

	INSERT INTO Transaction_Table_Abuse_Neglect_Cases_01 (SESSION_UUID, CLIENT_ID, Question_ID, RESPONSE_DATA, Consumer_Name, SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER,
	AGENCY_NAME,	 PROVIDER_NAME_AS_AGENCY_NAME,  ASSESSOR_NAME, ASSESSMENT_CREATE_DATETIME)
	EXEC (@dynSQL)	
	SET @dynSQL = ''

	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - Transaction_Table_Abuse_Neglect_Cases_01 LINE# 234:'
    --RETURN 

--********************************************************
-- LOOP OVER Temp_User_Record_Processed_01
--********************************************************
 
	WHILE (@loopVar <= @totalNumberOfRecords) --using for determination_date_Logic
	BEGIN

			SET @var_temp_user_record_processed_id = (SELECT TOP(1) ID FROM Temp_User_Record_Processed_01 WHERE Record_Processed <> 1 )
			IF @debug > 0 PRINT @var_temp_user_record_processed_id;

			SET @var_client_id = (SELECT Client_ID FROM Temp_User_Record_Processed_01 WHERE ID = @var_temp_user_record_processed_id)
			IF @debug > 0 PRINT @var_client_id;

			SET @var_temp_user_record_processed_session_uuid = (SELECT SESSION_UUID FROM Temp_User_Record_Processed_01  WHERE ID = @var_temp_user_record_processed_id)
			IF @debug > 0 PRINT @var_temp_user_record_processed_session_uuid;
						 
			SET  @processsing =  'ID: ' + @var_temp_user_record_processed_id +'  |    SESSION_UUID: ' + @var_temp_user_record_processed_session_uuid +'   |    CLIENT_ID: ' + CAST(@var_client_id AS VARCHAR(100)) 
			IF @debug > 0 PRINT CHAR(13)+'Processsing: ' + @processsing ;

			--*************************************************************************************************************************
			-- COLLECT DATA FOR CLIENT ID AND DUMP INTO Transaction_Table_Abuse_Neglect_Cases_01
			--*************************************************************************************************************************		
			SET @dynSQL = '
				SELECT
						SESSION_UUID,
						Assessment.CLIENT_ID,
						FIRST_NAME + '' '' + LAST_NAME as ''Consumer_Name'',								
						QUESTION_ID, 
						Choice_ID, 
						RESPONSE_DATA,
						'''' AS Reason_Overdue,
						(
							SELECT TOP 1 
								CASE 
									WHEN RESPONSE_DATA != ''NULL'' OR RESPONSE_DATA IS NOT NULL OR RESPONSE_DATA <> '''' THEN
									PROVIDER_NAME
								ELSE
									AGENCY_NAME
								END
							FROM 
								Assessment 
							WHERE 
								QUESTION_ID = 10812 AND 
								Client_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + ''' AND 
								SESSION_UUID  = ''' + CAST(@var_temp_user_record_processed_session_uuid AS VARCHAR(150)) + '''
						) AS Investigating_Agency_OR_Provider_Name, 
						AGENCY_NAME,
						PROVIDER_NAME AS PROVIDER_NAME_AS_AGENCY_NAME,
						SUBPROVIDER_NAME AS SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER,
						ASSESSOR_NAME,								
						1 AS Determination_Complete,
						'''' AS NUMBER_OF_DAYS,			
						'''' AS CALCULATED_NUMBER_OF_DAYS,
						'''' AS DAYS_REMAINING_BUCKET_NARRATIVE,
						'''' AS EXPLOITATION_TYPE,
						'''' AS CALCULATED_NUMBER_OF_DAYS_FE,
						'''' AS DAYS_REMAINING_BUCKET_NARRATIVE_FE,
						'''' AS QUESTIONS_WITHOUT_DETERMINATION_DATE,
						'''' AS QUESTIONS_WITHOUT_DETERMINATION_DATE_ALL,
						'''' AS CATEGORY,
						'''' AS ENROLLMENT_START_DATE,
						'''' AS ENROLLMENT_TERMINATION_DATE,
						'''' AS CREATE_DATETIME,
						'''' AS FINAL_CATEGORY_LOGIC,
						'''' AS RESPONSE_DAYS_F2F,
						'''' AS DAY_BUCKET_TO_F2F,
						'''' AS DAYS_TO_DETERMINATION,
						'''' AS MEDICAL_DOCUMENTS
				FROM 
						Assessment 
				JOIN Demographic_Enrollment ON 
						Demographic_Enrollment.CLIENT_ID = Assessment.CLIENT_ID
				WHERE

						--Demographic_Enrollment.ENROLLMENT_STATUS = ''Active'' AND
						--Demographic_Enrollment.CARE_PROGRAM_NAME = ''Protective Services'' AND

						Assessment.CLIENT_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + ''' AND
						SESSION_UUID = ''' +  CAST(@var_temp_user_record_processed_session_uuid AS VARCHAR(150)) + ''' AND
						QUESTION_ID IN (4574, 1731, 16282, 10812) 
				ORDER BY 
						QUESTION_ID							 
				'
			IF @debug > 0 PRINT  CHAR(13) + CHAR(13) + 'dynSQL: ' + @dynSQL; 
			--RETURN

			INSERT INTO Transaction_Table_Abuse_Neglect_Cases_01 (
				SESSION_UUID, 
				Client_ID, 
				Consumer_Name, 
				QUESTION_ID, 
				Choice_ID, 
				RESPONSE_DATA,
				Reason_Overdue, 
				Investigating_Agency_OR_Provider_Name, 
				AGENCY_NAME, 
				PROVIDER_NAME_AS_AGENCY_NAME, 
				SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER, 
				ASSESSOR_NAME, 
				Determination_Complete,
				NUMBER_OF_DAYS,			
				CALCULATED_NUMBER_OF_DAYS,
				DAYS_REMAINING_BUCKET_NARRATIVE,
				EXPLOITATION_TYPE,
				CALCULATED_NUMBER_OF_DAYS_FE,
				DAYS_REMAINING_BUCKET_NARRATIVE_FE,
				QUESTIONS_WITHOUT_DETERMINATION_DATE,
				QUESTIONS_WITHOUT_DETERMINATION_DATE_ALL,
				CATEGORY,
				DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE,
				DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_TERMINATION_DATE,
				ASSESSMENT_CREATE_DATETIME,
				FINAL_CATEGORY_LOGIC,
				RESPONSE_DAYS_F2F,
				DAY_BUCKET_TO_F2F,
				DAYS_TO_DETERMINATION, 
				MEDICAL_DOCUMENTS) 
			EXEC (@dynSQL)
			SET @dynSQL = ''	

			IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 362:'
			--RETURN

		SET @debug  = 0 -- 1 YES/ 0 NO	 
		SET @var_exploitation_type_non_financial_type=0 
		SET @var_exploitation_type_STUFF = '0'

		SET  @var_exploitation_type_STUFF = 	 
		(
				SELECT 
						STUFF((SELECT DISTINCT ', ' + CAST (Choice_ID AS VARCHAR(255)) 
				FROM 
							--Transaction_Table_Open_Investigations_By_Person_Investigator_03 
							[dbo].[Transaction_Table_Abuse_Neglect_Cases_01]
				WHERE 
						SESSION_UUID = ''+@var_temp_user_record_processed_session_uuid+'' AND
						QUESTION_ID = 4574 
						FOR XML PATH('')),1,2,'')						
		)  

		IF (@var_exploitation_type_STUFF = 'NULL'  OR  @var_exploitation_type_STUFF IS NULL)   
			BEGIN
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_exploitation_type_STUFF  3 NULL-----+++';
			END
		ELSE
			BEGIN 
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_exploitation_type_STUFF 4 NOT  NULL'; 
						
						SET @var_exploitation_type_non_financial_type = CHARINDEX('8',@var_exploitation_type_STUFF)
						
						IF (@var_exploitation_type_non_financial_type > 0 )						
								SET @var_exploitation_type_non_financial_type  = 0	--0 means financial present AS PER 	-- @var_exploitation_type_non_financial_type = 0 )  -- 60-DAY COUNTDOWN LOGIC 
						ELSE	
								SET @var_exploitation_type_non_financial_type = 1	 
						
			END  
		IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_exploitation_type_non_financial_type : ' + CAST(@var_exploitation_type_non_financial_type AS VARCHAR); 


 
		--****************************************************************************************	
		--DETERMINATION DATE: 
		--*****************************************************************************************
		IF (@var_exploitation_type_STUFF = 'NULL'  OR  @var_exploitation_type_STUFF IS NULL)      	 
			BEGIN  		
					SET @update_determination_Complete = ' UPDATE '+@transaction_table_name_to_update +' SET
								Determination_Complete =  0,
								Questions_Without_Determination_Date =   ''QID 4574 or its choice ids are missing'',	
								Questions_Without_Determination_Date_All =  ''QID 4574 or its choice ids are missing'',  
								DAYS_REMAINING_BUCKET_NARRATIVE =  ''Allegations are missing'',
								REASON_OVERDUE =  	(
									SELECT
					 						STUFF((SELECT DISTINCT '', '' + CAST (Description AS varchar(1000)) 
									FROM 
											Reason_Overdue   
									WHERE
											'', ''+
											(
													SELECT
															STUFF((SELECT DISTINCT '', '' + CAST (CHOICE_ID AS varchar(1000))  
													FROM 
															Assessment  
													WHERE
															QUESTION_ID = 16282 AND  
															Client_ID = ' + CAST(@var_client_id AS VARCHAR(100)) + ' AND 
															SESSION_UUID  = ''' +@var_temp_user_record_processed_session_uuid + '''
															FOR XML PATH('''')),1,2,'''')
															
											) +'', '' LIKE '', ''+CAST(ID AS VARCHAR(255)) + '', ''
											FOR XML PATH('''')),1,2,'''')
								) 
						WHERE 
								QUESTION_ID = 1731 AND 
								Client_ID = ' +  CAST(@var_client_id AS VARCHAR(100)) + ' AND 
								SESSION_UUID = ''' + @var_temp_user_record_processed_session_uuid + '''
					'	
					IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + '@Questions_Without_Determination_Date usp_psi_03_Open_Investigations_By_Person_Investigator  LINE# 472: ' +  @Questions_Without_Determination_Date;		 
					--RETURN
	   	 
					EXEC (@update_determination_Complete); 
					SET @update_determination_Complete = '';  
			END 	

		ELSE 
			BEGIN				
				EXEC usp_psi_determination_date_Logic @var_client_id, @var_temp_user_record_processed_session_uuid, @table_name_to_update, @transaction_table_name_to_update, @var_exploitation_type_STUFF
			END
		IF @debug > 0 PRINT  CHAR(13) + CHAR(13) + 'usp_determination_date_Logic completed from usp_01_ABUSE_AND_NEGLECT_CASES';	 
		--RETURN
	SET @debug  = 0 -- 1 YES/ 0 NO	 

		SET @update_client_record_processed = '
				UPDATE Temp_User_Record_Processed_01 SET 
						Record_Processed = 1 
				WHERE ID  = ' + CAST(@var_temp_user_record_processed_id AS VARCHAR)
		IF @debug > 0 PRINT '@update_client_record_processed: ' +  @update_client_record_processed;
			
		EXEC (@update_client_record_processed);
		SET @update_client_record_processed = ''	
		
		SET @loopVar = @loopVar + 1; 
 		 
	END  -- WHILE (@loopVar <= @totalNumberOfRecords)	determination_date_Logic
			 
		
	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - 01_ABUSE_AND_NEGLECT_CASES LINE#405:'
	--RETURN 
 
--*************************************************************************************************************************
--BUILDING BUCKET LOGIC 
--INSERT DATA INTO Temp_Bucket_days SO WE CAN LOOP OVER IT AND GRAB THE DATE FOR RON
--*************************************************************************************************************************
	SET @chk_determination_not_complete = '
	SELECT 
			Client_ID, 
			SESSION_UUID, 
			QUESTION_ID,
			CASE
				WHEN RESPONSE_DATA != ''NULL'' OR RESPONSE_DATA IS NOT NULL OR RESPONSE_DATA <> '''' THEN RESPONSE_DATA
				ELSE ''01/01/1900''
			END AS RESPONSE_DATA,
			Determination_Complete,
			0 AS Record_Processed 
	FROM 
			 '+@transaction_table_name_to_update+' 
	WHERE
			QUESTION_ID = 1731 				 
	'
	IF @debug > 0 PRINT CHAR(13)+ 'GET QUESTION_ID 1731 RESPONSE_DATA TO DO DAY bucket: ' +  @chk_determination_not_complete;	 
	  
	INSERT INTO Temp_Bucket_days
	EXEC (@chk_determination_not_complete)
	SET @chk_determination_not_complete = '' 
 
	SET @totalNumberOfRecords_Temp_Bucket_days = (SELECT ISNULL(COUNT(ID), 0) FROM Temp_Bucket_days) 
	IF @debug > 0 PRINT CHAR(13)+ 'Total # of records in Temp_Bucket_days = ' + CAST(@totalNumberOfRecords_Temp_Bucket_days AS VARCHAR);
	
	--*********************************************************************************************************************************
	--LOOP OVER Temp_Bucket_days TABLE AND GENERATE VALUES FOR Days_Remaining_Bucket_Number, 
	--Number_Of_Days, Days_Remaining_Bucket AND UPDATE Transaction_Table_Abuse_Neglect_Cases_01
	--*********************************************************************************************************************************
 
	WHILE (@loop_Temp_Bucket_days <= @totalNumberOfRecords_Temp_Bucket_days)	
	BEGIN
			SET  @var_Temp_Bucket_days_id = (SELECT TOP 1 ID FROM Temp_Bucket_days WHERE Record_Processed <> 1)
			IF @debug > 0 PRINT '@var_Temp_Bucket_days_id: ' + CAST(@var_Temp_Bucket_days_id AS VARCHAR(250));

			SET  @var_Temp_Bucket_days_SESSION_UUID  = (SELECT SESSION_UUID FROM Temp_Bucket_days WHERE id = @var_Temp_Bucket_days_id)
			IF @debug > 0 PRINT '@var_Temp_Bucket_days_SESSION_UUID: ' + CAST(@var_Temp_Bucket_days_SESSION_UUID AS VARCHAR(250));

			SET  @var_Temp_Bucket_days_Client_ID  = (SELECT Client_ID FROM Temp_Bucket_days WHERE id = @var_Temp_Bucket_days_id)
			IF @debug > 0 PRINT '@var_Temp_Bucket_days_Client_ID: ' + CAST(@var_Temp_Bucket_days_Client_ID AS VARCHAR(250));
						
			SET  @Determination_Complete_value  = (SELECT Determination_Complete FROM Temp_Bucket_days WHERE id = @var_Temp_Bucket_days_id)
			IF @debug > 0 PRINT '@var_Temp_Bucket_days_Client_ID: ' + CAST(@var_Temp_Bucket_days_Client_ID AS VARCHAR(250));

	--	********************************************************************************		
	--GET ALL EXPLOITATION/Allegations
	--	********************************************************************************			
		SET @var_exploitation_type_non_financial_type=0 
		SET @var_exploitation_type_STUFF = '0'

		SET  @var_exploitation_type_STUFF = 	 
		(
				SELECT 
						STUFF((SELECT DISTINCT ', ' + CAST (Choice_ID AS VARCHAR(255)) 
				FROM 
							--Transaction_Table_Open_Investigations_By_Person_Investigator_03 
							[dbo].[Transaction_Table_Abuse_Neglect_Cases_01]
				WHERE 
						SESSION_UUID = ''+@var_Temp_Bucket_days_SESSION_UUID+'' AND
						QUESTION_ID = 4574 
						FOR XML PATH('')),1,2,'')						
		)  

		IF (@var_exploitation_type_STUFF = 'NULL'  OR  @var_exploitation_type_STUFF IS NULL)   
			BEGIN
					IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_exploitation_type_STUFF 1 NULL-----+++';
			END
		ELSE
			BEGIN 
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_exploitation_type_STUFF 2 NOT  NULL'; 
						
						SET @var_exploitation_type_non_financial_type = CHARINDEX('8',@var_exploitation_type_STUFF)
						
						IF (@var_exploitation_type_non_financial_type > 0 )						
								SET @var_exploitation_type_non_financial_type  = 0	--mean financial allegation present AS PER 	-- @var_exploitation_type_non_financial_type = 0 )  -- 60-DAY COUNTDOWN LOGIC 
						ELSE	
								SET @var_exploitation_type_non_financial_type = 1	 
						
			END  
		IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_exploitation_type_non_financial_type : ' + CAST(@var_exploitation_type_non_financial_type AS VARCHAR); 

		IF (@var_exploitation_type_STUFF = 'NULL'  OR  @var_exploitation_type_STUFF IS NULL)      	 
			BEGIN 
					IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  'DO NOT RUN Day bucket logic';
			END
		ELSE
			BEGIN 
				--	******************************************************************** 
				--	Day bucket logic: CALL sp_day_bucket_logic store proc
				--	******************************************************************** 
					EXEC usp_psi_day_bucket_logic @var_Temp_Bucket_days_Client_ID, @var_Temp_Bucket_days_SESSION_UUID, @table_name_to_update, @transaction_table_name_to_update, @var_exploitation_type_STUFF,  @var_exploitation_type_non_financial_type, @Determination_Complete_value
			END
		 
			IF @debug > 0 PRINT  CHAR(13) + CHAR(13) + 'usp_day_bucket_logic completed from Abuse_Neglect_Cases_01';	
					   
			SET @update_Temp_Bucket_days_processed = '
					UPDATE Temp_Bucket_days SET 
							Record_Processed = 1 
					WHERE 
							ID = ' + CAST(@var_Temp_Bucket_days_id AS VARCHAR)
			IF @debug > 0 PRINT 'Processsing: ' +  @update_Temp_Bucket_days_processed;
			
			EXEC (@update_Temp_Bucket_days_processed);
			SET @update_Temp_Bucket_days_processed = ''		

			SET @loop_Temp_Bucket_days = @loop_Temp_Bucket_days + 1;										
							
		END	--@loop_Temp_Bucket_days	
		
		--************************************************************ 
		-- Transfer data to 01_ABUSE_AND_NEGLECT_CASES
		--************************************************************ 
		INSERT INTO [01_ABUSE_AND_NEGLECT_CASES]
		SELECT  
			Client_ID AS SAMS_ID,
			Consumer_Name,
			SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER AS INVESTIGATOR_NAME_1A3,
			RESPONSE_DATA AS RON_DATE_1A1,				
			(
				SELECT	 
						STUFF((SELECT DISTINCT ', ' + CAST ([Description] AS VARCHAR(255))  
				FROM 
						Allegations
				WHERE 
						ID IN   
							(
								SELECT * 
								FROM
									[udf_psi_str_parse_8K](Exploitation_Type,',')
							) 
				FOR XML PATH('')),1,2,'') 
			) AS Allegations,							
			Calculated_Number_Of_Days AS DAYS_LEFT_TO_MAKE_DETERMINATION,
			Calculated_Number_Of_Days_FE AS DAYS_LEFT_TO_MAKE_DETERMINATION_FE,
			Reason_Overdue,	
			Exploitation_Type,	
			Questions_Without_Determination_Date,
			QUESTIONS_WITHOUT_DETERMINATION_DATE_ALL,
			Investigating_Agency_OR_Provider_Name,
			Number_Of_Days,		
			Days_Remaining_Bucket_Narrative,	
			Days_Remaining_Bucket_Narrative_FE, 
			SESSION_UUID, ASSESSMENT_CREATE_DATETIME
		FROM 
			Transaction_Table_Abuse_Neglect_Cases_01 
		WHERE 
			QUESTION_ID = 1731 		

		--********************************************************************************
		-- insert all the users with the initial investigation having multiple session_id 
		--********************************************************************************			
		INSERT INTO [01_ABUSE_AND_NEGLECT_CASES] 
		SELECT
			Client_ID AS SAMS_ID,
			'',
			'',
			'',			
			'',							
			'',
			'',
			'',	
			'',	
			'',
			'',
			'',
			'',		
			 'Multiple Initial Cases',	
			'', 
			'',
			''
		FROM
			Temp_Client_With_Multiple_SessionID
				EXEC usp_psi_02_Investigations_Missing_Initial_ISA	   
END  --MAIN

USE [idb_datastore]
GO
/****** Object:  StoredProcedure [dbo].[usp_psi_05_Total_Investigations_By_County]    Script Date: 6/13/2022 2:22:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
ALTER PROCEDURE [dbo].[usp_psi_05_Total_Investigations_By_County]
AS
SET ANSI_WARNINGS OFF
SET ANSI_NULLS ON 
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON 
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN  --MAIN
--************************************************************************************************************************
--EMPTYING OUT TABLES
--************************************************************************************************************************	
	TRUNCATE TABLE [05_TOTAL_INVESTIGATIONS_BY_COUNTY] 
	TRUNCATE TABLE Transaction_Table_Total_Investigations_by_county_05 	
	TRUNCATE TABLE Temp_User_Record_Processed_05
	TRUNCATE TABLE Temp_Bucket_days	 
	TRUNCATE TABLE Temp_Medical_Documents_Record_Processed
	TRUNCATE TABLE Transaction_Table_Medical_Documents_Record
			
	DECLARE @loopVar INT
	DECLARE @loop_Temp_Bucket_days INT
	DECLARE @var_client_id INT
	DECLARE @var_QUESTION_ID INT
	DECLARE @var_Temp_Bucket_days_id INT	 
	DECLARE @totalNumberOfRecords INT
	DECLARE @totalNumberOfRecords_Temp_Bucket_days INT	
	DECLARE @var_exploitation_type_non_financial_type INT
	DECLARE @var_Temp_Bucket_days_Client_ID VARCHAR(100)  
	DECLARE @update_client_record_processed VARCHAR(1000) 
	DECLARE @update_Temp_Bucket_days_processed VARCHAR(1000) 
	DECLARE @var_Temp_Bucket_days_SESSION_UUID VARCHAR(1000) 
	DECLARE @var_number_of_days VARCHAR(10)  
	DECLARE @calculate_var_number_of_days VARCHAR(10)
	DECLARE @var_days_remaining_bucket_narrative VARCHAR(250) 
	DECLARE @var_exploitation_type VARCHAR(50) 
	DECLARE @var_temp_id VARCHAR(50) 
	DECLARE @var_session_uuid VARCHAR(1000)
	DECLARE @var_is_financial_type VARCHAR(150)	
	DECLARE @var_exploitation_type_STUFF VARCHAR(100) 
	DECLARE @update_final_category_logic VARCHAR(500)
	DECLARE @final_category VARCHAR(500)   
	DECLARE @update_f2f_logic VARCHAR(500) 
	DECLARE @DAY_BUCKET_TO_F2F VARCHAR(100)
	DECLARE @RESPONSE_DAYS_F2F VARCHAR(100) 
	DECLARE @table_name_to_update VARCHAR(100) 
	DECLARE @transaction_table_name_to_update VARCHAR(100) 
	DECLARE @totalNumberOfRecords_medical_documents VARCHAR(1000) 
	DECLARE @loop_medical_documents VARCHAR(100) 		 
	DECLARE @dynSQL VARCHAR(MAX)
	DECLARE @processsing VARCHAR(MAX) 
	DECLARE @determination_complete VARCHAR(MAX) 
	DECLARE @chk_determination_not_complete VARCHAR(MAX)   
	DECLARE @Questions_Without_Determination_Date VARCHAR(MAX) 	
	DECLARE @Determination_Complete_value INT 
	DECLARE @debug INT
	DECLARE @update_determination_Complete  NVARCHAR(MAX) 
	 
	SET @debug  = 0 -- 1 YES/ 0 NO			 
	SET @loopVar = 1
	SET @loop_Temp_Bucket_days = 1  
	
	SET @table_name_to_update =	'[05_TOTAL_INVESTIGATIONS_BY_COUNTY]'
	IF @debug > 0 PRINT CHAR(13) + 'table_name_to_update: ' +  @table_name_to_update;	

	SET @transaction_table_name_to_update =	'Transaction_Table_Total_Investigations_By_County_05'
	IF @debug > 0 PRINT CHAR(13) + '@transaction_table_name_to_update: ' +  @transaction_table_name_to_update;	
  
--*****************************************************************************************************************************************************
--WE MAY NEED TO ENABLE THIS BELOW CONDITION IN THE SQL BELOW TO POPULATE TEMP TABLE AS WELL IF CLIENT ASKS
--*****************************************************************************************************************************************************
  
		SET @dynSQL = '	 
			SELECT  
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
	IF @debug > 0 PRINT CHAR(13) + CHAR(13) + 'INSERT INTO Temp_User_Record_Processed_05 FROM QUERY OUTPUT dynSQL: ' + @dynSQL; 
  	--RETURN
	
--*************************************************************************************
-- WE ARE INSERTING DATA IN "Temp_User_Record_Processed_05" TABLE SO WE CAN LOOP OVER IT
--*************************************************************************************	 	   
	INSERT INTO Temp_User_Record_Processed_05
	EXEC (@dynSQL)
	SET @dynSQL = ''
		
	SET @totalNumberOfRecords = (SELECT COUNT(ID) FROM Temp_User_Record_Processed_05) 
	IF @debug > 0 PRINT CHAR(13)+'Total # of records in Temp_User_Record_Processed_05  = ' + CAST(@totalNumberOfRecords AS VARCHAR);
	--RETURN


	--************************************************************************************************
--ADD ALL THE USERS WHO DOES NOT HAVE QUESTION ID 1731 IN THEIR PROFILE  
	--************************************************************************************************* 
	SET @dynSQL = '	
				SELECT 	
						DISTINCT SESSION_UUID, 
						CLIENT_ID, 
						''1731'' AS Question_ID, 
						''01/01/1900'' AS RESPONSE_DATA , 
						(SELECT TOP 1 FIRST_NAME +'' '' + LAST_NAME FROM [dbo].[Demographic_Enrollment] WHERE CLIENT_ID = T1.CLIENT_ID) as CONSUMER_NAME, 	
						
						(SELECT  TOP 1 
									CASE 
											WHEN PROVIDER_NAME = ''NULL'' OR PROVIDER_NAME IS NULL OR PROVIDER_NAME = '''' THEN			
											''Error – Missing Investigative Agency''
										ELSE
											PROVIDER_NAME
										END
								FROM 
										Assessment 
								WHERE 
										Client_ID = T1.CLIENT_ID AND 
										SESSION_UUID  =  T1.SESSION_UUID
						) AS PROVIDER_NAME_AS_AGENCY_NAME, 

						(SELECT  TOP 1 
								CASE 
										WHEN SUBPROVIDER_NAME = ''NULL'' OR SUBPROVIDER_NAME IS NULL OR SUBPROVIDER_NAME = '''' THEN			
										''Error – Missing Caseworker''
									ELSE
										SUBPROVIDER_NAME
									END
							FROM 
									Assessment 
							WHERE 
									Client_ID = T1.CLIENT_ID AND 
									SESSION_UUID  =  T1.SESSION_UUID
						) AS SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER,

						(SELECT TOP 1 AGENCY_NAME FROM Assessment WHERE SESSION_UUID = T1.SESSION_UUID) AS AGENCY_NAME,
						(SELECT TOP 1 ASSESSOR_NAME FROM Assessment WHERE SESSION_UUID = T1.SESSION_UUID) AS ASSESSOR_NAME,
						(SELECT TOP 1 ENROLLMENT_START_DATE FROM Demographic_Enrollment WHERE Client_ID =  T1.Client_ID) AS ENROLLMENT_START_DATE,
						(SELECT TOP 1 ENROLLMENT_TERMINATION_DATE FROM Demographic_Enrollment WHERE Client_ID =  T1.Client_ID) AS ENROLLMENT_TERMINATION_DATE,
						(SELECT TOP 1 CREATE_DATETIME FROM Assessment WHERE SESSION_UUID = T1.SESSION_UUID) AS CREATE_DATETIME   
			FROM 
						Temp_User_Record_Processed_05 T1
			WHERE 
					QUESTION_ID_1731  IS NULL
			' 
				 
	IF @debug > 0 PRINT 'INSERT INTO Transaction_Table_Total_Investigations_By_County_05 FROM QUERY OUTPUT dynSQL: ' + @dynSQL; 
	--RETURN

	INSERT INTO [Transaction_Table_Total_Investigations_By_County_05] (SESSION_UUID, CLIENT_ID, Question_ID, RESPONSE_DATA, Consumer_Name, PROVIDER_NAME_AS_AGENCY_NAME,
	SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER, AGENCY_NAME, ASSESSOR_NAME,  DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE, DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_TERMINATION_DATE, 
	ASSESSMENT_CREATE_DATETIME)
	EXEC (@dynSQL)
	
	SET @dynSQL = ''
	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - Transaction_Table_Total_Investigations_By_County_05 LINE# 255:'
	--RETURN
	   	 			
--*****************************************************************************************************************************************************************************
--LOOP OVER THE RECORDS, ONE CLIENT ID AT A TIME ONCE PROCESSES MARK Record_Processed TO 1 SO WE DO NOT USE IT AGAIN
--*****************************************************************************************************************************************************************************
	--WHILE (@loopVar <= 20)  --test
	WHILE (@loopVar <= @totalNumberOfRecords)
	BEGIN

			SET @var_temp_id = (SELECT TOP(1) ID FROM Temp_User_Record_Processed_05 WHERE Record_Processed <> 1)
			IF @debug > 0 PRINT CHAR(13) +  @var_temp_id;

			SET @var_client_id = (SELECT Client_ID FROM Temp_User_Record_Processed_05 WHERE ID = @var_temp_id)
			IF @debug > 0 PRINT CHAR(13) + CAST(@var_client_id AS VARCHAR(100)) ;

			SET @var_session_uuid = (SELECT SESSION_UUID FROM Temp_User_Record_Processed_05  WHERE ID = @var_temp_id)
			IF @debug > 0 PRINT CHAR(13)  + CAST(@var_session_uuid AS VARCHAR(100)) ;

			IF @debug > 0 PRINT CHAR(13) + 'Processsing: ' +  'ID: ' + @var_temp_id +'  |    SESSION_UUID: ' + CAST(@var_session_uuid AS VARCHAR(100))  +'   |    CLIENT_ID: ' + CAST(@var_client_id AS VARCHAR(100));

			--****************************************************************************************************************************
			-- COLLECT DATA FOR CLIENT ID AND DUMP INTO Transaction_Table_Total_Investigations_By_County_05
			--****************************************************************************************************************************			
			SET @dynSQL = '
				SELECT
					SESSION_UUID,
					Assessment.CLIENT_ID,
					FIRST_NAME + '' '' + LAST_NAME as ''Consumer_Name'',								
					QUESTION_ID, 
					CHOICE_ID, 
					RESPONSE_DATA,	
					'''' AS REASON_OVERDUE,
					'''' AS INVESTIGATING_AGENCY_OR_PROVIDER_NAME,
					AGENCY_NAME,
					(SELECT  TOP 1 
							CASE 
								WHEN PROVIDER_NAME = ''NULL'' OR PROVIDER_NAME IS NULL OR PROVIDER_NAME = '''' THEN			
								''Error – Missing Investigative Agency''
							ELSE
								PROVIDER_NAME
							END
						FROM 
							Assessment 
						WHERE 
							Client_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + ''' AND 
							SESSION_UUID  = ''' + @var_session_uuid + '''
					) AS PROVIDER_NAME_AS_AGENCY_NAME, 
					(SELECT  TOP 1 
							CASE 
								WHEN SUBPROVIDER_NAME = ''NULL'' OR SUBPROVIDER_NAME IS NULL OR SUBPROVIDER_NAME = '''' THEN			
								''Error – Missing Caseworker''
							ELSE
								SUBPROVIDER_NAME
							END
						FROM 
							Assessment 
						WHERE 
							Client_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + ''' AND 
							SESSION_UUID  = ''' + @var_session_uuid + '''
					) AS SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER, 
					ASSESSOR_NAME,								
					1 AS DETERMINATION_COMPLETE,
					'''' AS NUMBER_OF_DAYS,			
					'''' AS CALCULATED_NUMBER_OF_DAYS,
					'''' AS DAYS_REMAINING_BUCKET_NARRATIVE,
					'''' AS EXPLOITATION_TYPE,
					'''' AS CALCULATED_NUMBER_OF_DAYS_FE,
					'''' AS DAYS_REMAINING_BUCKET_NARRATIVE_FE,
					'''' AS QUESTIONS_WITHOUT_DETERMINATION_DATE,
					DEMOGRAPHIC_ENROLLMENT.ENROLLMENT_START_DATE,
					DEMOGRAPHIC_ENROLLMENT.ENROLLMENT_TERMINATION_DATE,
					ASSESSMENT.CREATE_DATETIME, 
					'''' AS FINAL_CATEGORY_LOGIC,
					'''' AS RESPONSE_DAYS_F2F,
					'''' AS DAY_BUCKET_TO_F2F,
					'''' AS DAYS_TO_DETERMINATION,
					'''' AS MEDICAL_DOCUMENTS, 
					'''' AS NUMBER_OF_DAYS_ELAPSED_MEDICAL_DOCUMENTS
				FROM 
					Assessment 
				JOIN Demographic_Enrollment ON 
					Demographic_Enrollment.CLIENT_ID = Assessment.CLIENT_ID
				WHERE

					--Demographic_Enrollment.ENROLLMENT_STATUS = ''Active'' AND
					--Demographic_Enrollment.CARE_PROGRAM_NAME = ''Protective Services'' AND

					Assessment.CLIENT_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + ''' AND
					SESSION_UUID = ''' +  @var_session_uuid + '''  AND
					QUESTION_ID IN (4574, 16130, 16127, 16129, 16155, 16128, 16149, 16126, 16152, 1731, 16282, 10812, 4072, 4730, 4455, 11489, 1145) -- need to limit the rows , as assessment table has tons of data for a user.
					 
				ORDER BY 
					QUESTION_ID							 
				'
		    IF @debug > 0 PRINT  CHAR(13) + CHAR(13) + 'dynSQL insert into [Transaction_Table_Total_Investigations_By_County_05] : ' + @dynSQL; 

			INSERT INTO [Transaction_Table_Total_Investigations_By_County_05]
				    (
					SESSION_UUID,
					CLIENT_ID,
					Consumer_Name,								
					QUESTION_ID, 
					CHOICE_ID, 
					RESPONSE_DATA, 
					REASON_OVERDUE, 
					INVESTIGATING_AGENCY_OR_PROVIDER_NAME,
					AGENCY_NAME,
					PROVIDER_NAME_AS_AGENCY_NAME,
					SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER,					
					ASSESSOR_NAME,								
					DETERMINATION_COMPLETE,
					NUMBER_OF_DAYS,			
					CALCULATED_NUMBER_OF_DAYS,
					DAYS_REMAINING_BUCKET_NARRATIVE,
					EXPLOITATION_TYPE,
					CALCULATED_NUMBER_OF_DAYS_FE,
					DAYS_REMAINING_BUCKET_NARRATIVE_FE,
					QUESTIONS_WITHOUT_DETERMINATION_DATE, 
					DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE,
					DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_TERMINATION_DATE,
					ASSESSMENT_CREATE_DATETIME,
					FINAL_CATEGORY_LOGIC,
					RESPONSE_DAYS_F2F,
					DAY_BUCKET_TO_F2F,
					DAYS_TO_DETERMINATION, 
					MEDICAL_DOCUMENTS,
					NUMBER_OF_DAYS_ELAPSED_MEDICAL_DOCUMENTS)
			EXEC (@dynSQL)
			SET @dynSQL = '' 
						 
		--	*************************************************************************************
		--	FINAL CATEGORY LOGIC: CALL udf_final_category_Logic function
		--	*************************************************************************************
			SET @final_category = dbo.udf_psi_final_category_Logic(@var_session_uuid, @var_client_id)

			SET @update_final_category_logic = '
				UPDATE '+@transaction_table_name_to_update+' SET 
					FINAL_CATEGORY_LOGIC = '''+ @final_category +''' 
				WHERE
					Client_ID = ' + CAST(@var_client_id AS VARCHAR(100)) + ' AND 
					SESSION_UUID  = ''' + @var_session_uuid + ''' AND 
					QUESTION_ID = 1731'
			IF @debug > 0 PRINT CHAR(13)+ 'update_final_category_logic: ' +  @update_final_category_logic;	
					   
			EXEC (@update_final_category_logic);
			SET @update_final_category_logic = ''
			IF @debug > 0 PRINT  CHAR(13) + CHAR(13) +  '@final_category completed from usp_05_Total_Investigations_By_County';	
			
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
							Transaction_Table_Total_Investigations_By_County_05 
				WHERE 
						SESSION_UUID = ''+@var_session_uuid+'' AND
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


		--****************************************************************************************	
		--DETERMINATION DATE:
		--*****************************************************************************************
				IF (@var_exploitation_type_STUFF = 'NULL'  OR  @var_exploitation_type_STUFF IS NULL)      	 
						BEGIN  						
								SET @update_determination_Complete = ' UPDATE '+@transaction_table_name_to_update +' SET
											Determination_Complete =  0,
											Questions_Without_Determination_Date =  ''QID 4574 or its choice ids are missing'',	
											Questions_Without_Determination_Date_All =  ''QID 4574 or its choice ids are missing'',  
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
																		SESSION_UUID  = ''' +@var_session_uuid + '''
																		FOR XML PATH('''')),1,2,'''')
															
														) +'', '' LIKE '', ''+CAST(ID AS VARCHAR(255)) + '', ''
														FOR XML PATH('''')),1,2,'''')
											) 
									WHERE 
											QUESTION_ID = 1731 AND 
											Client_ID = ' +  CAST(@var_client_id AS VARCHAR(100)) + ' AND 
											SESSION_UUID = ''' + @var_session_uuid + '''
								'	
								IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + '@Questions_Without_Determination_Date usp_psi_03_Open_Investigations_By_Person_Investigator  LINE# 472: ' +  @Questions_Without_Determination_Date;		 
								--RETURN
	   	 
								EXEC (@update_determination_Complete); 
								SET @update_determination_Complete = '';  
					END 	
			ELSE   	
				BEGIN
					 EXEC usp_psi_determination_date_Logic @var_client_id, @var_session_uuid, @table_name_to_update, @transaction_table_name_to_update, @var_exploitation_type_STUFF
						 IF @debug > 0 PRINT  CHAR(13) + CHAR(13) + 'usp_determination_date_Logic completed from usp_05_Total_Investigations_By_County';	
				END					 
				


		--	************************************************ 
		--	F2F LOGIC : CALL sp_f2f_Logic function
		--	************************************************* 
			IF (@var_exploitation_type_STUFF = 'NULL'  OR  @var_exploitation_type_STUFF IS NULL)      	 
				BEGIN  
					SET @update_f2f_logic = '
						UPDATE '+@transaction_table_name_to_update+' SET 
								--DAY_BUCKET_TO_F2F = ''Allegations are missing'',
								--RESPONSE_DAYS_F2F =  ''Allegations are missing'' 
								DAYS_REMAINING_BUCKET_NARRATIVE = ''Allegations are missing''
						WHERE
								Client_ID = ' + CAST(@var_client_id AS VARCHAR(100)) + ' AND 
								SESSION_UUID  = ''' + @var_session_uuid + ''' AND 
								QUESTION_ID = 1731'
					IF @debug > 0 PRINT CHAR(13)+ '@update_f2f_logic: ' +  @update_f2f_logic;	
			
					EXEC (@update_f2f_logic);
					SET @update_f2f_logic = ''
					SET  @var_exploitation_type_STUFF = ''
					SET @var_exploitation_type_non_financial_type = ''
				END
			  
			IF(1=1)
				BEGIN
							EXEC usp_psi_f2f_Logic @var_client_id, @var_session_uuid, @DAY_BUCKET_TO_F2F OUTPUT, @RESPONSE_DAYS_F2F OUTPUT, @table_name_to_update,  @transaction_table_name_to_update, @final_category, @var_exploitation_type_STUFF, @var_exploitation_type_non_financial_type
							SET @update_f2f_logic = '
									UPDATE '+@transaction_table_name_to_update+' SET 
											DAY_BUCKET_TO_F2F = '''+ @DAY_BUCKET_TO_F2F +''' , 
											RESPONSE_DAYS_F2F = '''+ @RESPONSE_DAYS_F2F +'''  
									WHERE
											Client_ID = ' + CAST(@var_client_id AS VARCHAR(100)) + ' AND 
											SESSION_UUID  = ''' + @var_session_uuid + ''' AND 
											QUESTION_ID = 1731'
							IF @debug > 0 PRINT CHAR(13)+ '@update_f2f_logic: ' +  @update_f2f_logic;	
			
							EXEC (@update_f2f_logic);
							SET @update_f2f_logic = ''
							SET  @var_exploitation_type_STUFF = ''
							SET @var_exploitation_type_non_financial_type = ''
				END
		    IF @debug > 0 PRINT  CHAR(13) + CHAR(13) + 'usp_f2f_Logic completed from usp_05_Total_Investigations_By_County';	
		

		
		--*********************************************************************************
		--Medical documents: CALL spMedical_documents store proc
		--*********************************************************************************
		EXEC usp_psi_medical_documents @var_client_id, @var_session_uuid, @table_name_to_update, @transaction_table_name_to_update 
		IF @debug > 0 PRINT  CHAR(13) + CHAR(13) + 'usp_medical_documents completed from usp_05_Total_Investigations_By_County';	

		SET @update_client_record_processed = '
			UPDATE Temp_User_Record_Processed_05 SET 
				Record_Processed = 1
			WHERE 
				ID  = ' + CAST(@var_temp_id AS VARCHAR)
			IF @debug > 0 PRINT '@update_client_record_processed: ' +  @update_client_record_processed;
		
		EXEC (@update_client_record_processed);
		SET @update_client_record_processed = ''		
		
		SET @loopVar = @loopVar + 1; 
 		 
	END  -- WHILE (@loopVar <= @totalNumberOfRecords)	

----******************************************************************************************************************
----BUILDING BUCKET LOGIC
----INSERT DATA INTO Temp_Bucket_days SO WE CAN LOOP OVER IT AND GRAB THE RON DATE
----*******************************************************************************************************************
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
	IF @debug > 0 PRINT  CHAR(13) + CHAR(13) +  'GET QUESTION_ID 1731 RESPONSE_DATA TO DO DAY bucket:' +  @chk_determination_not_complete;	
	  
	INSERT INTO Temp_Bucket_days
	EXEC (@chk_determination_not_complete)
	SET @chk_determination_not_complete = '' 
 
	SET @totalNumberOfRecords_Temp_Bucket_days = (SELECT ISNULL(COUNT(ID), 0) FROM Temp_Bucket_days) 
	IF @debug > 0 PRINT CHAR(13)+ 'Total # of records in Temp_Bucket_days = ' + CAST(@totalNumberOfRecords_Temp_Bucket_days AS VARCHAR);
	
--*********************************************************************************************************************************************
--LOOP OVER Temp_Bucket_days TABLE AND GENERATE VALUES FOR Days_Remaining_Bucket_Number, 
--Number_Of_Days, Days_Remaining_Bucket AND UPDATE Transaction_Table_Total_Investigations_By_County_05
--********************************************************************************************************************************************* 
	WHILE (@loop_Temp_Bucket_days <= @totalNumberOfRecords_Temp_Bucket_days)	 
	BEGIN
			SET  @var_Temp_Bucket_days_id = (SELECT TOP 1 ID FROM Temp_Bucket_days WHERE Record_Processed <> 1)
			IF @debug > 0 PRINT '@var_Temp_Bucket_days_id: ' + CAST(@var_Temp_Bucket_days_id AS VARCHAR(250));

			SET  @var_Temp_Bucket_days_SESSION_UUID  = (SELECT SESSION_UUID FROM Temp_Bucket_days WHERE ID = @var_Temp_Bucket_days_id)
			IF @debug > 0 PRINT '@var_Temp_Bucket_days_SESSION_UUID: ' + CAST(@var_Temp_Bucket_days_SESSION_UUID AS VARCHAR(250));

			SET  @var_Temp_Bucket_days_Client_ID  = (SELECT Client_ID FROM Temp_Bucket_days WHERE ID = @var_Temp_Bucket_days_id)
			IF @debug > 0 PRINT '@var_Temp_Bucket_days_Client_ID: ' + CAST(@var_Temp_Bucket_days_Client_ID AS VARCHAR(250));

			SET  @Determination_Complete_value  = (SELECT Determination_Complete FROM Temp_Bucket_days WHERE id = @var_Temp_Bucket_days_id)
			IF @debug > 0 PRINT '@var_Temp_Bucket_days_Client_ID: ' + CAST(@var_Temp_Bucket_days_Client_ID AS VARCHAR(250));

		--*************************************************************************
		--GET ALL EXPLOITATION/Allegations
		--*************************************************************************
        SET @var_exploitation_type_non_financial_type=0 
		SET @var_exploitation_type_STUFF = '0'

		SET  @var_exploitation_type_STUFF = 	 
		(
				SELECT 
						STUFF((SELECT DISTINCT ', ' + CAST (Choice_ID AS VARCHAR(255)) 
				FROM 
							Transaction_Table_Total_Investigations_By_County_05 
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
						--	*************************************************************************************
						--	Day bucket logic: CALL sp_day_bucket_logic store proc
						--	*************************************************************************************
						EXEC usp_psi_day_bucket_logic @var_Temp_Bucket_days_Client_ID, @var_Temp_Bucket_days_SESSION_UUID, @table_name_to_update, @transaction_table_name_to_update, @var_exploitation_type_STUFF,  @var_exploitation_type_non_financial_type , @Determination_Complete_value
					END
		 
			IF @debug > 0 PRINT  CHAR(13) + CHAR(13) + 'usp_day_bucket_logic completed  from usp_05_Total_Investigations_By_County';	
					   
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
		
----**********************************************************************************
---- Transfer data to 05_TOTAL_INVESTIGATIONS_BY_COUNTY
----**********************************************************************************

	SET @dynSQL = '
		SELECT  
			DISTINCT SESSION_UUID,
			CLIENT_ID,		
			CONSUMER_NAME,	
			DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE,
			ABS(DATEDIFF(DAY, CAST(GETDATE() AS DATE), DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE)) AS DAYS_ACTIVE,
			(SELECT TOP 1 FINAL_CATEGORY_LOGIC  FROM Transaction_Table_Total_Investigations_By_County_05 	WHERE 	QUESTION_ID = 1731 AND SESSION_UUID = tt.SESSION_UUID) AS CATEGORY,
			(SELECT  TOP 1 	DAY_BUCKET_TO_F2F FROM 	Transaction_Table_Total_Investigations_By_County_05 WHERE QUESTION_ID = 1731 AND 	SESSION_UUID = tt.SESSION_UUID) AS DAY_TO_F2F,
			(SELECT TOP 1  DAYS_REMAINING_BUCKET_NARRATIVE FROM Transaction_Table_Total_Investigations_By_County_05 	WHERE 	QUESTION_ID = 1731 AND SESSION_UUID = tt.SESSION_UUID) AS DAYS_LEFT_TO_MAKE_A_DETERMINATION,		
			(SELECT TOP 1 DAYS_REMAINING_BUCKET_NARRATIVE_FE FROM Transaction_Table_Total_Investigations_By_County_05 	WHERE 	QUESTION_ID = 1731 AND SESSION_UUID = tt.SESSION_UUID) AS DAYS_LEFT_TO_MAKE_A_DETERMINATION_FE,
			MEDICAL_DOCUMENTS, 
			AGENCY_NAME,
			PROVIDER_NAME_AS_AGENCY_NAME,
			SUBPROVIDER_NAME_INVESTIGATOR_CASEWORKER,
			ASSESSOR_NAME,
			(SELECT TOP 1 	RESPONSE_DAYS_F2F 	FROM Transaction_Table_Total_Investigations_By_County_05 WHERE QUESTION_ID = 1731 AND SESSION_UUID = tt.SESSION_UUID) AS RESPONSE_DAYS_F2F,
			(SELECT TOP 1  DAYS_TO_DETERMINATION FROM Transaction_Table_Total_Investigations_By_County_05 WHERE QUESTION_ID = 1731 AND 	SESSION_UUID = tt.SESSION_UUID) AS DAYS_TO_DETERMINATION,
			(SELECT TOP 1 CALCULATED_NUMBER_OF_DAYS FROM Transaction_Table_Total_Investigations_By_County_05 	WHERE 	QUESTION_ID = 1731 AND SESSION_UUID = tt.SESSION_UUID) AS CALCULATED_NUMBER_OF_DAYS,
			(SELECT TOP 1 CALCULATED_NUMBER_OF_DAYS_FE  FROM Transaction_Table_Total_Investigations_By_County_05 	WHERE QUESTION_ID = 1731 AND SESSION_UUID = tt.SESSION_UUID) AS CALCULATED_NUMBER_OF_DAYS_FE,	
			'''' AS NUMBER_OF_DAYS_ELAPSED_MEDICAL_DOCUMENTS, 
			[ASSESSMENT_CREATE_DATETIME]
	FROM 
		Transaction_Table_Total_Investigations_By_County_05 tt
	WHERE
		QUESTION_ID = 1731
	'
	IF @debug > 0 PRINT CHAR(13) + CHAR(13) + 'INSERT INTO OUTPUT TABLE Transaction_Table_Total_Investigations_By_County_05: ' + @dynSQL ;
	
	INSERT INTO [05_Total_Investigations_By_County]
	EXEC (@dynSQL)
	SET @dynSQL = ''


	--******************************************************************************************************************************************************************************* 
	-- insert all the users with the initial investigation having multiple session_id, no need to capture sesssion_id because user has multiple sessions
	--********************************************************************************	*********************************************************************************************** 
	INSERT INTO [05_Total_Investigations_By_County] 
	SELECT
		'',
		Client_ID AS SAMS_ID,
		'',
		'',
		'',			
		'',							
		'',
		'Multiple Initial Cases',
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
		''
	FROM
		Temp_Client_With_Multiple_SessionID

END  --MAIN

USE [idb_datastore]
GO
/****** Object:  StoredProcedure [dbo].[usp_psi_02_Investigations_Missing_Initial_ISA]    Script Date: 6/13/2022 2:21:14 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[usp_psi_02_Investigations_Missing_Initial_ISA]
AS
SET ANSI_WARNINGS OFF
SET ANSI_NULLS ON 
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON 
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN  
	TRUNCATE TABLE [02_Investigations_Missing_Initial_ISA]  
	TRUNCATE TABLE Temp_User_Record_Processed_02
	
	DECLARE @loopVar int 
	DECLARE @var_client_id int 	
	DECLARE @totalNumberOfRecords int   
	DECLARE @var_temp_user_record_processed_id varchar(50)	 
	DECLARE @dynSQL varchar(MAX) 
	DECLARE @processsing varchar(MAX)  
	DECLARE @enrollment_start_date_and_care_plan_start_date_matches varchar(MAX)
	DECLARE @update_client_record_processed varchar(MAX)
	DECLARE @todays_date DATE
	DECLARE @enrollment_start_date DATE
	DECLARE @number_of_days_active varchar(50)  
	DECLARE @debug INT
	 
	SET @debug  = 0-- 1 YES/ 0 NO

	SET @todays_date = (SELECT CAST(GETDATE() AS DATE))	
	SET @enrollment_start_date = (SELECT CAST(GETDATE() AS DATE))
	SET @loopVar = 1	 

---***************************************************************************************************************************************************************************************************
-- CREATE DYNAMIC QUERY TO SELECT THE RELEVANT DATA BASED ON THE CONDITION GIVEN IN WORD DOCUMENT FOR 02_INVESTIGATIONS_MISSING_INITIAL_ISA  	
--************************************************************************************************************************************************************************************************* 

	SET @dynSQL = '	 
		SELECT  
				DISTINCT SESSION_UUID, CLIENT_ID, ''0'' AS RECORD_PROCESSED
		FROM
				Assessment
		WHERE 

			--	QUESTION_ID = 1145 AND 
			--	RESPONSE_DATA = ''19'' AND

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
				
				--AND Assessment.CLIENT_ID NOT IN (SELECT client_id FROM Temp_Client_With_Multiple_SessionID) 

		ORDER BY 
			CLIENT_ID
	'
	IF @debug > 0 PRINT 'dynSQL: INSERT INTO Temp_User_Record_Processed_02 FROM QUERY OUTPUT' + @dynSQL;
	
--*************************************************************************************
-- INSERTING DATA IN "Temp_User_Record_Processed 02" TABLE SO WE CAN LOOP OVER IT
--*************************************************************************************	 	   
	INSERT INTO Temp_User_Record_Processed_02
	EXEC (@dynSQL) 	 
	SET @dynSQL = ''
		   	 
	SET @dynSQL = '
				SELECT 
						SESSION_UUID, 
						Client_ID AS SAMS_ID,	 
						[Consumer Name],
						ISA_MISSING,
						AGENCY_NAME, 
						CARE_PLAN_CARE_MANAGER,	
						ASSESSMENT_CREATE_DATETIME,
						DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE,
						DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_TERMINATION_DATE,
						CAREPLAN_SERVICEPLAN_CARE_PLAN_START_DATE,	
						0 AS ENROLLMENT_START_DATE_AND_CARE_PLAN_START_DATE_MATCHES,	
						0 AS NUMBER_OF_DAYS_ACTIVE,
						0 AS RECORD_PROCESSED			
				FROM (
							SELECT 
									Assessment.CLIENT_ID,
									SESSION_UUID,												
									Demographic_Enrollment.FIRST_NAME + '' ''+ Demographic_Enrollment.LAST_NAME  AS ''Consumer Name'',

									CASE
											WHEN 
												ISNULL((
														SELECT 
															CLIENT_ID 
														FROM
															Assessment a
														WHERE 
															QUESTION_ID = 1145 AND RESPONSE_DATA = ''19'' AND 
															a.SESSION_UUID = Assessment.SESSION_UUID
														),	0) = 0 
												THEN
														1 --MISSING AS NO DATA RETURN FROM ABOVE QUERY
										ELSE 
												0
									END AS ISA_MISSING,


									AGENCY_NAME, 


									(
											SELECT TOP 1 
													CARE_PLAN_CARE_MANAGER 
											FROM 
													CarePlan_ServicePlan 
											WHERE
													CLIENT_ID = Demographic_Enrollment.CLIENT_ID AND
													CARE_PLAN_CARE_MANAGER_IS_PRIMARY = ''Y'' AND
													CARE_PLAN_STATUS = ''Active''
									) AS CARE_PLAN_CARE_MANAGER,				 


									ASSESSMENT.CREATE_DATETIME as ASSESSMENT_CREATE_DATETIME,
									DEMOGRAPHIC_ENROLLMENT.ENROLLMENT_START_DATE as  DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE,
									DEMOGRAPHIC_ENROLLMENT.ENROLLMENT_TERMINATION_DATE as DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_TERMINATION_DATE,

									(
										SELECT TOP 1 
												CARE_PLAN_START_DATE 
										FROM 
												CarePlan_ServicePlan 
										WHERE 
												CLIENT_ID = Demographic_Enrollment.CLIENT_ID AND 
												CARE_PLAN_CARE_MANAGER_IS_PRIMARY = ''Y'' AND 
												CARE_PLAN_STATUS = ''Active''
									) AS CAREPLAN_SERVICEPLAN_CARE_PLAN_START_DATE,			 

									ROW_NUMBER() OVER ( PARTITION BY Demographic_Enrollment.CLIENT_ID ORDER BY CREATE_DATETIME asc) AS rn
							FROM
									Demographic_Enrollment 
							JOIN Assessment ON 
									Demographic_Enrollment.CLIENT_ID = Assessment.CLIENT_ID 		 
							WHERE 			 
									Demographic_Enrollment.ENROLLMENT_STATUS = ''Active'' AND 
									Demographic_Enrollment.CARE_PROGRAM_NAME = ''Protective Services'' AND
									Assessment.ASSESSFORM_FILENAME LIKE ''%PS Investigation.afm%'' AND									 
									(Assessment.CREATE_DATETIME >= Demographic_Enrollment.ENROLLMENT_START_DATE) AND 
									QUESTION_ID IN (4574, 16130, 16127, 16129, 16155, 16128, 16149, 16126, 16152, 1731, 16282, 10812, 4072, 4730, 4455, 11489, 1145) -- need to limit the rows , as assessment table has tons of data for a user.
 						) AS q2
				WHERE 
					q2.rn = 1 AND 
					SESSION_UUID IN (SELECT SESSION_UUID FROM [dbo].[Temp_User_Record_Processed_02])					 
				ORDER BY 
					CLIENT_ID   		 

	'
	IF @debug > 0 PRINT 'dynSQL: ' + @dynSQL ;
	IF @debug > 0 PRINT CHAR(13)+ 'INSERT INTO [02_Investigations_Missing_Initial_ISA] FROM QUERY OUTPUT ';
	--RETURN  


	INSERT INTO [02_Investigations_Missing_Initial_ISA]
	EXEC (@dynSQL) 	 
	SET @dynSQL = ''

	SET @totalNumberOfRecords = (SELECT COUNT(ID) FROM Temp_User_Record_Processed_02) 
	IF @debug > 0 PRINT CHAR(13)+'TOTAL # OF RECORDS IN Temp_User_Record_Processed  = ' + CAST(@totalNumberOfRecords AS VARCHAR);
--****************************************************************************************************************************************
--IF "ENROLLMENT_START_DATE" EXACTLY MATCHES WITH "CARE_PLAN_START_DATE" THEN ENROLLMENT_START_DATE_AND_CARE_PLAN_START_DATE_MATCHES = 1	
--****************************************************************************************************************************************
		SET @dynSQL = '
						UPDATE [02_Investigations_Missing_Initial_ISA] SET 
							 ENROLLMENT_START_DATE_AND_CARE_PLAN_START_DATE_MATCHES = 1
					   WHERE  						
						  DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE = CAREPLAN_SERVICEPLAN_CARE_PLAN_START_DATE
					'
		IF @debug > 0 PRINT CHAR(13)+ 'Enrollment_start_date_and_care_plan_start_date MATCHES: ' +  @dynSQL;	
		EXEC (@dynSQL);
		SET @dynSQL = '' 

--****************************************************************************************************************************************
--IF "ENROLLMENT_START_DATE" EXACTLY DOES NOT MATCHES WITH "CARE_PLAN_START_DATE"  THEN CARE_PLAN_CARE_MANAGER = 'Unassigned Caseworker'
--****************************************************************************************************************************************
		SET @dynSQL = '
							UPDATE [02_Investigations_Missing_Initial_ISA] SET 
									CARE_PLAN_CARE_MANAGER = ''Unassigned Caseworker''							
							WHERE 
									ISA_MISSING = 1 AND  
									(
										(CAREPLAN_SERVICEPLAN_CARE_PLAN_START_DATE <> DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE) OR 
										(CAREPLAN_SERVICEPLAN_CARE_PLAN_START_DATE IS NULL)
									)
						'	
		IF @debug > 0 PRINT CHAR(13)+ 'CARE_PLAN_CARE_MANAGER as UNASSIGNED CASEWORKER: ' +  @dynSQL;	
		EXEC (@dynSQL);
		SET @dynSQL = ''
--*********************************************************************************************************************
--LOOP OVER THE RECORDS, ONE CLIENT ID AT A TIME, ONCE PROCESSES MARKED Record_Processed TO 1 SO WE DO NOT USE IT AGAIN
--*********************************************************************************************************************
	WHILE (@loopVar <= @totalNumberOfRecords)	
	BEGIN

	--SET @debug  = 1  -- 1 YES/ 0 NO

			SET @var_temp_user_record_processed_id = (SELECT TOP(1) ID FROM Temp_User_Record_Processed_02 WHERE Record_Processed <> 1)			
			IF @debug > 0 PRINT CHAR(13) + 'var_temp_user_record_processed_id: ' + @var_temp_user_record_processed_id;

			SET @var_client_id = (SELECT CLIENT_ID FROM Temp_User_Record_Processed_02 WHERE ID = @var_temp_user_record_processed_id)			
			IF @debug > 0 PRINT CHAR(13) + 'var_client_id: ' + CAST(@var_client_id AS VARCHAR(100));
 
			IF @debug > 0 PRINT CHAR(13) + 'ID: ' + @var_temp_user_record_processed_id +'  |   CLIENT_ID: ' + CAST(@var_client_id AS VARCHAR(100));		

--*******************************************************************************************************************
-- UPDATE NUMBER_OF_DAYS_ACTIVE  IN [02_Investigations_Missing_Initial_ISA] FOR CLIENT_ID 
--*******************************************************************************************************************
			SET @enrollment_start_date = (SELECT TOP 1 DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE FROM [02_Investigations_Missing_Initial_ISA] WHERE SAMS_ID =  CAST(@var_client_id AS VARCHAR(100))) 	

			IF @debug > 0 PRINT @enrollment_start_date;
			IF @debug > 0 PRINT @todays_date;  

			SET @number_of_days_active =  (CAST(DATEDIFF(DAY,   CAST(@todays_date AS date),   CAST(@enrollment_start_date AS date)) AS VARCHAR(100)))
			IF @debug > 0 PRINT @number_of_days_active;			 

			SET @dynSQL = '
							UPDATE [02_Investigations_Missing_Initial_ISA] SET  						
									NUMBER_OF_DAYS_ACTIVE = ' +  CAST(@number_of_days_active AS VARCHAR(100))  +'
							WHERE 
									--ISA_MISSING = 1 AND 
									SAMS_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + ''' 
									--AND
									--(
									--	(CAREPLAN_SERVICEPLAN_CARE_PLAN_START_DATE <> DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE) OR 
									--	(CAREPLAN_SERVICEPLAN_CARE_PLAN_START_DATE IS NULL)
									--)
							'	
				IF @debug > 0 PRINT CHAR(13)+ 'UPDATE NUMBER_OF_DAYS_ACTIVE: ' +  @dynSQL;	
--SET @debug  = 0  -- 1 YES/ 0 NO

				EXEC (@dynSQL);
				SET @dynSQL = ''

--*******************************************************************************************************
-- UPDATE CARE PLAN CARE MANAGER IN [02_Investigations_Missing_Initial_ISA] FOR CLIENT_ID 
--*******************************************************************************************************
			SET @dynSQL = '
								UPDATE [02_Investigations_Missing_Initial_ISA] SET 
									CARE_PLAN_CARE_MANAGER = (
											SELECT TOP 1
												CARE_PLAN_CARE_MANAGER
											FROM 
												CarePlan_ServicePlan 
											WHERE 
												Client_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + ''' AND
												CARE_PLAN_CARE_MANAGER_IS_PRIMARY = ''Y'' AND
												CARE_PLAN_STATUS = ''Active''
										)
								WHERE 
									ISA_MISSING = 1 AND 
									(DEMOGRAPHIC_ENROLLMENT_ENROLLMENT_START_DATE = CAREPLAN_SERVICEPLAN_CARE_PLAN_START_DATE) AND  
									SAMS_ID = ''' + CAST(@var_client_id AS VARCHAR(100)) + ''' 
					'
				IF @debug > 0 PRINT CHAR(13)+ 'UPDATE CARE PLAN CARE MANAGER: ' +  @dynSQL;	
				EXEC (@dynSQL);
				SET @dynSQL = ''

			SET @update_client_record_processed = '
					UPDATE Temp_User_Record_Processed_02 SET 
							Record_Processed = 1 
					WHERE 
							ID  = ' + CAST(@var_temp_user_record_processed_id AS VARCHAR)
			IF @debug > 0 PRINT 'update_client_record_processed: ' +  @update_client_record_processed;		
			EXEC (@update_client_record_processed);
			SET @update_client_record_processed = ''	
		
			SET @loopVar = @loopVar + 1; 
 	
	END  -- WHILE (@loopVar <= @totalNumberOfRecords)	
	EXEC usp_psi_03_Open_Investigations_By_Person_Investigator
END

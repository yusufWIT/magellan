USE [idb_datastore]
GO
/****** Object:  StoredProcedure [dbo].[usp_psi_medical_documents]    Script Date: 6/13/2022 2:24:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
ALTER PROCEDURE [dbo].[usp_psi_medical_documents] 

@var_client_id NVARCHAR(50), 
@var_session_uuid NVARCHAR(150),
@table_name_to_update NVARCHAR(150),
@transaction_table_name_to_update NVARCHAR(150)
AS
SET NOCOUNT ON 
SET ANSI_WARNINGS OFF
SET ANSI_NULLS ON 
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN      
	DECLARE @var_medical_document_message NVARCHAR(750)
	DECLARE @med_requested_sets NVARCHAR(750)
	DECLARE @med_received_sets NVARCHAR(750)
	DECLARE @var_careplan_uuid NVARCHAR(150) 
	DECLARE @dynSQL_temp_medical_documents VARCHAR(MAX) 
	DECLARE @var_update_medical_documents VARCHAR(MAX) 
	DECLARE @update_Temp_Medical_Documents_Record_Processed VARCHAR(MAX) 
	DECLARE @med_set_1_req_count INT 
	DECLARE @med_set_1_rec_count INT 
	DECLARE @med_set_2_req_count INT 
	DECLARE @med_set_2_rec_count INT 
	DECLARE @med_set_3_req_count INT 
	DECLARE @med_set_3_rec_count INT 	
	DECLARE @var_temp_id INT 		
	DECLARE @loopVar INT
	DECLARE @debug INT
	DECLARE @skip_processing INT			
	DECLARE @med_set_1_req INT	
	DECLARE @med_set_1_rec INT 
	DECLARE @med_number_of_days_1 INT 
	DECLARE @med_set_2_req INT 
	DECLARE @med_set_2_rec INT 
	DECLARE @med_number_of_days_2 INT 
	DECLARE @med_set_3_req INT 
	DECLARE @med_set3_rec INT 
	DECLARE @med_number_of_days_3 INT  
	DECLARE @totalnumberofrecords_temp_medical_documents INT 
	DECLARE @var_set_req INT
	DECLARE @var_set_rec INT
	DECLARE @entry_datetime_med_set_1_req DATETIME
	DECLARE @entry_datetime_med_set_1_recd DATETIME
	DECLARE @entry_datetime_med_set_2_req DATETIME
	DECLARE @entry_datetime_med_set_2_recd DATETIME 
	DECLARE @entry_datetime_med_set_3_req DATETIME 		
	DECLARE @entry_datetime_med_set_3_recd DATETIME  	
	   	  
	SET @debug  = 0 -- 1 YES/ 0 NO
	SET @skip_processing  = 0 -- 1 YES/ 0 NO 	
	SET @med_set_1_req_count = 0
	SET @med_set_1_rec_count = 0
	SET @med_set_2_req_count = 0
	SET @med_set_2_rec_count = 0
	SET @med_set_3_req_count = 0
	SET @med_set_3_rec_count = 0
	SET @var_set_req = 0
	SET @var_set_rec = 0
	SET @loopVar = 1  
	SET @med_requested_sets = '';
	SET @med_received_sets  = '';

	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  'BEGIN: usp_Medical_documents';

	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_client_id: ' +  CAST(@var_client_id AS VARCHAR(100));
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_session_uuid: ' +  CAST(@var_session_uuid AS VARCHAR(100))  ;
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@table_name_to_update: ' +  CAST(@table_name_to_update AS VARCHAR(100));
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@transaction_table_name_to_update: ' +  CAST(@transaction_table_name_to_update AS VARCHAR(100));

--********************************************************
--EMPTY OUT THE TABLE
--********************************************************
	TRUNCATE TABLE Temp_Medical_Documents_Record_Processed;

	-- we are using TOP 1 CAREPLAN_UUID FROm Journal instead of [dbo].[CarePlan_ServicePlan] because 
	--for client 1313464746 there is a record in journal table but no record in Careplan_serviceplan table, so there may be more cases like this
	SET @dynSQL_temp_medical_documents = '
		SELECT
				CLIENT_ID,
				CAREPLAN_UUID,				
				JOURNAL_TYPE, 
	--			(SELECT CONVERT(DATETIME, CONVERT(CHAR(8), ENTRY_DATE, 112)  + '' '' + CONVERT(char(8), ENTRY_TIME, 108))) AS ENTRY_DATETIME,
		[ENTRY_DATE_TIME] as ENTRY_DATETIME,
				0 AS RECORD_PROCESSED
		FROM 
				Journal je
		WHERE 
				CLIENT_ID = ' + CAST(@var_client_id AS VARCHAR(100)) + ' AND
				JOURNAL_TYPE LIKE ''%SET%''  AND 
				CAREPLAN_UUID = (
						SELECT
								TOP 1 CAREPLAN_UUID 
						FROM
								CarePlan_ServicePlan 
						WHERE 
								CLIENT_ID = ' + CAST(@var_client_id AS VARCHAR(100)) + ' AND
								CARE_PLAN_STATUS = ''Active'' AND
								CARE_PLAN_CARE_MANAGER_IS_PRIMARY = ''Y''
						ORDER BY 
								CARE_PLAN_END_DATE DESC
			)			
	' 
	IF @debug > 0 PRINT CHAR(13) + CHAR(13) + '@dynSQL_temp_medical_documents: ' + @dynSQL_temp_medical_documents; 

--********************************************************
--REBUILD TEMP TABLE
--********************************************************	
	INSERT INTO Temp_Medical_Documents_Record_Processed
	EXEC (@dynSQL_temp_medical_documents)
	SET @dynSQL_temp_medical_documents = ''	  

	SET @var_careplan_uuid = (SELECT TOP(1) CAREPLAN_UUID FROM Temp_Medical_Documents_Record_Processed)
	IF @debug > 0 PRINT CHAR(13) + CHAR(13) + '@var_careplan_uuid: ' + CAST(@var_careplan_uuid AS VARCHAR(100))  
 
--********************************************************
-- SET 1 Medical Information or Documents		
--********************************************************
	SET @entry_datetime_med_set_1_req = (SELECT TOP 1 ENTRY_DATETIME FROM Temp_Medical_Documents_Record_Processed WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE = 'Medical Info (Set 1) Requested'  ORDER BY ENTRY_DATETIME ASC)
	IF @debug > 0 PRINT CHAR(13)  + '@entry_datetime_med_set_1_req: ' + CAST(@entry_datetime_med_set_1_req AS VARCHAR(100)) 

	SET @med_set_1_req_count = (SELECT ISNULL(COUNT(JOURNAL_TYPE), 0) FROM Temp_Medical_Documents_Record_Processed WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE = 'Medical Info (Set 1) Requested' )
	IF @debug > 0 PRINT CHAR(13)  + '@med_set_1_req_count: ' + CAST(@med_set_1_req_count AS VARCHAR(100)) 

	IF @med_set_1_req_count > 0
		BEGIN 
			SET @med_requested_sets = '1, ';
		END
	IF @med_set_1_req_count <= 0 
		BEGIN 
			SET @med_requested_sets = 'None, ';
			SET @var_set_req = 1;
		END

	SET @entry_datetime_med_set_1_recd  = (SELECT TOP 1 ENTRY_DATETIME FROM Temp_Medical_Documents_Record_Processed WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE = 'Medical Info (Set 1) Received' ORDER BY ENTRY_DATETIME ASC)
	IF @debug > 0 PRINT CHAR(13)  + '@@entry_datetime_med_set_1_recd: ' + CAST(@entry_datetime_med_set_1_recd AS VARCHAR(100)) 

	SET @med_set_1_rec_count = (SELECT ISNULL(COUNT(JOURNAL_TYPE), 0) FROM Temp_Medical_Documents_Record_Processed WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE = 'Medical Info (Set 1) Received')
	IF @debug > 0 PRINT CHAR(13) + '@@med_set_1_rec_count: ' +  CAST(@med_set_1_rec_count AS VARCHAR(100)) 
	
	IF @med_set_1_rec_count > 0
		BEGIN 
			SET @med_received_sets = '1, ';
		END
	IF @med_set_1_rec_count <= 0
		BEGIN 
			SET @med_received_sets = 'None, ';
			SET @var_set_rec = 1;
		END
				
	IF (@entry_datetime_med_set_1_req IS NOT NULL AND @entry_datetime_med_set_1_req <> '')
	BEGIN
		IF (@entry_datetime_med_set_1_recd IS NULL OR @entry_datetime_med_set_1_recd = '')
			BEGIN
				SET @med_number_of_days_1  = DATEDIFF(d, GETDATE(), @entry_datetime_med_set_1_req ) 
				IF @debug > 0 PRINT CHAR(13) + 'getdate - set1 recd' + CAST(@med_number_of_days_1 AS VARCHAR(100))  
			END
		ELSE
			BEGIN
				SET @med_number_of_days_1  =  DATEDIFF(d, @entry_datetime_med_set_1_req, @entry_datetime_med_set_1_recd )   
				IF @debug > 0 PRINT CHAR(13) + 'set1 req - set1 recd' + CAST(@med_number_of_days_1 AS VARCHAR(100))  
			END
	END
--*****************************************
-- SET 2 Medical Information or Documents		
--*****************************************				 
	SET @entry_datetime_med_set_2_req = (SELECT TOP 1  ENTRY_DATETIME FROM Temp_Medical_Documents_Record_Processed  WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE =  'Medical Info (Set 2) Requested'  ORDER BY ENTRY_DATETIME ASC)
	IF @debug > 0 PRINT CHAR(13)  + '@@entry_datetime_med_set_2_req: ' + CAST(@entry_datetime_med_set_2_req AS VARCHAR(100))  
	
	SET @med_set_2_req_count = (SELECT ISNULL(COUNT(JOURNAL_TYPE), 0) FROM Temp_Medical_Documents_Record_Processed  WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE =  'Medical Info (Set 2) Requested')
	IF @debug > 0 PRINT CHAR(13)  + '@@med_set_2_req_count: ' + CAST(@med_set_2_req_count AS VARCHAR(100)) 

	IF @med_set_2_req_count > 0
		BEGIN 
			SET @med_requested_sets = @med_requested_sets + '2, ';
		END
	IF @med_set_2_req_count <= 0 
		BEGIN 
			--SET @med_requested_sets = @med_requested_sets + 'None, ';
			SET @var_set_req = @var_set_req + 1;
		END

	SET @entry_datetime_med_set_2_recd  = (SELECT TOP 1  ENTRY_DATETIME FROM Temp_Medical_Documents_Record_Processed  WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE  = 'Medical Info (Set 2) Received'  ORDER BY ENTRY_DATETIME ASC)
	IF @debug > 0 PRINT CHAR(13)  + '@@entry_datetime_med_set_2_recd: '  +CAST(@entry_datetime_med_set_2_recd AS VARCHAR(100)) 

	SET @med_set_2_rec_count  = (SELECT  ISNULL(COUNT(JOURNAL_TYPE), 0)  FROM Temp_Medical_Documents_Record_Processed  WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE  = 'Medical Info (Set 2) Received')
	IF @debug > 0 PRINT CHAR(13)  + '@@med_set_2_rec_count: ' + CAST(@med_set_2_rec_count AS VARCHAR(100))  

	IF @med_set_2_rec_count > 0
		BEGIN 
			SET @med_received_sets = @med_received_sets + '2, ';
		END
	IF @med_set_2_rec_count <= 0 
		BEGIN 
			--SET @med_received_sets = @med_received_sets + 'None, ';
			SET @var_set_rec = @var_set_rec + 1;
		END

	IF (@entry_datetime_med_set_2_req IS NOT NULL AND @entry_datetime_med_set_2_req <> '')
	BEGIN
		IF (@entry_datetime_med_set_2_recd IS NULL OR @entry_datetime_med_set_2_recd = '')
			BEGIN
				SET @med_number_of_days_2  = DATEDIFF(d, GETDATE(), @entry_datetime_med_set_2_req )
				IF @debug > 0 PRINT CHAR(13) + ' getdate - set2 recd' + CAST(@med_number_of_days_2 AS VARCHAR(100))  
			END
		ELSE
			BEGIN
				SET @med_number_of_days_2  =  DATEDIFF(d, @entry_datetime_med_set_2_req, @entry_datetime_med_set_2_recd )   
				IF @debug > 0 PRINT CHAR(13) + 'set2 req - set2 recd' + CAST(@med_number_of_days_2 AS VARCHAR(100))  
			END
	END							   
--*****************************************
-- SET 3 Medical Information or Documents		
--*****************************************
	SET @entry_datetime_med_set_3_req = (SELECT TOP 1  ENTRY_DATETIME FROM Temp_Medical_Documents_Record_Processed  WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE =  'Medical Info (Set 3) Requested'  ORDER BY ENTRY_DATETIME ASC)
	IF @debug > 0 PRINT CHAR(13)  + '@@entry_datetime_med_set_3_req: ' + CAST(@entry_datetime_med_set_3_req AS VARCHAR(100))  
	
	SET @med_set_3_req_count = (SELECT  ISNULL(COUNT(JOURNAL_TYPE), 0)  FROM Temp_Medical_Documents_Record_Processed  WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE =  'Medical Info (Set 3) Requested')
	IF @debug > 0 PRINT CHAR(13)  + '@@med_set_3_req_count: ' + CAST(@med_set_3_req_count AS VARCHAR(100))

	IF @med_set_3_req_count > 0
		BEGIN 
			SET @med_requested_sets = @med_requested_sets + '3';
		END
	IF @med_set_3_req_count <= 0
		BEGIN 
				SET @var_set_req = @var_set_req + 1;
		END

	SET @entry_datetime_med_set_3_recd  = (SELECT TOP 1  ENTRY_DATETIME FROM Temp_Medical_Documents_Record_Processed  WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE = 'Medical Info (Set 3) Received'  ORDER BY ENTRY_DATETIME ASC)
	IF @debug > 0 PRINT CHAR(13)  + '@@entry_datetime_med_set_3_recd: ' + CAST(@entry_datetime_med_set_3_recd AS VARCHAR(100)) 

	SET @med_set_3_rec_count  = (SELECT  ISNULL(COUNT(JOURNAL_TYPE), 0)   FROM Temp_Medical_Documents_Record_Processed  WHERE CLIENT_ID = @var_client_id AND JOURNAL_TYPE = 'Medical Info (Set 3) Received')
	IF @debug > 0 PRINT CHAR(13)  + '@@med_set_3_rec_count: ' + CAST(@med_set_3_rec_count AS VARCHAR(100))  

	IF @med_set_3_rec_count > 0
		BEGIN 
			SET @med_received_sets = @med_received_sets + '3';
		END
	IF @med_set_3_rec_count <= 0
		BEGIN 			
			SET @var_set_rec = @var_set_rec + 1;
		END
	
	IF (@entry_datetime_med_set_3_req IS NOT NULL AND @entry_datetime_med_set_3_req <> '')
	BEGIN
		IF (@entry_datetime_med_set_3_recd IS NULL OR @entry_datetime_med_set_3_recd = '')
			BEGIN
				SET @med_number_of_days_3  = DATEDIFF(d, GETDATE(), @entry_datetime_med_set_3_req )
				IF @debug > 0 PRINT CHAR(13) + 'getdate - set3 recd' + CAST(@med_number_of_days_3 AS VARCHAR(100))  
			END
		ELSE
			BEGIN
				SET @med_number_of_days_3  =  DATEDIFF(d, @entry_datetime_med_set_3_req, @entry_datetime_med_set_3_recd )   
				IF @debug > 0 PRINT CHAR(13) + 'set3 req - set3 recd' + CAST(@med_number_of_days_3 AS VARCHAR(100))  
			END
	END 

	IF (RIGHT(RTRIM(@med_requested_sets), 1) = ',')
	BEGIN
		SET @med_requested_sets = SUBSTRING(RTRIM(@med_requested_sets), 1, LEN(RTRIM(@med_requested_sets))-1)
	END 
	IF @debug > 0 PRINT CHAR(13)  + '@med_requested_sets: ' + @med_requested_sets;	 
 
	IF (RIGHT(RTRIM(@med_received_sets), 1) = ',')
	BEGIN
		SET @med_received_sets = SUBSTRING(RTRIM(@med_received_sets), 1, LEN(RTRIM(@med_received_sets))-1)
	END	
	IF @debug > 0 PRINT CHAR(13)  + '@med_received_sets: '  + @med_received_sets;


	IF (@var_set_req = 3 AND @var_set_rec = 3)  
	BEGIN 
		SET @med_requested_sets = '';
		SET @med_received_sets = '';
	END
		
	IF (LEN(@med_requested_sets) > 0 OR LEN(@med_received_sets) > 0 )
		BEGIN 
			SET	@var_medical_document_message  = 'Medical Info: Requested Set(s) ' + QUOTENAME(@med_requested_sets, '{}') +' ' + CHAR(0149) + ' Received Set(s) ' + QUOTENAME(@med_received_sets, '{}'); 
		END
	ELSE 
		BEGIN	 
			SET	@var_medical_document_message  = 'None requested'; 
		END 
 
  --IF ERROR (WHEN MULTIPLE REQ : MEDICAL_DOCUMENTS display “Error: Medical Info Journal Type Sets# used more than once "
	IF (@med_set_1_req_count > 1)
	BEGIN 
		SET	@var_medical_document_message  = 'Error: Medical Info Journal Type Set #1 used more than once';		
	END 

	IF (@med_set_2_req_count > 1)
	BEGIN 
		SET	@var_medical_document_message  = 'Error: Medical Info Journal Type Set #2 used more than once';		
	END 

	IF (@med_set_3_req_count > 1)
	BEGIN 
		SET	@var_medical_document_message  = 'Error: Medical Info Journal Type Set #3 used more than once';		
	END 

	IF @debug > 0 PRINT CHAR(13) + '@var_medical_document_message: '+ @var_medical_document_message; 
	

	INSERT INTO Transaction_Table_Medical_Documents_Record
	(
		CLIENT_ID,
		CAREPLAN_UUID,
		ENTRY_DATETIME_MED_SET_1_REQ,
		MED_SET_1_REQ,
		ENTRY_DATETIME_MED_SET_1_RECD,
		MED_SET_1_REC,
		MED_NUMBER_OF_DAYS_1,
		ENTRY_DATETIME_MED_SET_2_REQ,
		MED_SET_2_REQ,
		ENTRY_DATETIME_MED_SET_2_RECD,
		MED_SET_2_REC,
		MED_NUMBER_OF_DAYS_2,
		ENTRY_DATETIME_MED_SET_3_REQ,
		MED_SET_3_REQ,
		ENTRY_DATETIME_MED_SET_3_RECD,
		MED_SET3_REC,
		MED_NUMBER_OF_DAYS_3,
		MED_REQUESTED_SETS,
		MED_RECEIVED_SETS		
	)
	values
	(
		@var_client_id,
		@var_careplan_uuid,
		@entry_datetime_med_set_1_req,
		@med_set_1_req_count,
		@entry_datetime_med_set_1_recd,
		@med_set_1_rec_count, 
		@med_number_of_days_1, 
		@entry_datetime_med_set_2_req,  
		@med_set_2_req_count, 
		@entry_datetime_med_set_2_recd,  
		@med_set_2_rec_count,   
		@med_number_of_days_2,   
		@entry_datetime_med_set_3_req,  
		@med_set_3_req_count,  
		@entry_datetime_med_set_3_recd,  
		@med_set_3_rec_count,  
		@med_number_of_days_3,
		@med_requested_sets,
		@med_received_sets
	) 

	SET @var_update_medical_documents = '
		UPDATE '+CAST(@transaction_table_name_to_update AS VARCHAR(100))+' SET
				MEDICAL_DOCUMENTS =  '''+CAST(@var_medical_document_message AS VARCHAR(100))+'''
		WHERE				
				CLIENT_ID = '+@var_client_id+' AND
				SESSION_UUID  = ''' + CAST(@var_session_uuid AS VARCHAR(500)) + '''
	'
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_update_medical_documents: ' + @var_update_medical_documents;
	EXEC (@var_update_medical_documents); 
	    
	SET @var_client_id = ''
	SET @var_careplan_uuid = ''
	SET @entry_datetime_med_set_1_req = '' 
	SET @med_set_1_req  = ''
	SET @med_requested_sets =  ''
	SET @entry_datetime_med_set_1_recd  =  ''
	SET @med_set_1_rec  =  ''
	SET @med_number_of_days_1  = ''
	SET @entry_datetime_med_set_2_req  = ''
	SET @med_set_2_req =  ''
	SET @med_requested_sets =  ''
	SET @entry_datetime_med_set_2_recd  =  ''
	SET @med_set_2_rec  = ''
	SET @med_number_of_days_2 = ''
	SET @entry_datetime_med_set_3_req =  ''
	SET @med_set_3_req = ''
	SET @med_requested_sets = ''
	SET @entry_datetime_med_set_3_recd  = ''
	SET @med_set3_rec =  ''
	SET @med_number_of_days_3 = ''
	SET @med_requested_sets = ''
	SET @med_received_sets = '' 
	SET @var_update_medical_documents = ''
	SET @var_medical_document_message = ''
	
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  'END:  usp_Medical_documents';

END 

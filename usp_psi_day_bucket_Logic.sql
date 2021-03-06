USE [idb_datastore]
GO
/****** Object:  StoredProcedure [dbo].[usp_psi_day_bucket_Logic]    Script Date: 6/13/2022 2:22:33 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 



ALTER  PROCEDURE [dbo].[usp_psi_day_bucket_Logic] 

@var_Temp_Bucket_days_Client_ID NVARCHAR(50), 
@var_Temp_Bucket_days_SESSION_UUID NVARCHAR(150),
@table_name_to_update NVARCHAR(150),
@transaction_table_name_to_update NVARCHAR(150),
@var_exploitation_type_STUFF NVARCHAR(150),
@var_exploitation_type_non_financial_type NVARCHAR(150),
@Determination_Complete_value INT
AS
SET NOCOUNT ON 
SET ANSI_WARNINGS OFF
SET ANSI_NULLS ON 
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN    
	DECLARE @var_calculate_number_of_days INT
	DECLARE @var_Temp_Bucket_days_id INT
	DECLARE @var_is_financial_type NVARCHAR(150)
	DECLARE @var_number_of_days NVARCHAR(150)
	DECLARE @var_days_remaining_bucket_narrative NVARCHAR(150)
	DECLARE @exploitation_type_choice_ID  NVARCHAR(150) 
	DECLARE @var_update_number_of_days NVARCHAR(MAX)
	DECLARE @var_update_Exploitation_Type NVARCHAR(MAX) 
	DECLARE @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe NVARCHAR(MAX)  	 
	DECLARE @debug INT 

	SET @debug  = 0 -- 1 YES/ 0 NO

	--IF	(@var_Temp_Bucket_days_SESSION_UUID = '911F1675-930B-4B36-8121-CABDE355DF94')
	--	BEGIN 
	--			SET @debug  = 1 -- 1 YES/ 0 NO
	--	END

	--IF	(@var_Temp_Bucket_days_SESSION_UUID  = '92EF9470-C32B-4847-A95D-1B09A0F25FDE')
	--	BEGIN 
	--			SET @debug  = 1 -- 1 YES/ 0 NO
	--	END

	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  'BEGIN: usp_day_bucket_Logic'  ;
	   	    
	--CHECK IF ANY FINANCIAL EXPLOITATION EXIST
	SET @var_is_financial_type =  NULL;
	SET @var_is_financial_type =  (SELECT CHARINDEX('8', @var_exploitation_type_STUFF));
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_is_financial_type: ' +  CAST(@var_is_financial_type AS VARCHAR(100));
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_exploitation_type_STUFF: ' +  CAST(@var_exploitation_type_STUFF AS VARCHAR(100))  ;
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_exploitation_type_non_financial_type: ' +  CAST(@var_exploitation_type_non_financial_type AS VARCHAR(100));
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@Determination_Complete_value: ' +  CAST(@Determination_Complete_value AS VARCHAR(100));
	 
	SET @var_update_Exploitation_Type = '
			UPDATE '+CAST(@transaction_table_name_to_update AS VARCHAR(100))+' SET
					Exploitation_Type = '''+ @var_exploitation_type_STUFF +''' 
			WHERE				
					SESSION_UUID = '''+@var_Temp_Bucket_days_SESSION_UUID+'''AND
					QUESTION_ID = 1731'
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_update_Exploitation_Type: ' + @var_update_Exploitation_Type;
	EXEC (@var_update_Exploitation_Type); 
	   
    --WE ARE GETTING ONLY TOP 1 AS THERE ARE MORE THAN ONE RECORD RETURNING, AS THERE IS DUPLICATE DATA IN SYSTEM. E.G SESSION ID
	--SELECT CLIENT_ID SESSION_UUID, QUESTION_ID, RESPONSE_DATA FROM TRANSACTION_TABLE_OPEN_INVESTIGATIONS_BY_PERSON_INVESTIGATOR_03
	--WHERE SESSION_UUID = '7BC39C62-D264-4D64-B17F-7ABCBCD8BFC0' AND QUESTION_ID = 1731
	
	SET  @var_number_of_days = (
			SELECT   
					TOP 1 DATEDIFF(DAY, GETDATE(), CAST(RESPONSE_DATA AS DATE) ) 
			FROM 
					Temp_Bucket_days 
			WHERE
					SESSION_UUID = ''+@var_Temp_Bucket_days_SESSION_UUID+'' AND
					QUESTION_ID = 1731
	)								 
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_number_of_days: ' + @var_number_of_days ;
    --RETURN

	SET @var_update_number_of_days = '
			UPDATE '+CAST(@transaction_table_name_to_update AS VARCHAR(100))+' SET
					Number_Of_Days = '+@var_number_of_days+'
			WHERE 
					SESSION_UUID = '''+@var_Temp_Bucket_days_SESSION_UUID+''' AND
					Client_ID = '''+@var_Temp_Bucket_days_Client_ID+''' AND
					QUESTION_ID = 1731
		'
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_update_number_of_days: ' + @var_update_number_of_days;
	EXEC (@var_update_number_of_days);   
	 										
	--BUCKET SORTING       							
	IF (@var_is_financial_type != 'NULL' AND @var_is_financial_type <> '' AND @var_is_financial_type > 0 AND @var_exploitation_type_non_financial_type = 0 )  -- 60-DAY COUNTDOWN LOGIC 
			IF (@Determination_Complete_value = 0 OR @Determination_Complete_value = NULL OR @Determination_Complete_value ='' ) 
					BEGIN				
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@Determination_Complete_value' +  CAST(@Determination_Complete_value AS VARCHAR(100));
						IF @debug > 0 PRINT CHAR(13)+ 'USE THE 60-DAY COUNTDOWN LOGIC'; 

						SET @var_calculate_number_of_days = @var_number_of_days
						SET @var_calculate_number_of_days = @var_calculate_number_of_days + 60 	
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_calculate_number_of_days plus 60: ' +  CAST(@var_calculate_number_of_days AS VARCHAR(100));

						IF (@var_calculate_number_of_days <0)
							BEGIN 
								SET @var_days_remaining_bucket_narrative = 'Overdue by ' + CAST(ABS(@var_calculate_number_of_days) AS VARCHAR(100)) + ' Days' -- “Overdue by [number of days] Days”
							END				
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_calculate_number_of_days: ' +  CAST(@var_calculate_number_of_days AS VARCHAR(100));
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_days_remaining_bucket_narrative: ' + @var_days_remaining_bucket_narrative;

						SET @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe = '
								UPDATE '+CAST(@transaction_table_name_to_update AS VARCHAR(100))+' SET
										Calculated_Number_Of_Days_FE = '+CAST(@var_calculate_number_of_days AS VARCHAR(100))+',
										Days_Remaining_Bucket_Narrative_FE = '''+@var_days_remaining_bucket_narrative+'''
								WHERE 
										SESSION_UUID = '''+@var_Temp_Bucket_days_SESSION_UUID+''' AND
										Client_ID = '''+@var_Temp_Bucket_days_Client_ID+''' AND
										QUESTION_ID = 1731
						'
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe: ' + @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe ;
						EXEC (@var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe); 
					END	
			ELSE
				BEGIN
					IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@Determination_Complete_value' +  CAST(@Determination_Complete_value AS VARCHAR(100));
					SET @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe = '
								UPDATE '+CAST(@transaction_table_name_to_update AS VARCHAR(100))+' SET	
										Number_Of_Days = '''',
										Days_Remaining_Bucket_Narrative_FE = ''Allegation(s) Determination Complete.''
								WHERE 
										SESSION_UUID = '''+@var_Temp_Bucket_days_SESSION_UUID+''' AND
										Client_ID = '''+@var_Temp_Bucket_days_Client_ID+''' AND
										QUESTION_ID = 1731
						'
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ '@var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe: ' + @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe ;
						EXEC (@var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe); 
				END	

	ELSE -- 20-DAY COUNTDOWN LOGIC 
			IF (@Determination_Complete_value = 0 OR @Determination_Complete_value = NULL OR @Determination_Complete_value ='' ) 
					BEGIN
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ 'USE THE 20-DAY COUNTDOWN LOGIC2';  

						SET @var_calculate_number_of_days = @var_number_of_days + 20 	 
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_calculate_number_of_days plus 20: ' +  CAST(@var_calculate_number_of_days AS VARCHAR(100));
						IF (@var_calculate_number_of_days >20)  
							BEGIN 
								SET @var_days_remaining_bucket_narrative = 'Above 20 days'
							END			
										
						IF (@var_calculate_number_of_days >= 11 AND @var_calculate_number_of_days <=20)  
							BEGIN 
								SET @var_days_remaining_bucket_narrative = '11 to 20 Days Remaining'
							END					
						IF (@var_calculate_number_of_days >= 6 AND @var_calculate_number_of_days <=10)
							BEGIN 
								SET @var_days_remaining_bucket_narrative = '6 to 10 Days Remaining'
							END		
						IF (@var_calculate_number_of_days >= 0 AND @var_calculate_number_of_days <=5)
							BEGIN 
								SET @var_days_remaining_bucket_narrative = '0 to 5 Days Remaining'
							END		
						IF (@var_calculate_number_of_days <0)
							BEGIN 
								SET @var_days_remaining_bucket_narrative = 'Overdue by ' + CAST(ABS(@var_calculate_number_of_days) AS VARCHAR(100)) + ' Days' -- “Overdue by [number of days] Days”
							END										
			
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_calculate_number_of_days: ' +  CAST(@var_calculate_number_of_days AS VARCHAR(100));
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_days_remaining_bucket_narrative: ' + @var_days_remaining_bucket_narrative;
										
						SET @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe = 
								'UPDATE '+CAST(@transaction_table_name_to_update AS VARCHAR(100))+' SET
										Calculated_Number_Of_Days = '+CAST(@var_calculate_number_of_days AS VARCHAR(100))+',
										Days_Remaining_Bucket_Narrative = '''+@var_days_remaining_bucket_narrative+'''
								WHERE 
										SESSION_UUID = '''+@var_Temp_Bucket_days_SESSION_UUID+''' AND
										Client_ID = '''+@var_Temp_Bucket_days_Client_ID+''' AND
										QUESTION_ID = 1731
						'
						IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe: ' + @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe ;
						EXEC (@var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe); 
					END 
			ELSE
				BEGIN
					SET @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe = 
							'UPDATE '+CAST(@transaction_table_name_to_update AS VARCHAR(100))+' SET	
									Number_Of_Days = '''',
									Days_Remaining_Bucket_Narrative = ''Allegation(s) Determination Complete.''
							WHERE 
									SESSION_UUID = '''+@var_Temp_Bucket_days_SESSION_UUID+''' AND
									Client_ID = '''+@var_Temp_Bucket_days_Client_ID+''' AND
									QUESTION_ID = 1731
					'
					IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe: ' + @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe ;
					EXEC (@var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe); 
		END 
	SET @var_exploitation_type_STUFF = ''
	SET @var_update_Exploitation_Type = ''
	SET @var_number_of_days = ''
	SET @var_update_number_of_days = ''
	SET @var_exploitation_type_non_financial_type = ''
	SET @var_update_calculated_number_of_days_fe_days_remaining_bucket_narrative_fe = '' 
 
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  'END: usp_day_bucket_Logic';

END 

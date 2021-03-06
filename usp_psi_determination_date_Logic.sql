USE [idb_datastore]
GO
/****** Object:  StoredProcedure [dbo].[usp_psi_determination_date_Logic]    Script Date: 6/13/2022 2:22:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[usp_psi_determination_date_Logic] 
	@var_client_id NVARCHAR(50), 
	@var_session_uuid NVARCHAR(150),
	@table_name_to_update NVARCHAR(150),
	@transaction_table_name_to_update NVARCHAR(150),
	@var_exploitation_type_STUFF  NVARCHAR(150)
AS 
	SET NOCOUNT ON 
	SET ANSI_WARNINGS OFF
	SET ANSI_NULLS ON 
	SET QUOTED_IDENTIFIER ON
	SET ARITHABORT ON  
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN  
	DECLARE @Questions_Without_Determination_Date NVARCHAR(MAX) 

	DECLARE @var_question_ids NVARCHAR(250) 
	DECLARE @var_question_ids_TOP1 NVARCHAR(250) 
	DECLARE @var_users_question_ids NVARCHAR(250) 
	DECLARE @var_users_question_ids_SQL NVARCHAR(2500) 
	DECLARE @var_users_missed_question_ids_TOP1_SQL NVARCHAR(2500) 
	DECLARE @var_users_missed_question_ids_SQL NVARCHAR(2500) 
	DECLARE @var_users_missed_question_ids NVARCHAR(250) 
	DECLARE @var_users_missed_question_ids_TOP1 NVARCHAR(100) 
	DECLARE @debug INT
	
	SET @debug  =0 -- 1 YES/ 0 NO 

	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+ 'START: usp_determination_date_Logic' ;	
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_exploitation_type_STUFF - usp_psi_determination_date_Logic: ' + CAST(@var_exploitation_type_STUFF AS VARCHAR);

	--*****************************************************************************
	-- BASED ON USER'S ALLEGATION TYPES GET THE QUESTION IDS 
	--*****************************************************************************
 	SET  @var_question_ids =  (
		SELECT 			
			STUFF((SELECT DISTINCT ', ' + CAST (QUESTION_ID AS VARCHAR(250))
		FROM 
			Allegations 
		WHERE 
			ID IN 
			(
				SELECT * 
				FROM
					[udf_psi_str_parse_8K](@var_exploitation_type_STUFF,',')
			) 
			FOR XML PATH('')),1,2,'')
	)	
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_question_ids correspond to choice id - usp_psi_determination_date_Logic: ' +  CAST(@var_question_ids AS VARCHAR(250));	
	   
	--********************************************************************************************************************************************************
	 --BASED ON THE USER'S ALLEGATION TYPES GET THE QUESTION_IDS WHICH ARE PRESENT IN USER ASSESSMENT WITH A RESPONSE DATE 
	--********************************************************************************************************************************************************
	SET @var_users_question_ids_SQL = '
		SELECT @var_users_question_ids =
			ISNULL(
					STUFF((SELECT DISTINCT '', '' + CAST(QUESTION_ID AS VARCHAR(500)) 
					FROM  
						ASSESSMENT 
					WHERE 
						Client_ID = ' + @var_client_id + ' AND 
						SESSION_UUID  = ''' + @var_session_uuid + ''' AND 
						(RESPONSE_DATA <> NULL OR RESPONSE_DATA IS NOT NULL OR RESPONSE_DATA <> '''') AND
						QUESTION_ID IN ( ' + @var_question_ids + '  )
					FOR XML PATH('''')),1,2,'''')
			, 0)
	'
	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + '@var_users_question_ids_SQL - usp_psi_determination_date_Logic: ' +  @var_users_question_ids_SQL;
 
	EXEC sp_executesql @var_users_question_ids_SQL, N'@var_users_question_ids NVARCHAR(150) OUTPUT', @var_users_question_ids OUTPUT;
	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + '@var_users_question_ids - question ids with response date in user.s assessment - usp_psi_determination_date_Logic: ' + @var_users_question_ids

	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 85:'
	--RETURN

	--=============================== TESTING PURPOSE, WILL NEED TO REMOVE OR COMMENTED OUT IT LATER  =================================
	--SET @var_users_question_ids = 1;
	--IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + '@var_users_question_ids - usp_psi_determination_date_Logic: line: ' + @var_users_question_ids
	--================================================================================================================================
		
	IF (@var_users_question_ids <> '0') --BASED ON THE USER'S ALLEGATION TYPES THE USER HAS A FEW QUESTION_IDS WITH RESPONSE DATE, SO WE NEED TO CHECK ARE THERE ANY QUESTION_IDS NOT PRESENT IN USER ASSESSMENT OR ARE WITHOUT A RESPONSE DATE.

		BEGIN
			IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'USER ASSESSMENT HAS ONE OR MORE QUESTION ID WITH THE RESPONSE DATE SO WE NEED TO SKIP THOSE AND GET THE ONES WHICH DOES NOT HAVE RESPONSE DATE OR ARE MISSING IN USER ASSESSMENT BASED ON THE user.s ALLEGATION TYPES';

			--************************************************************************************************************************************************** 
			-- THE USER'S ALLEGATION TYPES(CHOICE_ID) GET THE QUESTION_ID WHICH ARE MISSING OR DOES NOT HAVE A RESPONSE DATA 
			--************************************************************************************************************************************************** 
			SET  @var_users_missed_question_ids_SQL = '
					SELECT @var_users_missed_question_ids =
							ISNULL(
									STUFF((SELECT DISTINCT '', '' + CAST (QUESTION_ID AS VARCHAR(500))   
								FROM  
										ASSESSMENT 
								WHERE 
										Client_ID = ' + @var_client_id + ' AND 
										SESSION_UUID  = ''' + @var_session_uuid + ''' AND 
										QUESTION_ID IN ( ' + @var_question_ids + '  ) AND 
										QUESTION_ID NOT IN ( ' + @var_users_question_ids + '  )
										FOR XML PATH('''')),1,2,'''')
						, 0)
				'
			IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_users_missed_question_ids_SQL - usp_psi_determination_date_Logic: ' + @var_users_missed_question_ids_SQL;

			EXEC sp_executesql @var_users_missed_question_ids_SQL, N'@var_users_missed_question_ids NVARCHAR(150) OUTPUT', @var_users_missed_question_ids OUTPUT;
			IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + '@var_users_missed_question_ids - usp_psi_determination_date_Logic: ' + @var_users_missed_question_ids	 

			 IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 120: '
			-- RETURN
			 
			IF (@var_users_missed_question_ids <> '0')  --NOT ALL ALLEGATIONS ARE COMPLETE, ONE OR MORE QUESTION_IDS ARE MISSING RESPONSE DATE
				BEGIN 

				--******************************************************************************************************************
				--  BASED ON USER'S ALLEGATION TYPES(CHOICE_ID) GET THE TOP 1 MISSING QUESTION_ID
				--******************************************************************************************************************
				SET @var_users_missed_question_ids_TOP1_SQL = '
						SELECT @var_users_missed_question_ids_TOP1 =
								ISNULL(
										STUFF((SELECT DISTINCT TOP 1 '', '' + CAST (QUESTION_ID AS VARCHAR(500)) 
								FROM  
										ASSESSMENT 
								WHERE 
										Client_ID = ' + @var_client_id + ' AND 
										SESSION_UUID  = ''' + @var_session_uuid + ''' AND 
										QUESTION_ID IN ( ' + @var_question_ids + '  ) AND 
										QUESTION_ID NOT IN ( ' + @var_users_question_ids + '  )
										FOR XML PATH('''')),1,2,'''')
						, 0)
				'
				IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@var_users_missed_question_ids_TOP1_SQL - usp_psi_determination_date_Logic: ' + @var_users_missed_question_ids_TOP1_SQL;
	
				EXEC sp_executesql @var_users_missed_question_ids_TOP1_SQL, N'@var_users_missed_question_ids_TOP1 NVARCHAR(150) OUTPUT', @var_users_missed_question_ids_TOP1 OUTPUT;
				IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + '@var_users_missed_question_ids_TOP1 - usp_psi_determination_date_Logic: ' + @var_users_missed_question_ids_TOP1  
				 
				
					IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 146:'
					--RETURN
				
				SET @Questions_Without_Determination_Date = '
					UPDATE '+@transaction_table_name_to_update +' SET
							Determination_Complete =  0,
							Questions_Without_Determination_Date =  '''+CAST(@var_users_missed_question_ids_TOP1 AS VARCHAR(100))+''',
							Questions_Without_Determination_Date_All =  '''+CAST(@var_users_missed_question_ids AS VARCHAR(100))+''',	   
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
					IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'Questions_Without_Determination_Date - usp_psi_determination_date_Logic: ' +  @Questions_Without_Determination_Date;	
					IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 177:'
					--RETURN


				END	
			ELSE   --ALL ALLEGATIONS ARE COMPLETE, ALL CHOICE IDS HAVE CORRESPONDING QUESTION IDs WITH A RESPONSE DATE
				BEGIN
					SET @Questions_Without_Determination_Date = '
						UPDATE '+@transaction_table_name_to_update+' SET
								Determination_Complete =  1,
								Questions_Without_Determination_Date =  '''',
								Questions_Without_Determination_Date_All =  '''',	  
								REASON_OVERDUE = ''''
						WHERE 
								QUESTION_ID = 1731 AND 
								Client_ID = ' +  CAST(@var_client_id AS VARCHAR(100)) + ' AND 
								SESSION_UUID = ''' + @var_session_uuid + '''
					'  
					IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'Questions_Without_Determination_Date - usp_psi_determination_date_Logic: ' +  @Questions_Without_Determination_Date;	
					IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 196:'
					--RETURN
				END							
			
				IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 200:'
				--RETURN
			
		END

	ELSE -- USER DID NOT RESPONSE TO ANY ALLEGATIONS SO DETERMINATION IS NOT COMPLETE
				
		BEGIN 	
			IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'USER DID NOT ANSWER ANY QUESTIONS';

			SET  @var_question_ids_TOP1 =  (
		SELECT 			
			STUFF((SELECT DISTINCT TOP 1 ', ' + CAST (QUESTION_ID AS VARCHAR(250))
		FROM 
			Allegations 
		WHERE 
			ID IN 
			(
				SELECT * 
				FROM
					[udf_psi_str_parse_8K](@var_exploitation_type_STUFF,',')
			) 
			FOR XML PATH('')),1,2,'')
	)	
			IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  '@@var_question_ids_TOP1 - usp_psi_determination_date_Logic: ' +  CAST(@var_question_ids_TOP1 AS VARCHAR(250));	
	
			SET @Questions_Without_Determination_Date = '
			UPDATE '+@transaction_table_name_to_update+' SET
					Determination_Complete =  0,
					Questions_Without_Determination_Date = '''+CAST(@var_question_ids_TOP1 AS VARCHAR(100))+''',	
					Questions_Without_Determination_Date_All =  '''+CAST(@var_question_ids AS VARCHAR(100))+''',	  
					REASON_OVERDUE =   (
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
					SESSION_UUID = ''' + @var_session_uuid+ '''
			'	 
			IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'Questions_Without_Determination_Date - usp_psi_determination_date_Logic: ' +  @Questions_Without_Determination_Date;	
			IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 254:'
			--RETURN
		END	 
			   		 	  		
	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'Questions_Without_Determination_Date - usp_psi_determination_date_Logic: ' +  @Questions_Without_Determination_Date;		 
	IF @debug > 0 PRINT CHAR(13)+  CHAR(13) + 'RETURN - usp_psi_determination_date_Logic LINE# 259:'
	--RETURN
	   	 
	EXEC (@Questions_Without_Determination_Date); 

	SET  @Questions_Without_Determination_Date = '' 
	SET  @var_question_ids =  ''
	SET  @var_users_question_ids_SQL =  ''
	SET  @var_users_missed_question_ids_SQL =  ''
	SET  @var_users_missed_question_ids_TOP1_SQL = ''
	SET  @var_users_missed_question_ids =  ''
	SET  @var_users_missed_question_ids_TOP1 = ''
				
	IF @debug > 0 PRINT CHAR(13)+ CHAR(13)+  'END: usp_determination_date_Logic';
END

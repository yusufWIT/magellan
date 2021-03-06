USE [idb_datastore]
GO
/****** Object:  StoredProcedure [dbo].[usp_psi_f2f_Logic]    Script Date: 6/13/2022 2:23:29 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[usp_psi_f2f_Logic] @var_client_id NVARCHAR(20)
	,@var_session_uuid NVARCHAR(150)
	,@day_bucket_to_f2f NVARCHAR(100) OUTPUT
	,@response_days_f2f INT OUTPUT
	,@table_name_to_update NVARCHAR(150)
	,@transaction_table_name_to_update NVARCHAR(150)
	,@final_category NVARCHAR(50)
	,@var_exploitation_type_STUFF NVARCHAR(150)
	,@var_exploitation_type_non_financial_type NVARCHAR(150)
AS
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN
	DECLARE @set_response_data_from_4072 NVARCHAR(500)
	DECLARE @set_response_data_from_1731 NVARCHAR(500)
	DECLARE @var_is_financial_type NVARCHAR(150)
	DECLARE @debug INT

	SET @debug = 0 -- 1 YES/ 0 NO

	IF @debug > 0
		PRINT CHAR(13) + 'START:sp_f2f_Logic';

	IF @debug > 0
		PRINT CHAR(13) + '@final_category: ' + @final_category;

	--RETURN
	IF (
			@final_category = 'Emergency'
			OR @final_category = 'Priority'
			)
			BEGIN
		SET @response_days_f2f = '';
		SET @day_bucket_to_f2f = 'Error – Missing RON Date - Overdue';

		IF @debug > 0
			PRINT CHAR(13) + 'EMERGENCY OR PRIORITY LOGIC';

		IF @debug > 0
			PRINT CHAR(13) + 'sp_f2f_Logic: #53 '

		SET @debug = 0
		SET @set_response_data_from_4072 = (
				SELECT RESPONSE_DATA
				FROM ASSESSMENT
				WHERE QUESTION_ID = 4072
					AND Client_ID = '' + CAST(@var_client_id AS VARCHAR(20)) + ''
					AND SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(100)) + ''
				)

		IF @debug > 0 PRINT CHAR(13) +  '@@set_response_data_from_4072 ' + CAST(@set_response_data_from_4072 AS VARCHAR(100));

		--RETURN
		--WE ARE GETTING ONLY TOP 1 AS THERE ARE MORE THAN ONE RECORD RETURNING, AS THERE IS DUPLICATE DATA IN SYSTEM. E.G SESSION ID
		--SELECT CLIENT_ID SESSION_UUID, QUESTION_ID, RESPONSE_DATA FROM TRANSACTION_TABLE_OPEN_INVESTIGATIONS_BY_PERSON_INVESTIGATOR_03
		--WHERE SESSION_UUID = '7BC39C62-D264-4D64-B17F-7ABCBCD8BFC0' AND QUESTION_ID = 1731
		IF (
				@set_response_data_from_4072 IS NULL
				OR @set_response_data_from_4072 = ''
				OR @set_response_data_from_4072 = 'NULL'
				OR len(@set_response_data_from_4072) = 0
				)
		BEGIN
			IF @debug > 0
				PRINT CHAR(13) + 'sp_f2f_Logic: #78 '

			IF @debug > 0
				PRINT CHAR(13) + @set_response_data_from_4072;

			SET @set_response_data_from_1731 = (
					SELECT TOP 1 RESPONSE_DATA
					FROM ASSESSMENT
					WHERE QUESTION_ID = 1731
						AND Client_ID = '' + CAST(@var_client_id AS VARCHAR(100)) + ''
						AND SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(500)) + ''
					)

			IF @debug > 0
				PRINT CHAR(13) +  '@set_response_data_from_1731 ' + CAST(@set_response_data_from_1731 AS VARCHAR(100));

			IF @debug > 0
				PRINT CHAR(13) + 'sp_f2f_Logic: #95 '

			--RETURN
			--IF (NOT EXIST)
			IF (
					@set_response_data_from_1731 IS NULL
					OR @set_response_data_from_1731 = ''
					OR @set_response_data_from_1731 = 'NULL'
					OR len(@set_response_data_from_1731) = 0
					)
			BEGIN
				SET @day_bucket_to_f2f = 'Error – Missing RON Date - Overdue - 4072'

				IF @debug > 0
					PRINT CHAR(13) + 'sp_f2f_Logic: #109 '

				--RETURN
				SET @debug = 0
			END
			ELSE
			BEGIN
				SET @response_days_f2f = DATEDIFF(DAY, CAST(GETDATE() AS DATE), CAST(@set_response_data_from_1731 AS DATE))

				IF @debug > 0
					PRINT CHAR(13) + 'DATEDIFF response_days_f2f: #1 ' + CAST(@response_days_f2f AS VARCHAR(20));

				IF @debug > 0
					PRINT CHAR(13) + 'sp_f2f_Logic: #122 '

				--RETURN
				IF (@response_days_f2f = 0)
				BEGIN
					SET @day_bucket_to_f2f = 'Day 1 - 24 hours or less remaining'
				END

				IF (@response_days_f2f = - 1)
				BEGIN
					SET @day_bucket_to_f2f = 'Day 2 - Less than 12 hours remaining'
				END

				IF (@response_days_f2f <= - 2)
				BEGIN
					SET @day_bucket_to_f2f = 'Overdue by ' + CAST(ABS(@response_days_f2f) AS VARCHAR(100)) + ' day(s)'
				END

				IF @debug > 0
					PRINT CHAR(13) + '@day_bucket_to_f2f #1 ' + @day_bucket_to_f2f;
			END
		END
		ELSE
		BEGIN
			IF @debug > 0
				PRINT CHAR(13) + 'sp_f2f_Logic: #147 '

			--RETURN
			SET @set_response_data_from_4072 = (
					SELECT RESPONSE_DATA
					FROM ASSESSMENT
					WHERE QUESTION_ID = 4072
						AND Client_ID = '' + CAST(@var_client_id AS VARCHAR(100)) + ''
						AND SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(500)) + ''
					)
			--WE ARE GETTING ONLY TOP 1 AS THERE ARE MORE THAN ONE RECORD RETURNING, AS THERE IS DUPLICATE DATA IN SYSTEM. E.G SESSION ID
			--SELECT CLIENT_ID SESSION_UUID, QUESTION_ID, RESPONSE_DATA FROM TRANSACTION_TABLE_OPEN_INVESTIGATIONS_BY_PERSON_INVESTIGATOR_03
			--WHERE SESSION_UUID = '7BC39C62-D264-4D64-B17F-7ABCBCD8BFC0' AND QUESTION_ID = 1731                                                                              
			SET @set_response_data_from_1731 = ISNULL((
						SELECT TOP 1 RESPONSE_DATA
						FROM ASSESSMENT
						WHERE QUESTION_ID = 1731
							AND Client_ID = '' + CAST(@var_client_id AS VARCHAR(100)) + ''
							AND SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(500)) + ''
						), '01/01/1900')
			SET @response_days_f2f = DATEDIFF(DAY, CAST(@set_response_data_from_4072 AS DATE), CAST(@set_response_data_from_1731 AS DATE))

			IF @debug > 0
				PRINT CHAR(13) + 'DATEDIFF response_days_f2f: #3 ' + CAST(@response_days_f2f AS VARCHAR(20));

			--SET @day_bucket_to_f2f = 'WE DO NOT NEED TO APPLY ANY BUCKET LOGIC AS QUESTION_ID 4072 IS NOT NULL'
			SET @day_bucket_to_f2f = 'F2F completed in ' + CAST(ABS(@response_days_f2f) AS VARCHAR(100)) + ' days'

			IF @debug > 0
				PRINT CHAR(13) + @day_bucket_to_f2f;
		END
	END
	ELSE
			BEGIN
				SET @response_days_f2f = '';
				SET @day_bucket_to_f2f = 'default value of @day_bucket_to_f2f at line# 183 is null ';

				IF @debug > 0
					PRINT CHAR(13) + 'NON PRIORITY CONDITION LOGIC';

				IF @debug > 0
					PRINT CHAR(13) + 'sp_f2f_Logic: #188' 
 
			SET @debug = 0
  
				IF @debug > 0
					PRINT CHAR(13) + 'sp_f2f_Logic: #194 ';
 
					IF NOT EXISTS ( 
						SELECT RESPONSE_DATA
							FROM ASSESSMENT
							WHERE QUESTION_ID = 4072
								AND Client_ID = '' + CAST(@var_client_id AS VARCHAR(100)) + ''
								AND SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(500)) + '')
					BEGIN
								IF @debug > 0
									PRINT CHAR(13) + '  usp_psi_f2f_Logic #204 ';

								--RETURN

								--IF (RESPONSE_DATA_FROM_1731 NOT EXIST)
								IF NOT  EXISTS ( 	SELECT TOP 1 RESPONSE_DATA
										FROM ASSESSMENT
										WHERE QUESTION_ID = 1731
											AND Client_ID = '' + CAST(@var_client_id AS VARCHAR(100)) + ''
											AND SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(500)) + ''
										)
									BEGIN
									SET @day_bucket_to_f2f = 'Error – Missing RON Date'

									IF @debug > 0
										PRINT CHAR(13) + '  usp_psi_f2f_Logic # 219';

									--RETURN
									SET @debug = 0
								END
								ELSE 
							---**************************************************************************************************************
							-- LOGIC (based on 01/25/2022 word doc) commented out on 04/19/2022
							---**************************************************************************************************************		
							--BEGIN
							--		IF @debug > 0
							--			PRINT CHAR(13) + '  usp_psi_f2f_Logic # 259';
							--		IF @debug > 0
							--				PRINT CHAR(13) + 'NON PRIORITY DAY LOGIC';

							--		--RETURN
							--		SET @response_days_f2f = DATEDIFF(DAY, CAST(GETDATE() AS DATE), CAST(@set_response_data_from_1731 AS DATE))

							--		IF @debug > 0
							--			PRINT CHAR(13) + 'DATEDIFF response_days_f2f: #267 ' + CAST(@response_days_f2f AS VARCHAR(20));

							--		BEGIN
							--			IF (@response_days_f2f = 0)
							--			BEGIN
							--				SET @day_bucket_to_f2f = 'Day 1 - 72 hours or less remaining'
							--			END

							--			IF (@response_days_f2f = 1)
							--			BEGIN
							--				SET @day_bucket_to_f2f = 'Day 2 - Less than 24 hours remaining'
							--			END

							--			IF (@response_days_f2f = 2)
							--			BEGIN
							--				SET @day_bucket_to_f2f = 'Day 3 - Less than 12 hours remaining'
							--			END

							--			--	then place message in bucket: “Overdue by [Days minus 2] day(s)”
							--			IF (@response_days_f2f >= 3)
							--				SET @response_days_f2f = @response_days_f2f - 2;

							--			BEGIN
							--				SET @day_bucket_to_f2f = 'Overdue by ' + CAST(ABS(@response_days_f2f) AS VARCHAR(20)) + 'day(s)';
							--			END
							--		END

							--		IF @debug > 0
							--			PRINT CHAR(13) + '@day_bucket_to_f2f #2 ' + @day_bucket_to_f2f;
							--	END
							---**************************************************************************************************************

							---**************************************************************************************************************
							--	-- LOGIC  added on 04/19/2022
							---**************************************************************************************************************  
										BEGIN
											SET @set_response_data_from_1731 = (
													SELECT TOP 1 RESPONSE_DATA
													FROM ASSESSMENT
													WHERE QUESTION_ID = 1731
														AND Client_ID = '' + CAST(@var_client_id AS VARCHAR(100)) + ''
														AND SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(500)) + ''
													)

											IF @debug > 0 PRINT CHAR(13)+ '  usp_psi_f2f_Logic # 282';
											--RETURN
											SET @response_days_f2f = DATEDIFF(DAY, CAST(GETDATE() AS DATE), CAST(@set_response_data_from_1731 AS DATE))    
											SET @response_days_f2f = @response_days_f2f + 20

											SET @response_days_f2f = CAST(ABS(@response_days_f2f) AS VARCHAR(100)) 

											IF @debug > 0 PRINT CHAR(13)+ 'DATEDIFF response_days_f2f: #289 ' +  CAST(@response_days_f2f AS VARCHAR(20));
											--RETURN

											----IF QUESTION_ID 4574 (ALLEGATIONS), CHOICE_ID = 8 (FINANCIAL EXPLOITATION) AND THERE ARE NO OTHER CHOICE_IDS THEN
											--IF (@var_is_financial_type != 'NULL' AND @var_is_financial_type <> '' AND @var_is_financial_type > 0 AND @var_exploitation_type_non_financial_type = 0 )						
											--	BEGIN 										
											--		SET @day_bucket_to_f2f = 'FINANCIAL EXPLOITATION AND and there are no other CHOICE_IDs  '
								
											--		IF @debug > 0 PRINT CHAR(13)+ '  usp_psi_f2f_Logic #: 317 ';
											--		--RETURN

											--	END	 
											--ELSE  
											--	BEGIN 
														--SET @day_bucket_to_f2f = 'line#316 and value of @response_days_f2f: ' + CAST(@response_days_f2f AS VARCHAR(20)) 
														SET @day_bucket_to_f2f = 'Value is either zero or less than zero: ' + CAST(@response_days_f2f AS VARCHAR(20)) 
														IF (@response_days_f2f > 0 and @response_days_f2f < =20)
															BEGIN 
																SET @day_bucket_to_f2f =   CAST(ABS(@response_days_f2f) AS VARCHAR(20))  + ' Remaining'
															END
														IF (@response_days_f2f >= 21)
															BEGIN 
																SET @day_bucket_to_f2f =  'Overdue by ' + CAST(ABS(@response_days_f2f) AS VARCHAR(20)) 
															END
												--END	   

											IF @debug > 0 PRINT CHAR(13)+ '@day_bucket_to_f2f #2 - LINE# 314 ' +  @day_bucket_to_f2f;
										END
							--************************************************************************************************************** 
					 
					END
				ELSE --NON PRIORITY =>  If QUESTION_ID 4072 (F2F Date), RESPONSE_DATA is not missing,
					BEGIN
								IF @debug > 0
									PRINT CHAR(13) + '  usp_psi_f2f_Logic # 322 ';

								--RETURN
								SET @set_response_data_from_4072 = (
										SELECT RESPONSE_DATA
										FROM ASSESSMENT
										WHERE QUESTION_ID = 4072
											AND Client_ID = '' + CAST(@var_client_id AS VARCHAR(100)) + ''
											AND SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(500)) + ''
										)
								--WE ARE GETTING ONLY TOP 1 AS THERE ARE MORE THAN ONE RECORD RETURNING, AS THERE IS DUPLICATE DATA IN SYSTEM. E.G SESSION ID
								--SELECT CLIENT_ID SESSION_UUID, QUESTION_ID, RESPONSE_DATA FROM TRANSACTION_TABLE_OPEN_INVESTIGATIONS_BY_PERSON_INVESTIGATOR_03
								--WHERE SESSION_UUID = '7BC39C62-D264-4D64-B17F-7ABCBCD8BFC0' AND QUESTION_ID = 1731
								SET @set_response_data_from_1731 = isnull((
											SELECT TOP 1 RESPONSE_DATA
											FROM ASSESSMENT
											WHERE QUESTION_ID = 1731
												AND Client_ID = '' + CAST(@var_client_id AS VARCHAR(100)) + ''
												AND SESSION_UUID = '' + CAST(@var_session_uuid AS VARCHAR(500)) + ''
											), '01/01/1900')
								SET @response_days_f2f = DATEDIFF(DAY, CAST(@set_response_data_from_4072 AS DATE), CAST(@set_response_data_from_1731 AS DATE))

								IF @debug > 0
									PRINT CHAR(13) + 'DATEDIFF response_days_f2f #4: ' + CAST(@response_days_f2f AS VARCHAR(20));

								--SET @day_bucket_to_f2f = 'WE DO NOT NEED TO APPLY ANY BUCKET LOGIC AS QUESTION_ID 4072 IS NOT NULL'
								SET @day_bucket_to_f2f = 'F2F completed in ' + CAST(ABS(@response_days_f2f) AS VARCHAR(100)) + ' days'

								IF @debug > 0
									PRINT CHAR(13) + '@day_bucket_to_f2f: LINE# 351' + @day_bucket_to_f2f;
					END
	END

	IF @debug > 0
		PRINT CHAR(13) + 'END: sp_f2f_Logic';
END
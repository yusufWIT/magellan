USE [idb_datastore]
GO
/****** Object:  StoredProcedure [dbo].[usp_psi_etl_process]    Script Date: 6/13/2022 2:23:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[usp_psi_etl_process]
AS
SET NOCOUNT ON 
SET ANSI_WARNINGS OFF
SET ANSI_NULLS ON 
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN  

	PRINT CHAR(13)+ CHAR(13)+ 'START: usp_etl_proces'  
		EXEC usp_psi_01_Abuse_And_Neglect_Cases; 
	PRINT CHAR(13)+ CHAR(13)+ 'END: usp_etl_proces'
END

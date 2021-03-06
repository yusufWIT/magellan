USE [idb_datastore]
GO
/****** Object:  UserDefinedFunction [dbo].[udf_psi_str_parse_8K]    Script Date: 6/13/2022 2:24:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[udf_psi_str_parse_8K] (@String varchar(max),@Delimiter varchar(10))
Returns Table 
As
Return (  
    with   cte1(N)   As (Select 1 From (Values(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) N(N)),
           cte2(N)   As (Select Top (IsNull(DataLength(@String),0)) Row_Number() over (Order By (Select NULL)) From (Select N=1 From cte1 a,cte1 b,cte1 c,cte1 d) A ),
           cte3(N)   As (Select 1 Union All Select t.N+DataLength(@Delimiter) From cte2 t Where Substring(@String,t.N,DataLength(@Delimiter)) = @Delimiter),
           cte4(N,L) As (Select S.N,IsNull(NullIf(CharIndex(@Delimiter,@String,s.N),0)-S.N,8000) From cte3 S)

    Select RetVal = Substring(@String, A.N, A.L) 
    From   cte4 A
);
--Much faster than str-Parse, but limited to 8K
--Select * from [dbo].[udf-Str-Parse-8K]('Dog,Cat,House,Car',',')
--Select * from [dbo].[udf-Str-Parse-8K]('John||Cappelletti||was||here','||')

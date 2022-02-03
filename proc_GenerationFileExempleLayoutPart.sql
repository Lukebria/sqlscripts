IF EXISTS (
    SELECT    TOP 1 0
    FROM     dbo.SYSOBJECTS
    WHERE     ID = OBJECT_ID(N'[dbo].[proc_GenerationFileExempleLayoutPart]')
        AND OBJECTPROPERTY(ID, N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[proc_GenerationFileExempleLayoutPart]
GO
    
CREATE PROCEDURE [dbo].[proc_GenerationFileExempleLayoutPart]      
(      
 @issuer   int,      
 @ProductId   int,      
 @DateInitial   date,      
 @FinalDate  date,      
 @NumberFile  int,      
 @SysDateGeneretion  datetime,      
 @FirstFile bit = 0      
)      
AS      
BEGIN      
      
declare @FileG table      
(      
 id_Line int identity(1,1),      
 tp_Register tinyint,      
 id_Register int,      
 dc_Register varchar(500)      
)      
      
declare @AmountRegisters int = 0,      
  @InsurenceCompanyId  int      
           
select  @InsurenceCompanyId = id_Seguradora      
from ProductInsurence     
where   id_Issuer    = @issuer      
  and id_ProductInsurence = @ProductId      
      
      
--Header      
insert @FileG      
SELECT      
    0,      
 0,      
 'H' +                     -- “H” – Header (fix value)      
 'VENDAS     ' +                         
 'COMPANY TRILALA               ' +            
 format(@SysDateGeneretion, 'ddMMyyyy') +
 format(@NumberFile, '000000') +         
 left(nm_Product + space(30), 30) +
 space(261) -- Filler      
FROM Products WHERE id_Product = @ProductId      
      
-- ADESAO      
insert @FileG      
select distinct IIF(a.tp_StatusInsurenceSeguro = 1, 1, 3),      
				a.id_ContractInsurence,      
				'D' + 
				right(replicate('0', 3) + pl.cd_PlanIssuer, 3) +  
				left(a.no_Contract + space(15), 15) +     
				right(replicate('0', 6) + isnull(at.no_Title, ''), 6) +     
				isnull(format(a.dt_SituationBilling, 'ddMMyyyy'), format(a.dt_Situation, 'ddMMyyyy')) +      
				left(upper(pe.nm_Person) + space(40), 40) +
				left(pe.no_CPF + space(11), 11) +
				left(upper(isnull(e.cd_UF, '')) + space(2), 2) +     
				iif(a.tp_StatusInsurenceSeguro = 1, 'I', 'C') +    
				iif(a.tp_StatusInsurenceSeguro = 2, format(a.dt_Situation, 'ddMMyyyy'), space(8)) +
				isnull(format(co.no_DDD, '000'), '000') +   
				isnull(format(co.no_Telefone, replicate('0', 15)), replicate('0', 15)) + 
				isnull(format(co.no_DDD, '000'), '000') +             
				isnull(format(co.no_SmartPhone, replicate('0', 15)), replicate('0', 15)) +      
				right(replicate('0', 11) + isnull(cast(at.no_Title as varchar), '0') + isnull(cast(at.cd_Identification as varchar), '00'), 11) +    
				right(replicate('0', 10) + est.cd_Estabelecimento, 10) +
				space(50) --filler
  from ContractInsurence a      
  inner join ProductInsurence p  on p.id_ProductInsurence = a.id_ProductInsurence      
  inner join InsurencePlan pl  on pl.id_Plan = a.id_Plan      
  left join Billing ps     on ps.id_ContractInsurence = a.id_ContractInsurence      
  inner join Client c   on c.id_Client = a.id_Client      
  inner join Person pe   on pe.id_Person = c.id_Person      
  left join Contact co   on co.id_Contact = pe.id_Contact         
  left join Adress e   on e.id_Adress = pe.id_Adress     
  left join Title at  on at.id_ContractInsurence = a.id_ContractInsurence              
where    
  a.id_Issuer = @issuer      
  and p.id_ProductInsurence = @ProductId      
  and (a.dt_Issue  < DATEADD(DAY, 1, @FinalDate)       
        and a.tp_StatusTransference = 1 and a.tp_StatusInsurenceSeguro = 1)      
  and ((      
    (select min(no_billing)      
    from Parcela_Seguro      
    where id_ContractInsurence = a.id_ContractInsurence      
      and tp_StatusInsurence = 2) = ps.no_billing      
   AND (p.cd_ProductInsurence = '9981')) 
   OR (p.cd_ProductInsurence <> '9981'))    
    
    
      
select @AmountRegisters = COUNT(*) + 1      
from    @FileG      
      
      
begin      
   
        INSERT INTO File_Exportation_Data (      
                dt_Reference,        
                id_Issuer,      
                id_InsurenceCompany,      
                id_Product,         
                nr_SequentialFile      
                )      
        VALUES (@FinalDate, @issuer, @InsurenceCompanyId, @ProductId, @NumberFile)          
    
        DECLARE @IdFileExportationData INT      
      
        SELECT @IdFileExportationData = idFileExportationData       
                FROM File_Exportation_Data      
                WHERE dt_Reference = @FinalDate       
                AND nr_SequentialFile = @NumberFile      
                AND id_InsurenceCompany = @InsurenceCompanyId       
                AND id_ProductInsurence = @ProductId      
                AND  id_Emissor = @issuer      

 insert @FileG      
    SELECT 2, 0, 'T' + right(replicate('0', 8) + CAST(@AmountRegisters AS VARCHAR), 8) + space(338)      
      
 insert @FileG      
 select  10,      
   0,      
   'update ContractInsurence set tp_StatusTransference = 2 where id_ContractInsurence = ' +      
   CAST(id_Register as varchar)      
 from    @FileG      
 where   tp_Register = 1      
 order by id_Line      
      
 insert @FileG      
 select  10,      
   0,      
   'update ContractInsurence set tp_StatusTransference = 5 where id_ContractInsurence = ' +      
   CAST(id_Register as varchar)      
 from    @FileG      
 where   tp_Register = 3      
 order by id_Line      
      
    IF @IdFileExportationData IS NOT NULL      
        BEGIN      
            UPDATE ContractInsurence       
                SET id_ArquivoExportacaoDados = @IdFileExportationData      
                FROM ContractInsurence A JOIN @FileG Arq ON Arq.id_Register=A.id_ContractInsurence      
        END       
      
end      
      
select id_Line,      
  tp_Register,      
  id_Register,      
  dc_Register    
from    @FileG      
order by id_Line      
      
return      
END
go

GRANT EXECUTE ON [dbo].[proc_GenerationFileExempleLayoutPart] TO [rotine.exection.sql]
GO
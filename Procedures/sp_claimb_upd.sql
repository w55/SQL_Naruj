USE [Naruj]
GO
/****** Object:  StoredProcedure [dbo].[sp_claimb_upd]    Script Date: 27.02.2017 9:57:42 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO


--		менеджеры или администратор изменяют заявку
--
ALTER                         PROCEDURE [dbo].[sp_claimb_upd]
	@upd_whom int, @claimb_id int, @claimh_id int, @claim_state int, @bit_add bit, @adr_id int, @is_light bit,
	@date_from varchar(20), @date_to varchar(20),  @price decimal(19,2) = 0
AS

IF @upd_whom < 1
begin
	RAISERROR(' Ошибка изменения записи № %d из таблицы claim_body: Номер пользователя (%d) - должен быть больше 0',
		16, 1, @claimb_id, @upd_whom)
	return -1
end
IF @claimb_id <= 0
begin
	RAISERROR(' Ошибка изменения записи № %d из таблицы claim_body: Номер записи должен быть больше 0',
		16, 1, @claimb_id)
	return - 1
end


declare @date_from0 datetime, @date_to0 datetime
set @date_from0 = convert(datetime, @date_from,104)
set @date_to0 = convert(datetime, @date_to,104)

if @date_from0 > @date_to0
begin
	RAISERROR(' Ошибка изменения заявки: Начальная дата больше конечной !!!',16, 1)
	return -1
end

IF (SELECT revoke_admin FROM claim_head where claimh_id = @claimh_id) is not null
begin
	RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже аннулирована Администратором ',
		16, 1, @claimh_id)
	return - 1
end

IF (SELECT revoke_manager FROM claim_head where claimh_id = @claimh_id) is not null
begin
	RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже аннулирована Менеджером ',
		16, 1, @claimh_id)
	return - 1
end

--
IF (SELECT is_bind FROM claim_head where claimh_id = @claimh_id) <> 0
begin
	RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже <Привязана> к договору ',
		16, 1, @claimh_id)
	return - 1
end

IF (SELECT is_assign FROM claim_head where claimh_id = @claimh_id) <> 0
begin
	RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже <Закреплена> Администратором ',
		16, 1, @claimh_id)
	return - 1
end

IF (SELECT is_revoke_admin_2 FROM claim_head where claimh_id = @claimh_id) <> 0
begin
	RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже <Отозвана> Администратором ',
		16, 1, @claimh_id)
	return - 1
end

--
--		запрашиваемые стороны
--
IF @claim_state = 1
begin
-- 	IF (SELECT is_bind FROM claim_head where claimh_id = @claimh_id) <> 0
-- 	begin
-- 		RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже <привязана> к договору',
-- 			16, 1, @claimh_id)
-- 		return - 1
-- 	end

	IF (SELECT ask_to_agree FROM claim_head where claimh_id = @claimh_id) is not null
	begin
		RAISERROR(' Ошибка изменения записи № %d из таблицы ЗАЯВКИ: Уже выставлен флаг: запрос Администратору',
			16, 1, @claimh_id)
		return - 1
	end

	IF (SELECT agree_to FROM claim_head where claimh_id = @claimh_id) is not null
	begin
		RAISERROR(' Ошибка изменения записи № %d из таблицы ЗАЯВКИ: Уже назначена дата согласования',
			16, 1, @claimh_id)
		return - 1
	end

	IF (SELECT agreed FROM claim_head where claimh_id = @claimh_id) is not null
	begin
		RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже согласована',
			16, 1, @claimh_id)
		return - 1
	end
	
-- 	IF (SELECT is_assign FROM claim_head where claimh_id = @claimh_id) <> 0
-- 	begin
-- 		RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже <закреплена>',
-- 			16, 1, @claimh_id)
-- 		return - 1
-- 	end
end

--
--		предложенные стороны
--
IF @claim_state = 2
begin
-- 	IF (SELECT is_bind FROM claim_head where claimh_id = @claimh_id) <> 0
-- 	begin
-- 		RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже <привязана> к договору',
-- 			16, 1, @claimh_id)
-- 		return - 1
-- 	end

	IF (SELECT ask_to_agree FROM claim_head where claimh_id = @claimh_id) is null
	begin
		RAISERROR(' Ошибка изменения записи № %d из таблицы ЗАЯВКИ: Еще не выставлен флаг: запрос Администратору',
			16, 1, @claimh_id)
		return - 1
	end
--
--		изменение условий договора должно быть подтверждено начальником отдела
--
	IF ((SELECT is_dog_chng FROM claim_head where claimh_id = @claimh_id) <> 0) and 
		((SELECT is_chng_agree FROM claim_head where claimh_id = @claimh_id) = 0)
	begin
		RAISERROR(' Ошибка : изменение условий договора должно быть подтверждено начальником отдела',
			16, 1)
		return - 1
	end

	IF (SELECT agree_to FROM claim_head where claimh_id = @claimh_id) is not null
	begin
		RAISERROR(' Ошибка изменения записи № %d из таблицы ЗАЯВКИ: Уже назначена дата согласования',
			16, 1, @claimh_id)
		return - 1
	end

	IF (SELECT agreed FROM claim_head where claimh_id = @claimh_id) is not null
	begin
		RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже согласована',
			16, 1, @claimh_id)
		return - 1
	end
	
-- 	IF (SELECT is_assign FROM claim_head where claimh_id = @claimh_id) <> 0
-- 	begin
-- 		RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже <закреплена>',
-- 			16, 1, @claimh_id)
-- 		return - 1
-- 	end
--
--	проверяем - занятость данного адреса на запрашиваемое время
--
--	если налагаем свободно(bsst_id = 1) или предварительная бронь (bsst_id = 2) - то пропускаем проверку
--
-- 	IF @bit_add = 1 and exists(SELECT * FROM busy where adr_id = @adr_id AND bsst_id > 1 AND claimb_id <> @claimb_id AND
-- 		((date_from between convert(datetime, @date_from,104) and convert(datetime, @date_to,104)) OR
-- 		(date_to between convert(datetime, @date_from,104) and convert(datetime, @date_to,104))))
-- 	begin
-- --
-- 		declare @adr_code varchar(9), @busy_id int, @dbuser_id2 int, @manager varchar(102)
-- 		declare @date_from1 datetime, @date_to1 datetime, @date_from2 varchar(20), @date_to2 varchar(20)
-- 
-- 		set @adr_code = (select adr_code from address where  adr_id = @adr_id)
-- 
-- 		set @busy_id = (select top 1 busy_id from busy where  adr_id = @adr_id AND bsst_id > 1 AND
-- 			((date_from between convert(datetime, @date_from,104) and convert(datetime, @date_to,104)) OR
-- 			(date_to between convert(datetime, @date_from,104) and convert(datetime, @date_to,104))))
-- 
-- 		set @dbuser_id2 = (select dbuser_id from busy where  busy_id = @busy_id)
-- 		set @manager = (select ltrim(rtrim(last_name)) + ' ' + ltrim(rtrim(first_name)) from db_users where  dbuser_id = @dbuser_id2)
-- 
-- 		set @date_from1 = (select date_from from busy where  busy_id = @busy_id)
-- 		set @date_from2 = convert(varchar(20), @date_from1,104)
-- 
-- 		set @date_to1 = (select date_to from busy where  busy_id = @busy_id)
-- 		set @date_to2 = convert(varchar(20), @date_to1,104)
-- --
-- --
-- 		RAISERROR(' Ошибка: по адресу %s, за период с %s по %s, менеджером %s - наложена бронь ',
-- 			16, 1, @adr_code, @date_from2, @date_to2, @manager)
-- 		return - 1
-- 	end
end

--
--		подтвержденные стороны
--
IF @claim_state = 3
begin
-- 	IF (SELECT is_bind FROM claim_head where claimh_id = @claimh_id) <> 0
-- 	begin
-- 		RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже <привязана> к договору',
-- 			16, 1, @claimh_id)
-- 		return - 1
-- 	end

	IF (SELECT ask_to_agree FROM claim_head where claimh_id = @claimh_id) is null
	begin
		RAISERROR(' Ошибка изменения записи № %d из таблицы ЗАЯВКИ: Еще не выставлен флаг: запрос Администратору',
			16, 1, @claimh_id)
		return - 1
	end
--
--		изменение условий договора должно быть подтверждено начальником отдела
--
	IF ((SELECT is_dog_chng FROM claim_head where claimh_id = @claimh_id) <> 0) and 
		((SELECT is_chng_agree FROM claim_head where claimh_id = @claimh_id) = 0)
	begin
		RAISERROR(' Ошибка : изменение условий договора должно быть подтверждено начальником отдела',
			16, 1)
		return - 1
	end

	IF (SELECT agree_to FROM claim_head where claimh_id = @claimh_id) is null
	begin
		RAISERROR(' Ошибка изменения записи № %d из таблицы ЗАЯВКИ: Еще не назначена дата согласования',
			16, 1, @claimh_id)
		return - 1
	end

	IF (SELECT agreed FROM claim_head where claimh_id = @claimh_id) is not null
	begin
		RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже согласована',
			16, 1, @claimh_id)
		return - 1
	end
	
-- 	IF (SELECT is_assign FROM claim_head where claimh_id = @claimh_id) <> 0
-- 	begin
-- 		RAISERROR(' Ошибка изменения записи № %d из таблицы claim_head: Заявка уже <закреплена>',
-- 			16, 1, @claimh_id)
-- 		return - 1
-- 	end
--
--		если не изменяем условия договора - то делаем проверку:  
--		не включен ли данный адрес на запрашиваемое время в подтвержденные стороны
--
	IF (SELECT is_dog_chng FROM claim_head where claimh_id = @claimh_id) = 0
	begin
		IF exists (SELECT * FROM claim_body 
			where claimb_id <> @claimb_id AND claimh_id = @claimh_id AND claim_state = 3 AND adr_id = @adr_id AND is_del = 0 AND
			((date_from between convert(datetime, @date_from,104) and convert(datetime, @date_to,104)) OR
			(date_to between convert(datetime, @date_from,104) and convert(datetime, @date_to,104))))
		begin
			RAISERROR(' Ошибка : данный адрес на запрашиваемое время уже включен в подтвержденные стороны', 16, 1)
			return - 1
		end
	end

--
--	проверяем - занятость данного адреса на запрашиваемое время
--
--
--	т.к. налагаем реальную бронь (bsst_id = 3) - то проводим проверку на наличие реальной брони или занятости
--

	declare @adr_code varchar(9), @busy_id int, @dbuser_id2 int, @manager varchar(102)
	declare @date_from1 datetime, @date_to1 datetime, @date_from2 varchar(20), @date_to2 varchar(20)

--
	IF @bit_add = 1 and exists(SELECT * FROM busy where adr_id = @adr_id AND bsst_id > 2 AND
		((@date_from0 between date_from AND date_to) OR (@date_to0 between date_from AND date_to)))
	begin
		set @adr_code = (select adr_code from address where  adr_id = @adr_id)

		set @busy_id = (select top 1 busy_id from busy where  adr_id = @adr_id AND bsst_id > 2 AND
			((@date_from0 between date_from AND date_to) OR (@date_to0 between date_from AND date_to)))

		set @dbuser_id2 = (select dbuser_id from busy where  busy_id = @busy_id)
		set @manager = (select ltrim(rtrim(last_name)) + ' ' + ltrim(rtrim(first_name)) from db_users where  dbuser_id = @dbuser_id2)

		set @date_from1 = (select date_from from busy where  busy_id = @busy_id)
		set @date_from2 = convert(varchar(20), @date_from1,104)

		set @date_to1 = (select date_to from busy where  busy_id = @busy_id)
		set @date_to2 = convert(varchar(20), @date_to1,104)
--
		RAISERROR(' Ошибка 111: по адресу %s, за период с %s по %s, менеджером %s - наложена реальная бронь(или занято) ',
			16, 1, @adr_code, @date_from2, @date_to2, @manager)
		return - 1
	end
--

	IF @bit_add = 1 and exists(SELECT * FROM busy where adr_id = @adr_id AND bsst_id > 2 AND
		((date_from between @date_from0 AND @date_to0) OR (date_to between @date_from0 AND @date_to0)))
	begin
		set @adr_code = (select adr_code from address where  adr_id = @adr_id)

		set @busy_id = (select top 1 busy_id from busy where  adr_id = @adr_id AND bsst_id > 2 AND
			((date_from between @date_from0 AND @date_to0) OR (date_to between @date_from0 AND @date_to0)))

		set @dbuser_id2 = (select dbuser_id from busy where  busy_id = @busy_id)
		set @manager = (select ltrim(rtrim(last_name)) + ' ' + ltrim(rtrim(first_name)) from db_users where  dbuser_id = @dbuser_id2)

		set @date_from1 = (select date_from from busy where  busy_id = @busy_id)
		set @date_from2 = convert(varchar(20), @date_from1,104)

		set @date_to1 = (select date_to from busy where  busy_id = @busy_id)
		set @date_to2 = convert(varchar(20), @date_to1,104)
--
		RAISERROR(' Ошибка 222: по адресу %s, за период с %s по %s, менеджером %s - наложена реальная бронь(или занято) ',
			16, 1, @adr_code, @date_from2, @date_to2, @manager)
		return - 1
	end
end


--	вычисляем число(дробное) месяцев
--	размещения рекламы :
declare @dt1 as datetime, @dt2 as datetime, @dt00 as datetime, @dt99 as datetime, @str_date as varchar(30)
declare @m1 as int, @m2 as int, @d1 as int, @d2 as int, @yy as int, @mm as int, @nmb int
declare @nmbc as dec(15,10), @nmbc1 as dec(15,10), @nmbc2 as dec(15,10)

set @dt1 = convert(datetime, @date_from,104)
set @dt2 = convert(datetime, @date_to,104)

--select '@dt1' = @dt1, '@dt2' = @dt2, 'datediff(dd,@dt1,@dt2)' = datediff(dd,@dt1,@dt2)

IF @dt1 > @dt2
begin
	RAISERROR(' Ошибка : Дата начала больше даты окончания размещения рекламного изображения !!!',16, 1)
	return -1
end

--	первый месяц
set @mm = datepart(month,@dt1)
set @yy = datepart(year,@dt1)

set @str_date = '01.' + str(@mm) + '.' + str(@yy)
set @dt00 = convert(datetime, @str_date,104)

if @mm = 12
	begin
		set @str_date = '01.01.' + str(@yy + 1)
		set @dt99 = convert(datetime, @str_date,104)
	end
else
	begin
		set @str_date = '01.' +  str(@mm + 1) + '.' + str(@yy)
		set @dt99 = convert(datetime, @str_date,104)
	end

set @m1 = datediff(day,@dt00,@dt99)	--	общее кол-во дней в первом месяце
set @d1 = datediff(day,@dt1,@dt99)		--	кол-во рекламных дней в первом месяце
--	отношение кол-ва рекламных дней к общему кол-ву дней в первом месяце
set @nmbc1 = cast(@d1 as dec(15,10)) / @m1
/*
begin
	RAISERROR(' @m1 = %d, @d1 = %d, @mm = %d, @yy = %d, @str_date = %s ',
		16, 1, @m1, @d1, @mm, @yy, @str_date)
	return - 1
end
*/
--select @m1 as '@m1', @d1 as '@d1', @nmbc1 as '@nmbc1', 1000000 * @nmbc1 as '1000000*@nmbc1'

--	последний месяц
set @mm = datepart(month,@dt2)
set @yy = datepart(year,@dt2)

set @str_date = '01.' + str(@mm) + '.' + str(@yy)
set @dt00 = convert(datetime, @str_date,104)

if @mm = 12
	begin
		set @str_date = '01.01.' + str(@yy + 1)
		set @dt99 = convert(datetime, @str_date,104)
	end
else
	begin
		set @str_date = '01.' +  str(@mm + 1) + '.' + str(@yy)
		set @dt99 = convert(datetime, @str_date,104)
	end

set @m2 = datediff(day,@dt00,@dt99)	--	общее кол-во дней в последнем месяце
set @d2 = datediff(day,@dt00,@dt2) + 1		--	кол-во рекламных дней в последнем месяце
--	отношение кол-ва рекламных дней к общему кол-ву дней в последнем месяце
set @nmbc2 = cast(@d2 as dec(15,10)) / @m2

--select @m2 as '@m2', @d2 as '@d2', @nmbc2 as '@nmbc2', 1000000 * @nmbc2 as '1000000*@nmbc2'

--	общее целое кол-во месяцев разницы
set @nmb = datediff(month,@dt1,@dt2)

--	общее дробное кол-во месяцев разницы
if @nmb = 0
begin
	set @d1 = datediff(day,@dt1,@dt2) + 1		--	кол-во рекламных дней в месяце
	set @nmbc = cast(@d1 as dec(15,10)) / @m1
end
else
begin
	if @nmb = 1
	begin
		set @nmbc = @nmbc1 + @nmbc2
	end
	else
	begin
		set @nmbc = @nmbc1 + @nmbc2 + (@nmb - 1)
	end
end

--select @d1 as '@d1',@nmb as '@nmb', @nmbc as '@nmbc', 1000000 * @nmbc as '1000000*@nmbc'

begin tran	--		start transaction

--	обновляем текущую запись
--	и вычисленное число(дробное) месяцев размещения рекламы
--	в таблице claim_body :
	update claim_body
		set claimh_id = @claimh_id, claim_state = @claim_state, bit_add = @bit_add, adr_id = @adr_id, is_light = @is_light,
			date_from = convert(datetime, @date_from,104), date_to = convert(datetime, @date_to,104),
			price = @price, month_dif = @nmbc, upd_whom = @upd_whom, upd_when = getdate()
		where claimb_id = @claimb_id
	
	if @@ROWCOUNT = 0
	begin
		rollback tran		--		rollback all transactions
		RAISERROR(' @@ROWCOUNT = 0 - Ошибка при изменении записи в таблице claim_body !!!', 16, 1)
	end
--
--	изменяем занятость данного адреса на запрашиваемое время	
--
-- 	IF @claim_state = 2 and @bit_add = 1
-- 	begin 
-- 		declare @dbuser_id int, @busy_id2 int, @adr_id2 int
-- 
-- 		set @dbuser_id = (select dbuser_id from claim_head where claimh_id = @claimh_id)
-- 		set @busy_id2 = (select busy_id from busy where claimb_id = @claimb_id)
-- 		set @adr_id2 = (select adr_id from busy where busy_id = @busy_id2)
-- --
-- --		тип занятости: предварительная бронь (bsst_id = 2)
-- --		busy_desc = NULL
-- 
-- 		if @adr_id2 = @adr_id
-- 		begin
-- 			update busy
-- 				set date_from = convert(datetime, @date_from,104), date_to = convert(datetime, @date_to,104),
-- 					bsst_id = 2, dbuser_id = @dbuser_id, is_auto_free = 0,
-- 					date_free = NULL, upd_whom = @upd_whom, upd_when = getdate()
-- 				where busy_id = @busy_id2
-- 			
-- 			if @@ROWCOUNT = 0
-- 			begin
-- 				rollback tran		--		rollback all transactions
-- 				RAISERROR(' @@ROWCOUNT = 0 - Ошибка при изменении записи в таблице busy !!!', 16, 1)
-- 			end
-- 		end
-- 		else
-- 		begin
-- 			update busy
-- 				set bsst_id = 1, upd_whom = @upd_whom, upd_when = getdate()
-- 				where claimb_id = @claimb_id
-- --
-- --
-- 			insert into busy(adr_id,claimb_id,date_from,date_to,bsst_id,dbuser_id,busy_desc,is_auto_free,date_free,upd_whom)
-- 				values(@adr_id,@claimb_id,convert(datetime, @date_from,104),convert(datetime, @date_to,104),
-- 					2,@dbuser_id,NULL,0,NULL,@upd_whom)
-- 	
-- 			if @@ROWCOUNT = 0
-- 			begin
-- 				rollback tran		--		rollback all transactions
-- 				RAISERROR(' @@ROWCOUNT = 0 - Ошибка при вставке новой записи в таблицу busy !!!', 16, 1)
-- 				return -1
-- 			end	
-- 		end
-- 	end

while @@TRANCOUNT > 0
	commit tran		--		commit all open transactions




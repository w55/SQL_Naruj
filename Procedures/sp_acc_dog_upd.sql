USE [Naruj]
GO
/****** Object:  StoredProcedure [dbo].[sp_acc_dog_upd]    Script Date: 27.02.2017 9:52:45 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

--
--	изменение текущей строки для текущей счет-фактуры по договору аренды рекламного места
--
ALTER         PROCEDURE [dbo].[sp_acc_dog_upd]
	@upd_whom int, @accb_id int, @acch_id int, @adr_id int,
	@date_from varchar(20), @date_to varchar(20), @price dec(19,2)
AS

IF @upd_whom < 1
begin
	RAISERROR(' Ошибка изменения записи в таблице acc_dog_body: Номер пользователя (%d) - должен быть больше нуля !!!',
		16, 1, @upd_whom)
	return -1
end

IF NOT EXISTS(select * from acc_head where acch_id = @acch_id and is_free = 0)
begin
	RAISERROR(' Ошибка изменения записи в таблице acc_dog_body: Счет-фактура(вн/№ = %d) - не найдена в таблице acc_head ',
		16, 1, @acch_id)
	return -1
end

IF NOT EXISTS(select * from acc_dog_body where accb_id = @accb_id)
begin
	RAISERROR(' Ошибка изменения записи в таблице acc_dog_body: Запись(вн/№ = %d) - не найдена в таблице acc_dog_body ',
		16, 1, @accb_id)
	return -1
end

--	если счет оплачен полностью - его нельзя редактировать	!!!
--
-- IF EXISTS(select * from acc_head where acch_id = @acch_id and for_pay <= paid and paid > 0)
-- begin
-- 	RAISERROR(' Ошибка : Счет-фактура(вн/№ %d) - оплачена полностью - её нельзя редактировать !!! ',
-- 		16, 1, @acch_id)
-- 	return -1
-- end


IF (@date_from is null or @date_to is null)
begin
	RAISERROR(' Ошибочные входные параметры: не задана начальная или конечная даты', 16, 1)
	return -1
end

IF (convert(datetime, @date_from,104) > convert(datetime, @date_to,104))
begin
	RAISERROR(' Ошибочные входные параметры: начальная дата больше конечной даты', 16, 1)
	return -1
end

--RAISERROR(' Входные параметры приняты !!!', 16, 1)

begin tran	--		start transaction
--
--	изменение текущей строки для текущей счет-фактуры по договору аренды рекламного места
--
	declare @dt1 as datetime, @dt2 as datetime, @dt00 as datetime, @dt99 as datetime, @str_date as varchar(30)
	declare @m1 as int, @m2 as int, @d1 as int, @d2 as int, @yy as int, @mm as int, @nmb int
	declare @nmbc as dec(15,10), @nmbc1 as dec(15,10), @nmbc2 as dec(15,10)


--		вычисляем число(дробное) месяцев
--		размещения рекламы :
--
	set @dt1 = convert(datetime, @date_from,104)	
	set @dt2 = convert(datetime, @date_to,104)
--
	IF @dt1 > @dt2
	begin
		rollback tran
		RAISERROR(' Ошибочные входные параметры: начальная дата больше конечной даты', 16, 1)
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
--
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
--
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
--
--	изменяем текущую запись
--	и изменяем число месяцев размещения рекламы
--	в таблице acc_dog_body :

	update acc_dog_body
	set adr_id = @adr_id, date_from = @dt1, date_to = @dt2, price = @price,
		month_dif = @nmbc, upd_whom = @upd_whom, upd_when = getdate()
		where accb_id = @accb_id and acch_id = @acch_id
	
	if @@ROWCOUNT = 0
	begin
		rollback tran		--		rollback all transactions
		RAISERROR(' @@ROWCOUNT = 0 - Ошибка при изменении текущей записи в acc_dog_body !!!', 16, 1)
		return -1
	end

--	изменение записи в таблице acc_head: 
--	подсчет общей суммы по данной счет-фактуре
--	подсчет оплаченной суммы по данной счет-фактуре
--
	declare @paid as decimal(19,2), @for_pay as decimal(19,2)
	
	
	set @for_pay = (select sum(cast(for_pay as dec(19,2))) from acc_dog_body 
		group by acch_id having acch_id = @acch_id)
	
	update acc_head
		set for_pay = isnull(@for_pay,0) where acch_id = @acch_id
	if @@ROWCOUNT = 0
	begin
		rollback tran		--		rollback all transactions
		RAISERROR(' @@ROWCOUNT = 0 - Ошибка при изменении записи в таблице acc_head(for_pay) !!!',16, 1)
		return -1
	end
	
	set @paid = (select sum(cast(paid as dec(19,2))) from acc_pays 
		group by acch_id having acch_id = @acch_id)
	
	update acc_head
		set paid = isnull(@paid,0) where acch_id = @acch_id
	if @@ROWCOUNT = 0
	begin
		rollback tran		--		rollback all transactions
		RAISERROR(' @@ROWCOUNT = 0 - Ошибка при изменении записи в таблице acc_head(paid) !!!',16, 1)
		return -1
	end


--	обновление информации о количестве зависимых строк в таблице acc_dog_body :
	update acc_head
		set accb_count = (select count(accb_id) from acc_dog_body where acch_id = @acch_id)
		where acch_id = @acch_id


--	изменение записи в таблице dog_head: 
--	подсчет общей суммы, выставленной по всем счетам к этому договору
--	подсчет общей оплаченной суммы по данному договору

--
	declare @dogh_id int
	set @dogh_id = (select dogh_id from acc_head where acch_id = @acch_id)

	set @for_pay = (select sum(for_pay) from acc_head group by dogh_id having dogh_id = @dogh_id)
	
	update dog_head
		set for_pay = isnull(@for_pay,0) where dogh_id = @dogh_id
	if @@ROWCOUNT = 0
	begin
		rollback tran		--		rollback all transactions
		RAISERROR(' sp_acch_new: (@@ROWCOUNT = 0) - Ошибка при изменении записи в таблице dog_head(for_pay) !!!',16, 1)
		return -1
	end
--
--
	set @paid = (select sum(paid) from acc_head group by dogh_id having dogh_id = @dogh_id)
	
	update dog_head
		set paid = isnull(@paid,0) where dogh_id = @dogh_id
	if @@ROWCOUNT = 0
	begin
		rollback tran		--		rollback all transactions
		RAISERROR(' sp_acch_new: (@@ROWCOUNT = 0) - Ошибка при изменении записи в таблице dog_head(paid) !!!',16, 1)
		return -1
	end
	
while @@TRANCOUNT > 0
	commit tran		--		commit all open transactions


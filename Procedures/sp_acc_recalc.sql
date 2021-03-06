USE [Naruj]
GO
/****** Object:  StoredProcedure [dbo].[sp_acc_recalc]    Script Date: 27.02.2017 9:53:57 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO


ALTER      PROCEDURE [dbo].[sp_acc_recalc]
--	пересчет всех сумм из таблиц связанных с счет-фактурами и оплатой по ним
as
--	2 step:
--	exec sp_acc_recalc

--	3 step:
--	select * from acc_dog_body
--	select * from acc_free_body
--	select * from acc_pays
--	select * from acc_head

--	1 step:	--	определяем и открываем курсоры
declare @date_from as datetime, @date_to as datetime, @accb_id as int

DECLARE accb_cursor CURSOR
   FOR SELECT accb_id, date_from, date_to FROM acc_dog_body
OPEN accb_cursor

--	вычисляем число(дробное) месяцев
--	размещения рекламы :
declare @dt1 as datetime, @dt2 as datetime, @dt00 as datetime, @dt99 as datetime
declare @m1 as int, @m2 as int, @d1 as int, @d2 as int, @yy as int, @mm as int, @nmb int
declare @nmbc as dec(15,10), @nmbc1 as dec(15,10), @nmbc2 as dec(15,10)

--	выборка по одной строке
FETCH NEXT FROM accb_cursor 
INTO @accb_id, @date_from, @date_to

WHILE @@FETCH_STATUS = 0
BEGIN
	set @dt1 = @date_from
	set @dt2 = @date_to
	
	--select '@dt1' = @dt1, '@dt2' = @dt2, 'datediff(dd,@dt1,@dt2)' = datediff(dd,@dt1,@dt2)
	
	IF @dt1 > @dt2
	begin
		--	обновляем текущую запись
		--	и вычисленное число(дробное) месяцев размещения рекламы
		--	в таблице acc_dog_body :
		update acc_dog_body
			set month_dif = 0
			where accb_id = @accb_id
	
		--	выборка по следующей строки
		FETCH NEXT FROM accb_cursor 
		INTO @accb_id, @date_from, @date_to

		CONTINUE
	end
	
	--	первый месяц
	set @mm = datepart(month,@dt1)
	set @yy = datepart(year,@dt1)
	set @dt00 =  str(@mm) + '.01.' + str(@yy)
	
	if @mm = 12
		begin
			set @dt99 = '01.01.' + str(@yy + 1)
		end
	else
		begin
			set @dt99 =  str(@mm + 1) + '.01.' + str(@yy)
		end
	set @m1 = datediff(day,@dt00,@dt99)	--	общее кол-во дней в первом месяце
	set @d1 = datediff(day,@dt1,@dt99)		--	кол-во рекламных дней в первом месяце
	--	отношение кол-ва рекламных дней к общему кол-ву дней в первом месяце
	set @nmbc1 = cast(@d1 as dec(15,10)) / @m1
	
	--select @m1 as '@m1', @d1 as '@d1', @nmbc1 as '@nmbc1', 1000000 * @nmbc1 as '1000000*@nmbc1'

	--	последний месяц
	set @mm = datepart(month,@dt2)
	set @yy = datepart(year,@dt2)
	set @dt00 =  str(@mm) + '.01.' + str(@yy)
	
	if @mm = 12
		begin
			set @dt99 = '01.01.' + str(@yy + 1)
		end
	else
		begin
			set @dt99 =  str(@mm + 1) + '.01.' + str(@yy)
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
	
	--	обновляем текущую запись
	--	и вычисленное число(дробное) месяцев размещения рекламы
	--	в таблице acc_dog_body :
	update acc_dog_body
		set month_dif = @nmbc
		where accb_id = @accb_id

	--	выборка по следующей строки
	FETCH NEXT FROM accb_cursor 
	INTO @accb_id, @date_from, @date_to
end

--	закрываем курсор
CLOSE accb_cursor
DEALLOCATE accb_cursor

--	изменение записи в таблице acc_head: 
--	подсчет общей суммы по данной счет-фактуре
--	подсчет оплаченной суммы по данной счет-фактуре
--
declare @acch_id int, @paid as decimal(19,2), @for_pay as decimal(19,2), @is_free bit

DECLARE acch_cursor CURSOR
   FOR SELECT acch_id, is_free FROM acc_head
OPEN acch_cursor

--	выборка по одной строке
FETCH NEXT FROM acch_cursor 
INTO @acch_id, @is_free

WHILE @@FETCH_STATUS = 0
BEGIN

--	счета по договорам аренды
	if @is_free = 0
	begin

		set @for_pay = (select sum(cast(for_pay as dec(19,2))) from acc_dog_body 
			group by acch_id having acch_id = @acch_id)

--		обновление информации о количестве зависимых строк в таблице acc_dog_body :
		update acc_head
			set accb_count = (select count(accb_id) from acc_dog_body where acch_id = @acch_id)
			where acch_id = @acch_id
	end
	else	--	свободные счета
	begin

		set @for_pay = (select sum(cast(for_pay as dec(19,2))) from acc_free_body 
			group by acch_id having acch_id = @acch_id)

--		обновление информации о количестве зависимых строк в таблице acc_free_body :
		update acc_head
			set accb_count = (select count(accb_id) from acc_free_body where acch_id = @acch_id)
			where acch_id = @acch_id
	end

	update acc_head
		set for_pay = isnull(@for_pay,0)
		where acch_id = @acch_id

	set @paid = (select sum(cast(paid as dec(19,2))) from acc_pays 
		group by acch_id having acch_id = @acch_id)

	update acc_head
		set paid = isnull(@paid,0)
		where acch_id = @acch_id

	--	выборка по следующей строке
	FETCH NEXT FROM acch_cursor 
	INTO @acch_id, @is_free
end

--	закрываем курсор
CLOSE acch_cursor
DEALLOCATE acch_cursor

--	изменение записи в таблице dog_head: 
--	подсчет общей суммы, выставленной по всем счетам к этому договору
--	подсчет общей оплаченной суммы по данному договору
--
declare @dogh_id int, @is_del bit
--	, @paid as decimal(19,2), @paid2 as decimal(19,2)
--	, @for_paid as decimal(19,2), @for_paid2 as decimal(19,2)

DECLARE doghead_cursor CURSOR
   FOR SELECT dogh_id, is_del FROM dog_head
OPEN doghead_cursor

--	выборка по одной строке
FETCH NEXT FROM doghead_cursor 
INTO @dogh_id, @is_del

WHILE @@FETCH_STATUS = 0
BEGIN
	set @for_pay = (select sum(for_pay) from acc_head 
		group by dogh_id having dogh_id = @dogh_id)

	update dog_head
		set for_pay = isnull(@for_pay,0)
		where dogh_id = @dogh_id
--
--
	set @paid = (select sum(paid) from acc_head 
		group by dogh_id having dogh_id = @dogh_id)

	update dog_head
		set paid = isnull(@paid,0)
		where dogh_id = @dogh_id

	--	выборка по следующей строки
	FETCH NEXT FROM doghead_cursor 
	INTO @dogh_id, @is_del
end

--	закрываем курсор
CLOSE doghead_cursor
DEALLOCATE doghead_cursor




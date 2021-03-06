USE [Naruj]
GO
/****** Object:  StoredProcedure [dbo].[sp_dog_recalc]    Script Date: 27.02.2017 9:59:41 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO

ALTER    PROCEDURE [dbo].[sp_dog_recalc]
--	пересчет всех сумм из таблиц связанных с договорами аренды
as
--	2 step:
--	exec sp_dog_recalc

--	3 step:
--	select * from dog_body
--	select * from dog_dops
--	select * from dog_head

--	1 step:	--	определяем и открываем курсоры
declare @date_from as datetime, @date_to as datetime, @dogb_id as int

DECLARE dogb_cursor CURSOR
   FOR SELECT dogb_id, date_from, date_to FROM dog_body
OPEN dogb_cursor

--	вычисляем число(дробное) месяцев
--	размещения рекламы :
declare @dt1 as datetime, @dt2 as datetime, @dt00 as datetime, @dt99 as datetime
declare @m1 as int, @m2 as int, @d1 as int, @d2 as int, @yy as int, @mm as int, @nmb int
declare @nmbc as dec(15,10), @nmbc1 as dec(15,10), @nmbc2 as dec(15,10)

--	выборка по одной строке
FETCH NEXT FROM dogb_cursor 
INTO @dogb_id, @date_from, @date_to

WHILE @@FETCH_STATUS = 0
BEGIN
	set @dt1 = @date_from
	set @dt2 = @date_to
	
	--select '@dt1' = @dt1, '@dt2' = @dt2, 'datediff(dd,@dt1,@dt2)' = datediff(dd,@dt1,@dt2)
	
	IF @dt1 > @dt2
	begin
		--	обновляем текущую запись
		--	и вычисленное число(дробное) месяцев размещения рекламы
		--	в таблице claim_body :
		update dog_body
			set month_dif = 0
			where dogb_id = @dogb_id
	
		--	выборка по следующей строки
		FETCH NEXT FROM dogb_cursor 
		INTO @dogb_id, @date_from, @date_to

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
	--	в таблице claim_body :
	update dog_body
		set month_dif = @nmbc
		where dogb_id = @dogb_id

	--	выборка по следующей строки
	FETCH NEXT FROM dogb_cursor 
	INTO @dogb_id, @date_from, @date_to
end

--	закрываем курсор
CLOSE dogb_cursor
DEALLOCATE dogb_cursor

--
--	изменение записи в таблице dog_dops: подсчет суммы по данному доп.соглашению
--
declare @dop_id int, @is_del bit, @cost as decimal(19,2)

DECLARE dogdops_cursor CURSOR
   FOR SELECT dop_id, is_del FROM dog_dops
OPEN dogdops_cursor

--	выборка по одной строке
FETCH NEXT FROM dogdops_cursor 
INTO @dop_id, @is_del

WHILE @@FETCH_STATUS = 0
BEGIN
	set @cost = (select sum(cast(cost as dec(19,2))) from dog_body where is_del = 0 
		group by dop_id having dop_id = @dop_id)

	update dog_dops
		set cost = isnull(@cost,0)
		where dop_id = @dop_id

	--	выборка по следующей строки
	FETCH NEXT FROM dogdops_cursor 
	INTO @dop_id, @is_del
end

--	закрываем курсор
CLOSE dogdops_cursor
DEALLOCATE dogdops_cursor

--
--	изменение записи в таблице dog_head: подсчет суммы по данному договору и всем его доп.соглашениям
--
declare @dogh_id int	--, @is_del bit, @cost as decimal(19,2)

DECLARE doghead_cursor CURSOR
   FOR SELECT dogh_id, is_del FROM dog_head
OPEN doghead_cursor

--	выборка по одной строке
FETCH NEXT FROM doghead_cursor 
INTO @dogh_id, @is_del

WHILE @@FETCH_STATUS = 0
BEGIN
	set @cost = (select sum(cost) from dog_dops where is_del = 0 
		group by dogh_id having dogh_id = @dogh_id)
	
	update dog_head
		set cost = isnull(@cost,0)
		where dogh_id = @dogh_id

	--	выборка по следующей строки
	FETCH NEXT FROM doghead_cursor 
	INTO @dogh_id, @is_del
end

--	закрываем курсор
CLOSE doghead_cursor
DEALLOCATE doghead_cursor



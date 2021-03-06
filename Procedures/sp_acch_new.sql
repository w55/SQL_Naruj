USE [Naruj]
GO
/****** Object:  StoredProcedure [dbo].[sp_acch_new]    Script Date: 27.02.2017 9:54:37 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO


--	Администратор вставляет новую счет-фактуру по договору аренды рекламного места
--
ALTER                 PROCEDURE [dbo].[sp_acch_new]
	@upd_whom int, @dogh_id int, @consignee varchar(100), @is_insert_data bit = 0, @date_for_pay varchar(20),
	@date_from varchar(20) = NULL, @date_to varchar(20) = NULL, @reg_nmb varchar(30) = NULL output
AS
IF @upd_whom < 1
begin
	RAISERROR(' Ошибка добавления записи в таблицу acc_head: Номер пользователя (%d) - должен быть больше нуля !!!',
		16, 1, @upd_whom)
	return -1
end

IF NOT EXISTS(select * from dog_head where dogh_id = @dogh_id and is_del = 0)
begin
	RAISERROR(' Ошибка добавления записи в таблицу acc_head: Договор(внутр.иденф.: %d) - не найден в таблице dog_head ',
		16, 1, @dogh_id)
	return -1
end

IF @date_for_pay is null
begin
	RAISERROR(' Ошибочные входные параметры: не задан срок оплаты', 16, 1)
	return -1
end

IF @is_insert_data = 1 and (@date_from is null or @date_to is null)
begin
	RAISERROR(' Ошибочные входные параметры: не задана начальная или конечная даты', 16, 1)
	return -1
end
IF @is_insert_data = 1 and (convert(datetime, @date_from,104) > convert(datetime, @date_to,104))
begin
	RAISERROR(' Ошибочные входные параметры: начальная дата больше конечной даты', 16, 1)
	return -1
end

begin tran	--		start transaction

DECLARE @acc_nmbi int, @acc_nmbc varchar(20), @account_nmb int, @clienth_id int, @dbuser_id int

set @clienth_id = (select clienth_id from dog_head where (dogh_id = @dogh_id and is_del = 0))

---
--RAISERROR(' @clienth_id = %d ',16, 1, @clienth_id)
---

set @dbuser_id = (select dbuser_id from dog_head where (dogh_id = @dogh_id and is_del = 0))

---
---RAISERROR(' @dbuser_id = %d ',16, 1, @dbuser_id)
---

set @acc_nmbi = (select max(acc_nmbi) from acc_head where (acc_year = year(getdate()) and dbuser_id = @dbuser_id))
---
---RAISERROR(' @acc_nmbi = %d ',16, 1, @acc_nmbi)
---

set @acc_nmbi =  isnull(@acc_nmbi,0) + 1
---
--RAISERROR(' @acc_nmbi = %d ',16, 1, @acc_nmbi)
---

set @account_nmb = (select account_nmb from db_users where dbuser_id = @dbuser_id)
---set @acc_nmbc = rtrim(ltrim(str(@account_nmb))) + '/' + rtrim(ltrim(str(@acc_nmbi)))
---
---RAISERROR(' @account_nmb = %d ',16, 1, @account_nmb)
---


declare @len1 as int, @str1 as varchar(20), @str2 as varchar(20)

set @str1 = ltrim(rtrim(str(@acc_nmbi)))
---
---RAISERROR(' @str1 = %s ',16, 1, @str1)
---

set @len1 = len(@acc_nmbi)
---
---RAISERROR(' @len1 = %d ',16, 1, @len1)
---

if @len1 = 1
	set @str2 = '00' + @str1

if @len1 = 2
	set @str2 = '0' + @str1

if @len1 > 2
	set @str2 = @str1
---
---RAISERROR(' @str2 = %s ',16, 1, @str2)
---
---
---		new code since 20 mar 2006	>>>
---
--set @acc_nmbc = rtrim(ltrim(str(@account_nmb))) + '/' + rtrim(ltrim(@str2))
set @acc_nmbc = 'б/н'


---
---RAISERROR(' @acc_nmbc = %s ',16, 1, @acc_nmbc)
---

--
--	вставляем новую запись в таблицу acc_head:
--
insert acc_head(dbuser_id, acc_nmbi, acc_nmb, clienth_id, consignee, dogh_id, date_for_pay, upd_whom) 
	values(@dbuser_id, @acc_nmbi, @acc_nmbc, @clienth_id, @consignee, @dogh_id, 
		convert(datetime, @date_for_pay,104), @upd_whom)
if @@ROWCOUNT = 0
begin
	rollback tran		--		rollback all transactions
	RAISERROR(' sp_acch_new: (@@ROWCOUNT = 0) - Ошибка при вставке новой записи в таблицу acc_head !!!',16, 1)
	return -1
end

--	вставляем новые записи в таблицу acc_dog_body
--	редактируем соответствующие записи в таблицах acc_head и dog_head:
--
--
declare @acch_id int
set @acch_id = (select max(acch_id) from acc_head where dogh_id = @dogh_id)

IF @is_insert_data = 1
begin
	declare @dt1 as datetime, @dt2 as datetime, @dt00 as datetime, @dt99 as datetime, @str_date as varchar(30)
	declare @m1 as int, @m2 as int, @d1 as int, @d2 as int, @yy as int, @mm as int, @nmb int
	declare @nmbc as dec(15,10), @nmbc1 as dec(15,10), @nmbc2 as dec(15,10)

--
--	извлечение записей из таблицы dog_body: 
--
	declare @adr_id int, @date_from2 datetime, @date_to2 datetime, @price decimal(19,2)

--	определяем и открываем курсор
--
	DECLARE dogb_cursor CURSOR
	   FOR SELECT adr_id, date_from, date_to, price FROM dog_body
		inner join dog_dops on dog_body.dop_id = dog_dops.dop_id
		inner join dog_head on dog_dops.dogh_id = dog_head.dogh_id
			where dog_head.is_del = 0 and dog_dops.is_del = 0 and dog_body.is_del = 0 
				and dog_body.bit_add = 1
				and dog_head.dogh_id = @dogh_id
				and dog_body.date_from <= convert(datetime, @date_to,104)
				and dog_body.date_to >= convert(datetime, @date_from,104)

	OPEN dogb_cursor

--	выборка по одной строке
	FETCH NEXT FROM dogb_cursor 
	INTO @adr_id, @date_from2, @date_to2, @price
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
--		вычисляем число(дробное) месяцев
--		размещения рекламы :
--
		set @dt1 = convert(datetime, @date_from,104)
		if @dt1 < @date_from2
			set @dt1 = @date_from2

		set @dt2 = convert(datetime, @date_to,104)
		if @dt2 > @date_to2
			set @dt2 = @date_to2
--
		IF @dt1 > @dt2
		begin		
--			выборка по следующей строке
--
			FETCH NEXT FROM dogb_cursor 
			INTO @adr_id, @date_from2, @date_to2, @price
	
			CONTINUE
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
--	вставляем новую запись
--	и вычисленное число(дробное) месяцев размещения рекламы
--	в таблицу acc_dog_body :

		insert into acc_dog_body(acch_id, adr_id, date_from, date_to, price, month_dif, upd_whom)
	 		values(@acch_id, @adr_id, @dt1, @dt2, @price, @nmbc, @upd_whom)

		if @@ROWCOUNT = 0
		begin
			rollback tran		--		rollback all transactions
			RAISERROR(' dogb_cursor: (@@ROWCOUNT = 0) - Ошибка при вставке новой записи в acc_dog_body !!!', 16, 1)
			return -1
		end

--		выборка по следующей строке
		FETCH NEXT FROM dogb_cursor 
		INTO @adr_id, @date_from2, @date_to2, @price
	end

--	закрываем курсор
	CLOSE dogb_cursor
	DEALLOCATE dogb_cursor
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
	RAISERROR(' sp_acch_new: (@@ROWCOUNT = 0) - Ошибка при изменении записи в таблице acc_head(for_pay) !!!',16, 1)
	return -1
end

set @paid = (select sum(cast(paid as dec(19,2))) from acc_pays 
	group by acch_id having acch_id = @acch_id)

update acc_head
	set paid = isnull(@paid,0) where acch_id = @acch_id
if @@ROWCOUNT = 0
begin
	rollback tran		--		rollback all transactions
	RAISERROR(' sp_acch_new: (@@ROWCOUNT = 0) - Ошибка при изменении записи в таблице acc_head(paid) !!!',16, 1)
	return -1
end

--	обновление информации о количестве зависимых строк в таблице acc_dog_body :
update acc_head
	set accb_count = (select count(accb_id) from acc_dog_body where acch_id = @acch_id)
	where acch_id = @acch_id

--	изменение записи в таблице dog_head: 
--	подсчет общей суммы, выставленной по всем счетам к этому договору
--	подсчет общей оплаченной суммы по данному договору

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

--	возвращаемое значение: номер и дата новой счет-фактуры:
--
set @reg_nmb = @acc_nmbc + '  от  ' + convert(varchar(10), getdate(), 104)





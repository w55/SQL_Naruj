USE [Naruj]
GO
/****** Object:  StoredProcedure [dbo].[sp_acc_free_upd]    Script Date: 27.02.2017 9:53:25 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO


--	изменение текущей строки для текущей свободной счет-фактуры
--
ALTER    PROCEDURE [dbo].[sp_acc_free_upd]
	@upd_whom int, @accb_id int, @acch_id int, @goods varchar(100), @units varchar(20), @amount decimal(19,4),
	@price decimal(19,2), @acc_desc varchar(100) = NULL
AS
IF @upd_whom < 1
begin
	RAISERROR(' Ошибка изменения записи в таблице acc_free_body: Номер пользователя (%d) - должен быть больше нуля !!!',
		16, 1, @upd_whom)
	return -1
end

IF NOT EXISTS(select * from acc_head where acch_id = @acch_id and is_free = 1)
begin
	RAISERROR(' Ошибка изменения записи в таблице acc_free_body: Счет-фактура(вн/№ = %d) - не найдена в таблице acc_head ',
		16, 1, @acch_id)
	return -1
end

IF NOT EXISTS(select * from acc_free_body where accb_id = @accb_id)
begin
	RAISERROR(' Ошибка изменения записи в таблице acc_free_body: Запись(вн/№ = %d) - не найдена в таблице acc_free_body ',
		16, 1, @accb_id)
	return -1
end

--	если счет оплачен полностью - его нельзя редактировать	!!!
--
IF EXISTS(select * from acc_head where acch_id = @acch_id and for_pay <= paid)
begin
	RAISERROR(' Ошибка : Счет-фактура(вн/№ %d) - оплачена полностью - её нельзя редактировать !!! ',
		16, 1, @acch_id)
	return -1
end

IF NOT EXISTS(select * from acc_free_body where accb_id = @accb_id and (year(upd_when) = year(getdate()) 
	and month(upd_when) = month(getdate()) and day(upd_when) = day(getdate())))
begin
	RAISERROR(' Ошибка : Можно изменять только документы, внесенные сегодня !!! ', 16, 1)
	return -1
end

--RAISERROR(' Входные параметры приняты !!!', 16, 1)

begin tran	--		start transaction
--
--	изменение текущей строки для текущей счет-фактуры по договору аренды рекламного места

--	изменяем текущую запись
--	и изменяем число месяцев размещения рекламы
--	в таблице acc_free_body :

	update acc_free_body
	set goods = @goods, units = @units, amount = @amount, price = @price,
		acc_desc = @acc_desc, upd_whom = @upd_whom, upd_when = getdate()
		where accb_id = @accb_id and acch_id = @acch_id
	
	if @@ROWCOUNT = 0
	begin
		rollback tran		--		rollback all transactions
		RAISERROR(' @@ROWCOUNT = 0 - Ошибка при изменении текущей записи в acc_free_body !!!', 16, 1)
		return -1
	end

--	изменение записи в таблице acc_head:
--	подсчет общей суммы по данной счет-фактуре
--	подсчет оплаченной суммы по данной счет-фактуре
--
	declare @paid as decimal(19,2), @for_pay as decimal(19,2)
	
	
	set @for_pay = (select sum(cast(for_pay as dec(19,2))) from acc_free_body 
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


--	обновление информации о количестве зависимых строк в таблице acc_free_body :
	update acc_head
		set accb_count = (select count(accb_id) from acc_free_body where acch_id = @acch_id)
		where acch_id = @acch_id
	
while @@TRANCOUNT > 0
	commit tran		--		commit all open transactions
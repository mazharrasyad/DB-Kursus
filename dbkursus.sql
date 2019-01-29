-- Drop Table Jika Ada

drop table if exists pendaftaran_detail;
drop table if exists pendaftaran;
drop table if exists jadwal;
drop table if exists materi;
drop table if exists kursus;
drop table if exists pengajar;
drop table if exists peserta;
drop table if exists member;

-- Create Table

create table member(
	id serial primary key,
	nama varchar(50),
	no_hp varchar(20),
	jenis_kelamin char(1),
	alamat text
);

create table peserta(
	riwayat_pendidikan varchar(20),
	saldo double precision,
	primary key(id)
) inherits(member);

create table pengajar(
	gelar varchar(20),
	saldo double precision default 0,
	primary key(id)
) inherits(member);

create table kursus(
	id serial primary key,
	nama varchar(50),
	alamat text,
	saldo double precision default 0
);

create table materi(
	id serial primary key,
	nama varchar(50),
	biaya_perjadwal double precision,
	pengajar_id int references pengajar(id),
	kursus_id int references kursus(id)
);

create table jadwal(
	id serial primary key,
	materi_id int references materi(id),
	hari varchar(10),
	jam_mulai time,
	jam_selesai time,
	jumlah_peserta int default 0
);

create table pendaftaran(
	id serial primary key,
	peserta_id int references peserta(id),	
	tanggal date default now(),
	jumlah_jadwal int default 0,
	total_biaya double precision default 0,
	status varchar(20) default 'Pending'
);

create table pendaftaran_detail(
	pendaftaran_id int references pendaftaran(id),
	jadwal_id int references jadwal(id)
);

-- Function

create or replace function
update_pendaftaran() returns trigger as
$$
	declare
		in_i int;
		in_jadwal_id int;
		in_jumlah_jadwal int;
	
		in_materi_id int;
		in_biaya_perjadwal double precision;
	begin
		-- Get Data Table kursus
		select into in_materi_id materi_id from jadwal where id = new.jadwal_id;
		select into in_biaya_perjadwal biaya_perjadwal from materi where id = in_materi_id;
		
		-- Get Data Column jumlah_jadwal
		in_i = 0;
		in_jumlah_jadwal = 0;
		loop
			select into in_jadwal_id jadwal_id from pendaftaran_detail where pendaftaran_id = new.pendaftaran_id limit 1 offset in_i;			
								
			if in_jadwal_id is null then				
				exit;
			else
				in_jumlah_jadwal = in_jumlah_jadwal + 1;
			end if;			
			
			in_i = in_i + 1;				
		end loop;
	
		update pendaftaran set jumlah_jadwal = in_jumlah_jadwal, total_biaya = in_biaya_perjadwal * in_jumlah_jadwal where id = new.pendaftaran_id;
	
		return new;
	end
$$ language plpgsql;

create or replace function
bayar(int) returns text as
$$
	declare
		in_pendaftaran_id alias for $1;
		in_total_biaya double precision;
		
		in_peserta_id int;
		in_saldo_peserta double precision;
			
		in_jadwal_id int;
		in_materi_id int;		
		in_biaya_perjadwal double precision;
	
		in_kursus_id int;		
	begin
		-- Get Data Column total_biaya
		select into in_total_biaya total_biaya from pendaftaran where id = in_pendaftaran_id;
		
		-- Get Data Table peserta
		select into in_peserta_id peserta_id from pendaftaran where id = in_pendaftaran_id;
		select into in_saldo_peserta saldo from peserta where id = in_peserta_id;
		
		-- Get Data Table materi
		select into in_jadwal_id jadwal_id from pendaftaran_detail where pendaftaran_id = in_pendaftaran_id;
		select into in_materi_id materi_id from jadwal where id = in_jadwal_id;
	
		-- Get Data Table kursus
		select into in_kursus_id kursus_id from materi where id = in_materi_id;				
	
		-- Cek Saldo		
		if in_total_biaya <= in_saldo_peserta then
			update peserta set saldo = in_saldo_peserta - in_total_biaya where id = in_peserta_id;
			update kursus set saldo = saldo + in_total_biaya where id = in_kursus_id;
			update pendaftaran set status = 'Accept' where id = in_pendaftaran_id;
			return 'Berhasil Membayar, Kursus Dapat Dimulai';
		else
			return 'Saldo Tidak Cukup';
		end if;
	end
$$ language plpgsql;

create or replace function
tambah_peserta() returns trigger as
$$
	declare
		in_i int;
		in_jadwal_id int;
		in_status varchar;
	begin	
		-- Get Data Column status
		select into in_status status from pendaftaran where id = old.id;
		
		-- Get Data Column jumlah_peserta
		in_i = 0;
		loop			
			select into in_jadwal_id jadwal_id from pendaftaran_detail where pendaftaran_id = old.id limit 1 offset in_i;			
								
			if in_jadwal_id is null then				
				exit;
			elseif in_status = 'Accept' then
				update jadwal set jumlah_peserta = jumlah_peserta + 1 where id = in_jadwal_id;
			end if;			
			
			in_i = in_i + 1;				
		end loop;
				
		return new;
	end
$$ language plpgsql;

create or replace function
selesai(int) returns text as
$$
	declare
		in_pendaftaran_id alias for $1;
	begin
		update pendaftaran set status = 'Finish' where id = in_pendaftaran_id;
	
		return 'Kursus Selesai';
	end
$$ language plpgsql;

create or replace function
komisi() returns trigger as
$$
	declare
		in_status varchar;
		in_total_biaya double precision;
		in_jadwal_id int;	
		in_materi_id int;
		in_pengajar_id int;		
		in_kursus_id int;		
	begin
		select into in_status status from pendaftaran where id = old.id;
		select into in_total_biaya total_biaya from pendaftaran where id = old.id;
		select into in_jadwal_id jadwal_id from pendaftaran_detail where pendaftaran_id = old.id;
		select into in_materi_id materi_id from jadwal where id = in_jadwal_id;
		select into in_pengajar_id pengajar_id from materi where id = in_materi_id;
		select into in_kursus_id kursus_id from materi where id = in_materi_id;
		
		if in_status = 'Finish' then
			update kursus set saldo = saldo - (in_total_biaya * 0.10) where id = in_kursus_id;
			update pengajar set saldo = saldo + (in_total_biaya * 0.10) where id = in_pengajar_id;
		end if;
	
		return new;
	end			
$$ language plpgsql;

create or replace function
kurang_peserta() returns trigger as
$$
	declare
		in_i int;
		in_jadwal_id int;
		in_status varchar;
	begin	
		-- Get Data Column status
		select into in_status status from pendaftaran where id = old.id;
		
		-- Get Data Column jumlah_peserta
		in_i = 0;
		loop			
			select into in_jadwal_id jadwal_id from pendaftaran_detail where pendaftaran_id = old.id limit 1 offset in_i;			
								
			if in_jadwal_id is null then				
				exit;
			elseif in_status = 'Finish' then
				update jadwal set jumlah_peserta = jumlah_peserta - 1 where id = in_jadwal_id;
			end if;			
			
			in_i = in_i + 1;				
		end loop;
				
		return new;
	end
$$ language plpgsql;

-- Trigger

create trigger trig_update_pendaftaran after
insert on pendaftaran_detail for each row
execute procedure update_pendaftaran();

create trigger trig_tambah_peserta after
update on pendaftaran for each row
execute procedure tambah_peserta();

create trigger trig_komisi after
update on pendaftaran for each row
execute procedure komisi();

create trigger trig_kurang_peserta after
update on pendaftaran for each row
execute procedure kurang_peserta();

-- Insert table

insert into peserta values
(1, 'Ayu', '081234567891', 'P', 'Jakarta', 'SMA', 1000000),
(2, 'Farras', '081234567892', 'P', 'Bogor', 'SMK', 2000000);

insert into pengajar values
(3, 'Adi', '081234567893', 'L', 'Depok', 'S.Kom.', default),
(4, 'Panji', '081234567894', 'L', 'Bekasi', 'S.SI.', default);

insert into kursus values
(1, 'Kursus Pemrograman', 'Jakarta', default),
(2, 'Kursus Marketing', 'Depok', default);

insert into materi values
(1, 'PostgreSQL', 50000, 3, 1),
(2, 'Reseller', 100000, 4, 2);

insert into jadwal values
(1, 1, 'Senin', '08:00', '10:00', default),
(2, 1, 'Selasa', '10:00', '12:00', default),
(3, 2, 'Rabu', '13:00', '15:00', default),
(4, 2, 'Kamis', '16:00', '18:00', default);

insert into pendaftaran values
(1, 1, default, default, default, default),
(2, 2, default, default, default, default);

insert into pendaftaran_detail values
(1, 1),
(1, 2),
(2, 3),
(2, 4);

-- Select Table

select * from member;
select * from peserta;
select * from pengajar;
select * from kursus;
select * from materi;
select * from jadwal;
select * from pendaftaran;
select * from pendaftaran_detail;

-- Transaction

begin transaction;

select bayar(1);
select selesai(1);
select bayar(2);
select selesai(2);

rollback;
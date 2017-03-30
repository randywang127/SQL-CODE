
Login information:



		ssh ls@vm01.lovesystems.com
		Enter PWD: xLKDrL5zP6PkEi
	
	  	MYSQL:marketing.lovesystems.com
		Password:D$213fdGsdbn7


mysql -hlswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -umroot -plovesystems1640 dbl

==============================================================================================================================================================
LINUX:
cd=== change direction 
ls== list of file

GO TO THE MYSQL DATABASE:
mysql -hlswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -umroot -plovesystems1640  dbl



====== Whole Contact List SQL CODE

drop table ifs_whole_contact_stg_150803;
Create table ifs_whole_contact_stg_150803 (
id int(20),
first_name char(10),
last_name char(10),
birthday varchar(100),
phone_1 varchar(100),
phone_2 varchar(100),
phone_3 varchar(100),
Bill_city char(50),
Bill_state char(50),
Bill_country char(50),
Ship_city char(50),
Ship_state char(50),
Ship_country char(50),
email text,
opt_country char(50),
owner_id int(20),
ip_country char(50),
ip_city char(50),
ip_state char(50),
year_birth varchar(100));

create table donotcall as 
select  id , phone_1 from ifs_whole_contact_stg_150803 where right(phone_1,1) not REGEXP '^[0-9]+$' 
and phone_1<>" ";


mysql -hlswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -umroot -plovesystems1640  --execute="LOAD DATA LOCAL INFILE 'optin.csv' INTO TABLE ifs_optin_id_150713 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl

====
mysql -hlswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -umroot -plovesystems1640  --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE ifs_whole_contact_stg_150803 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl



ALTER TABLE ifs_whole_contact_stg_150803 ADD INDEX n (id);


alter table ifs_whole_contact_stg_150803 add birthday_1 varchar(20);

update ifs_whole_contact_stg_150803 set birthday_1 = right(birthday,4);

========== get cln dataset.
drop table ifs_whole_contact_cln_150803;
CREATE table ifs_whole_contact_cln_150803 AS
SELECT  id as contact_id,
first_name as first_name,
last_name as last_name,
IF(phone_1 IS NULL or phone_1 = '', phone_2, phone_1) as phone,
2015 - CONVERT(IF(birthday_1 = '', year_birth, birthday_1), UNSIGNED INTEGER) as age,
case
when Bill_country <> " " then Bill_country 
when Bill_country = " " and Ship_country <> " " then Ship_country
when Bill_country  = " " and Ship_country = " " and opt_country <> " " then opt_country
when Bill_country = " " and Ship_country = " " and opt_country = " " and 
ip_country <> " " then ip_country
end
as country,
case
when Bill_city <> " " then Bill_city 
when Bill_city = " " and Ship_city <> " " then Ship_city
when Bill_city = " " and Ship_city = " " and ip_city <> " " then ip_city
end
as city,
case
when Bill_state <> " " then Bill_state 
when Bill_state = " " and Ship_state <> " " then Ship_state
when Bill_state = " " and Ship_state = " " and ip_state <> " " then ip_state
end
as state,
email as email
FROM ifs_whole_contact_stg_150803;

==
UPDATE ifs_whole_contact_cln_150803
SET age = NULL 
WHERE age = 2015; 


UPDATE ifs_whole_contact_cln_150803
SET phone = " "
where right(phone,1) not REGEXP '^[0-9]+$';

select * from ifs_whole_contact_cln_150803 where right(phone,1) not REGEXP '^[0-9]+$' limit 200;

ALTER TABLE ifs_whole_contact_cln_150803 ADD INDEX n (contact_id);



====================CREATE IFS EXPORT TABLE  --- FROM IFS- EMAIL_B
drop table ifs_LSI_WSM_mail_blast_result_w15_32_1;
CREATE TABLE ifs_LSI_WSM_mail_blast_result_w15_32_1(
Contact_Id int(20),
First_Name varchar(20),
Last_Name varchar(20),
Batch_Id int(20),
Sent varchar(20), 
Opened varchar(20),
Clicked varchar(20),
Link_Clicked text);

===================
mysql -hlswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -umroot -plovesystems1640

mysql -hlswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -umroot -plovesystems1640 --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE ifs_LSI_WSM_mail_blast_result_w15_32_1 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl   "


UPDATE ifs_LSI_WSM_mail_blast_result_w15_32_1
SET Sent = STR_TO_DATE(Sent, '%m/%d/%Y');

UPDATE ifs_LSI_WSM_mail_blast_result_w15_32_1
SET Opened = STR_TO_DATE(Opened, '%m/%d/%Y');




===================

ALTER TABLE ifs_LSI_WSM_mail_blast_result_w15_32_1 ADD INDEX n (Batch_Id);


====================CREATE A EMAIL STATS TABLE -- export table from IFS brocast_report
## current week to last 7 weeks

CREATE TABLE ifs_mail_brocast_W15_32(
Batch_Id int(20),
template varchar(50));

ALTER TABLE ifs_mail_brocast_W15_32 CONVERT TO CHARACTER SET utf8;

=====================

## use PHP to import the csv file

select distinct template from ifs_mail_brocast_W15_32;

============================
ALTER TABLE ifs_mail_brocast_W15_32 ADD INDEX n1 (Batch_Id);


============================== CREATE LSI+WSM+curric+One_off TABLE

drop table phone_leads_w15_32_stg_1;
CREATE TABLE phone_leads_w15_32_stg_1 AS
(SELECT ifs_LSI_WSM_mail_blast_result_w15_32_1.*, 
  ifs_mail_brocast_W15_32.template
  FROM ifs_LSI_WSM_mail_blast_result_w15_32_1
  INNER JOIN ifs_mail_brocast_W15_32
        ON ifs_LSI_WSM_mail_blast_result_w15_32_1.Batch_Id = ifs_mail_brocast_W15_32.Batch_Id
);


==================================

ALTER TABLE phone_leads_w15_32_stg_1 CHANGE template segment varchar(20);

ALTER TABLE phone_leads_w15_32_stg_1 ADD INDEX n1 (Opened);
ALTER TABLE phone_leads_w15_32_stg_1 ADD INDEX nn (Contact_Id);


==============================================



======================== CREATE A LSI+WSM EMAIL+PHONE+SMS LIST

drop table phone_leads_w15_32_stg_1_2;
CREATE TABLE phone_leads_w15_32_stg_1_2 AS
(SELECT phone_leads_w15_32_stg_1.*,
ifs_whole_contact_cln_150803.phone,
ifs_whole_contact_cln_150803.country,
ifs_whole_contact_cln_150803.email as email_address
From phone_leads_w15_32_stg_1
	INNER JOIN ifs_whole_contact_cln_150803
		ON ifs_whole_contact_cln_150803.contact_id=phone_leads_w15_32_stg_1.Contact_Id);

ALTER table phone_leads_w15_32_stg_1_2 
add seg_country varchar(20);

select distinct country from phone_leads_w15_32_stg_1_2;

UPDATE phone_leads_w15_32_stg_1_2
SET seg_country = case
When country = "United States" THEN "Domestic" 
When country = "Canada" THEN "Domestic" 
When country = "USA" THEN "Domestic" 
When country = "US" THEN "Domestic" 
ELSE "International"
END;

ALTER TABLE phone_leads_w15_32_stg_1_2
ADD actions varchar(200); 

select distinct segment from phone_leads_w15_32_stg_1_2;

==================

SEGMENTS

[1]Don’t have number opened --- email -- fpc
[2]International number Opened -- email --- email fpc
[3]International number Opened and Clicked or bought -- Call
[4]Domestic number Opened ----  email and SMS
[5]Domestic Clicked or bought ---  Email, SMS, Call
======================


UPDATE phone_leads_w15_32_stg_1_2
SET actions = CASE
When Phone = "" THEN "seg1"
When Phone <> "" AND Clicked = "" AND seg_country = "International" THEN "seg2"
WHEN Phone <> "" AND Clicked <>"" AND seg_country = "International" THEN "seg3"
When Phone <> "" AND Clicked = "" AND seg_country = "Domestic" THEN "seg4"
WHEN Phone <> "" AND Clicked <> "" AND seg_country = "Domestic" THEN  "seg5"
ELSE "SOMETHING WORNG"
END;

select count(distinct Contact_id) from phone_leads_w15_32_stg_1_2 where phone <> " ";


====================== check the segmentation 
select actions, count(Contact_id) as ct from phone_leads_w15_32_stg_1_2 group by actions;


=======
live opty call list 
=======
create table ifs_opty_list_w15_32_stg (
contact_id int(20),
opp_id int(20),
opp varchar(100),
contact_name varchar(100),
phone_number text,
first_name varchar(50),
last_name varchar(50),
street varchar(100),
city char(20),
state char(20),
post_code int(20),
owner varchar(50),
stage char(20),
perecent varchar(50),
next_action_date varchar(100),
next_action text,
note text,
num_campaigns int(10),
status_id text,
objection varchar(70),
opp_leads text,
move_date varchar(50),
date_create varchar(100),
last_update varchar(100),
est_closed_date varchar(50),
order_revenue varchar(20),
colsed_date varchar(20),
loss_reson text);

mysql -hlswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -umroot -plovesystems1640  --execute="LOAD DATA LOCAL INFILE 'opty.csv' INTO TABLE ifs_opty_list_w15_32_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl

===============================


update ifs_opty_list_w15_32_stg
set next_action_date= LEFT(next_action_date,LOCATE(' ',next_action_date) - 1)
,date_create = LEFT(date_create,LOCATE(' ',date_create) - 1)
, last_update = LEFT(last_update,LOCATE(' ',last_update) - 1);

UPDATE ifs_opty_list_w15_32_stg
SET next_action_date = STR_TO_DATE(next_action_date, '%m/%d/%Y'),
date_create = STR_TO_DATE(date_create, '%m/%d/%Y'),
last_update = STR_TO_DATE(last_update, '%m/%d/%Y');


ALTER TABLE ifs_opty_list_w15_32_stg ADD INDEX n_1 (opp_id);
ALTER TABLE ifs_opty_list_w15_32_stg ADD INDEX n_2 (contact_id);


UPDATE ifs_opty_list_w15_32_stg
set owner = "Rob"
where owner = "Love Systems Advisor";

create table ifs_opty_list_w15_32 as 
	select 
	a.*,
	b.country
	from ifs_opty_list_w15_32_stg a 
	left join ifs_whole_contact_cln_150803 b 
	on a.contact_id = b.contact_id;


================================

======================  GET the Phone and SMS leads LIST WITH DUCPLICATED 

drop table phone_leads_weekly_W15_32_1;
CREATE TABLE phone_leads_weekly_W15_32_1 AS(
SELECT a.* , b.city,d.owner as opty_owner,d.stage,
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=", d.opp_id) as opty_link
FROM phone_leads_w15_32_stg_1_2 a 
LEFT JOIN ifs_whole_contact_cln_150803 b
ON a.Contact_id= b.contact_id
left join ifs_opty_list_w15_32 d
On a.Contact_id = d.contact_id
where 
a.actions = "seg3" or a.actions ="seg5"
);

ALTER TABLE phone_leads_weekly_W15_32_1
add time_city varchar(50);


update phone_leads_weekly_W15_32_1
set time_city = case
when (seg_country = "Domestic") and (phone <> " " and LEFT(phone,1) <> 1) then right(left(phone,4),3)
when (seg_country = "Domestic") and (phone <> " " and LEFT(phone,1) = 1)  then right(left(phone,6),3)
when city = " " and seg_country = "Domestic" then country
else country
end;

select phone from phone_leads_weekly_W15_32_1 where left(phone,1) = 1;
ALTER TABLE phone_leads_weekly_W15_32_1 ADD INDEX n1 (time_city);



===================

Invoice weekly sales TABLE

===================

Create table invoice_slae_weekly_W15_32_1 (
contact_id int(20),
name varchar(30),
phone varchar(50),
email varchar(100),
country varchar(30),
product text,
invoice varchar(20));


mysql -hlswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -umroot -plovesystems1640  --execute="LOAD DATA LOCAL INFILE 'invoice.csv' INTO TABLE invoice_slae_weekly_W15_32_1 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl

UPDATE invoice_slae_weekly_W15_32_1
SET invoice = CAST(REPLACE(REPLACE(IFNULL(invoice,0),',',''),'$','') AS DECIMAL(10,2));

alter table invoice_slae_weekly_W15_32_1
add seg_country varchar(20);

UPDATE invoice_slae_weekly_W15_32_1
SET seg_country = case
When country = "United States" THEN "Domestic" 
When country = "Canada" THEN "Domestic" 
When country = "USA" THEN "Domestic" 
When country = "US" THEN "Domestic" 
ELSE "International"
END;

ALTER TABLE invoice_slae_weekly_W15_32_1
add time_city varchar(50);

update invoice_slae_weekly_W15_32_1
set time_city = case
when ((seg_country = "Domestic" or country=" ") and phone <> " ") then right(left(phone, locate(')', phone)-1),3)
else country
end;

ALTER TABLE invoice_slae_weekly_W15_32_1 ADD INDEX n1 (time_city);


===================
CREAT TABLE OF SEG 3 OR SEG 5 FROM Invoice
===================


create or replace view phone_leads_inovoice_list_w15_32_1 as 
	select 
a.*, c.time_zone, d.owner as opty_owner,d.stage,
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=", d.opp_id) as opty_link
FROM invoice_slae_weekly_W15_32_1 a 
LEFT JOIN time_zone_lookup c 
ON a.time_city = c.city 
left join ifs_opty_list_w15_32 d
On a.Contact_id = d.contact_id
where (a.product like "BOOK%" OR 
a.product LIKE "IVS%" OR
a.product LIKE"%DVD%" or
a.product like "Online%"
or a.product like "%Vol%"
or a.product like "%Mini%" ) and 
a.invoice between 1 and 300
group by a.Contact_id;

select count(*) from phone_leads_inovoice_list_w15_32_1;

drop view phone_leads

=================
DOB
================
drop table DOB_weekly_check_list;
create table DOB_weekly_check_list as 
	select 
	a.contact_id,
	CONCAT(a.first_name," ",a.last_name) as name,
	"Bithday this week" as what_done,
	"DOB" as segment,
	if(a.country = "United States" or a.country = "Canada" or a.country = "US", "Seg5", "Seg3") as actions,
	a.phone,a.country,
	if(a.country = "United States" or a.country = "Canada" or a.country = "US", "Domestic", "International") as seg_country,
	b.owner,concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=", b.opp_id) as opty_link,
	b.stage
	from ifs_whole_contact_cln_150803 a
	left join ifs_opty_list_w15_32 b
	on a.contact_id = b.contact_id
	where 
	MONTH(a.DOB) = 07  
	and 
	a.phone <> " "
	and day(a.DOB) between 20 and 26
	;

ALTER TABLE DOB_weekly_check_list
add time_city varchar(50);

update DOB_weekly_check_list
set time_city = case
when country ="United States" or country = "Canada" or country = "US" and (phone <> " " and LEFT(phone,1) <> 1) then left(right(phone,10),3)
when country ="United States" or country = "Canada" or country = "US" and (phone <> " " and LEFT(phone,1) = 1)  then right(left(phone,4),3)
else country
end;

====================== create final result table

drop table phone_leads_final_report_w15_32_stg_1;
create table phone_leads_final_report_w15_32_stg_1 as
	select 
	Contact_id as contact_id,
	CONCAT (First_name," ", Last_name) as name,
	Link_Clicked as what_done,
	segment,
	actions,
	phone,country,seg_country,opty_owner,opty_link,stage,time_city,
	Sent,
	Opened,
	Clicked
	from phone_leads_weekly_W15_32_1
	union ALL

	select
	contact_id,
	name,
	product as what_done,
	"purchase" as segment,
	if(seg_country = "Domestic", "seg5","seg3") as actions,
	phone,country,seg_country,opty_owner,opty_link,stage,time_city,
	Null as Sent,
	Null as Opened,
	Null as Clicked
	from phone_leads_inovoice_list_w15_32_1;

ALTER table phone_leads_final_report_w15_32_stg_1 add rank int(20);

update phone_leads_final_report_w15_32_stg_1 
set 
rank =case
when segment = "purchase" then 6
when segment = "fpc" then 5
when segment = "wsm" then 4
when segment = "DOB" then 3
when segment = "one-off" then 2
when segment = "lsi" then 1
when segment = "curric" then 0
end;

ALTER TABLE phone_leads_final_report_w15_32_stg_1 ADD INDEX n1 (time_city);



UPDATE phone_leads_final_report_w15_32_stg_1
SET Sent = STR_TO_DATE(Sent, '%m/%d/%Y');


drop view phone_leads_final_report_w15_32_stg_1_new;
drop view phone_leads_final_report_w15_32_stg_1_old;


ALTER TABLE phone_leads_final_report_w15_32_stg_1 ADD INDEX n1 (contact_id);
ALTER TABLE phone_leads_final_report_w15_32_stg_1 ADD INDEX n2 (rank);

drop table phone_leads_final_report_w15_32_stg_1_new;
drop table phone_leads_final_report_w15_32_stg_1_old;

create table phone_leads_final_report_w15_32_stg_1_new as 
	select a.*
	from 
	phone_leads_final_report_w15_32_stg_1 a
	left join phone_leads_final_report_w15_32_stg_1 b
	on 
	a.contact_id = b.contact_id
	and b.rank>a.rank 
	left join  phone_leads_final_report_w15_32_stg_1 c
	on c.contact_id = a.contact_id 
	and c.rank = a.rank
	where a.Sent >= "2015-07-20" or a.segment = "purchase" or a.segment = "DOB";

create table phone_leads_final_report_w15_32_stg_1_old as 
	select a.*
	from 
	phone_leads_final_report_w15_32_stg_1 a
	left join phone_leads_final_report_w15_32_stg_1 b
	on 
	a.contact_id = b.contact_id
	and b.rank>a.rank 
	left join  phone_leads_final_report_w15_32_stg_1 c
	on c.contact_id = a.contact_id 
	and c.rank = a.rank
	where a.Sent < "2015-07-20";

drop table phone_leads_final_report_w15_32_stg_1_2;

ALTER TABLE phone_leads_final_report_w15_32_stg_1_new ADD INDEX n1 (contact_id);
ALTER TABLE phone_leads_final_report_w15_32_stg_1_old ADD INDEX n1 (contact_id);

ALTER TABLE phone_leads_final_report_w15_32_stg_1_new ADD INDEX n2 (rank);
ALTER TABLE phone_leads_final_report_w15_32_stg_1_old ADD INDEX n2 (rank);

drop table phone_leads_final_report_w15_32_stg_1_2;
create table phone_leads_final_report_w15_32_stg_1_2 as 
SELECT a.*, "New" as type
FROM   phone_leads_final_report_w15_32_stg_1_new a
JOIN   (
           SELECT   contact_id, MAX(rank) max_rank
           FROM     phone_leads_final_report_w15_32_stg_1_new
           GROUP BY contact_id
       ) sub_p ON (sub_p.contact_id = a.contact_id AND 
                   sub_p.max_rank = a.rank)
GROUP BY a.contact_id

union all 

SELECT a.*, "Old" as type
FROM   phone_leads_final_report_w15_32_stg_1_old a
JOIN   (
           SELECT   contact_id, MAX(rank) max_rank
           FROM     phone_leads_final_report_w15_32_stg_1_old
           GROUP BY contact_id
       ) sub_p ON (sub_p.contact_id = a.contact_id AND 
                   sub_p.max_rank = a.rank)
GROUP BY a.contact_id;


select count(contact_id) from phone_leads_final_report_w15_32_stg_1_2;

select count(distinct contact_id) from phone_leads_final_report_w15_32_cln;

drop table phone_leads_final_report_w15_32_cln_1_2;
create table phone_leads_final_report_w15_32_cln_1_2 as 
	select a.*,
	b.CC, b.time_zone
	from 
	phone_leads_final_report_w15_32_stg_1_2 a
	left join 
	time_zone_lookup b
	on a.time_city = b.city;



update phone_leads_final_report_w15_32_cln_1_2
	set time_zone = "PST + 3 or PST"
	WHERE seg_country = "Domestic" and time_zone is null;


select count(contact_id) from phone_leads_final_report_w15_32_cln_1_2;

select distinct stage from phone_leads_final_report_w15_32_cln_1_2;

create table phone_leads_w15_32_no_call (
id int(20),
reason varchar(20)
);


ALTER TABLE phone_leads_w15_32_no_call ADD INDEX n1 (id);

drop table phone_leads_final_report_w15_32_cln_31;

create table phone_leads_final_report_w15_32_cln_31 as 
	select 
	a.*,
	b.reason
	from phone_leads_final_report_w15_32_cln_1_2 a 
	left join phone_leads_w15_32_no_call b
	on a.contact_id = b.id;

delete from phone_leads_final_report_w15_32_cln_31 where reason is not null;

ALTER TABLE phone_leads_final_report_w15_32_cln_31 ADD INDEX n1 (contact_id);


drop table phone_leads_final_report_w15_32_auto_31;
create table phone_leads_final_report_w15_32_auto_31 as 
	select 
	contact_id,
	name,
	CONCAT("https://lovesystems.infusionsoft.com/Contact/manageContact.jsp?view=edit&ID=",contact_id) as link,
	phone,
	country,
	what_done,
	time_zone,
	CC,
	opty_owner,
	opty_link,stage
	from phone_leads_final_report_w15_32_cln_31
	where 
	((stage = "Won" or stage = "Lost") and seg_country = "Domestic")
	or 
	(stage is null and seg_country = "Domestic");

DROP table phone_leads_final_report_w15_32_manual_31;
create table phone_leads_final_report_w15_32_manual_31 as 
	select 
	contact_id,
	name,
	CONCAT("https://lovesystems.infusionsoft.com/Contact/manageContact.jsp?view=edit&ID=",contact_id) as link,
	phone,
	country,
	what_done,
	time_zone,
	CC,
	opty_owner,
	opty_link,stage
	from phone_leads_final_report_w15_32_cln_31
	where 
	 seg_country = "International" 
	 and 
	 (stage is null or stage = "Won" or stage = "Lost");

DROP table phone_leads_final_report_w15_32_awakend;
create table phone_leads_final_report_w15_32_awakend as 
	select 
	contact_id,
	name,
	CONCAT("https://lovesystems.infusionsoft.com/Contact/manageContact.jsp?view=edit&ID=",contact_id) as link,
	phone,
	country,
	what_done,
	time_zone,
	CC,
	opty_owner,
	opty_link,stage
	from phone_leads_final_report_w15_32_cln
	where 
	stage  = "Working" or stage = "New";


select * from phone_leads_final_report_w15_32_cln where segment = "purchase" and seg_country = "Domestic";
select count(contact_id) from phone_leads_final_report_w15_32_cln;
select count(contact_id) from phone_leads_final_report_w15_32_awakend;
select count(contact_id) from phone_leads_final_report_w15_32_manual;
select count(contact_id) from phone_leads_final_report_w15_32_auto;


=======
live opty call list 
=======
create table ifs_opty_list_w15_32_stg (
contact_id int(20),
opp_id int(20),
opp varchar(100),
contact_name varchar(100),
phone_number text,
first_name varchar(50),
last_name varchar(50),
street varchar(100),
city char(20),
state char(20),
post_code int(20),
owner varchar(50),
stage char(20),
perecent varchar(50),
next_action_date varchar(100),
next_action text,
note text,
num_campaigns int(10),
status_id text,
objection varchar(70),
opp_leads text,
move_date varchar(50),
date_create varchar(100),
last_update varchar(100),
est_closed_date varchar(50),
order_revenue varchar(20),
colsed_date varchar(20),
loss_reson text);

mysql -hlswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -umroot -plovesystems1640  --execute="LOAD DATA LOCAL INFILE 'opty.csv' INTO TABLE ifs_opty_list_w15_32_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl

===============================


update ifs_opty_list_w15_32_stg
set next_action_date= LEFT(next_action_date,LOCATE(' ',next_action_date) - 1)
,date_create = LEFT(date_create,LOCATE(' ',date_create) - 1)
, last_update = LEFT(last_update,LOCATE(' ',last_update) - 1);

UPDATE ifs_opty_list_w15_32_stg
SET next_action_date = STR_TO_DATE(next_action_date, '%m/%d/%Y'),
date_create = STR_TO_DATE(date_create, '%m/%d/%Y'),
last_update = STR_TO_DATE(last_update, '%m/%d/%Y');


ALTER TABLE ifs_opty_list_w15_32_stg ADD INDEX n_1 (opp_id);
ALTER TABLE ifs_opty_list_w15_32_stg ADD INDEX n_2 (contact_id);


UPDATE ifs_opty_list_w15_32_stg
set owner = "Rob"
where owner = "Love Systems Advisor";

create table ifs_opty_list_w15_32 as 
	select 
	a.*,
	b.country
	from ifs_opty_list_w15_32_stg a 
	left join ifs_whole_contact_cln_150803 b 
	on a.contact_id = b.contact_id;


================================


create table fpc_blast_list_w15_32_stg as 
	select Contact_id,segment,actions
	from phone_leads_w15_32_stg_1_2
	where actions ="seg1"
	or actions ="seg2"
	or actions ="seg4"

	union all 
	select 
	contact_id,segment,actions
	from 
	phone_leads_final_report_w15_32_cln
	where 
	actions = "seg5"
	or actions = "seg3";


ALTER table fpc_blast_list_w15_32_stg add rank int(20);

update fpc_blast_list_w15_32_stg 
set 
rank =case
when actions = "seg5" then 5
when actions = "seg4" then 4
when actions = "seg3" then 3
when actions = "seg2" then 2
when actions = "seg1" then 1
end;


select distinct actions from phone_leads_w15_32_stg_1_2;
alter table fpc_blast_list_w15_32_stg add index rw (rank);

alter table fpc_blast_list_w15_32_stg add index rw_1 (contact_id);

create table fpc_blast_list_w15_32_stg_2 as 
	select a.*
	from 
	fpc_blast_list_w15_32_stg a
	left join fpc_blast_list_w15_32_stg b
	on 
	a.contact_id = b.contact_id
	and b.rank>a.rank 
	left join  fpc_blast_list_w15_32_stg c
	on c.contact_id = a.contact_id 
	and c.rank = a.rank;

alter table fpc_blast_list_w15_32_stg_2 add index rw (rank);

alter table fpc_blast_list_w15_32_stg_2 add index rw_1 (contact_id);

create table fpc_blast_list_w15_32_cln as 
SELECT a.*
FROM   fpc_blast_list_w15_32_stg_2 a
JOIN   (
           SELECT   contact_id, MAX(rank) max_rank
           FROM     fpc_blast_list_w15_32_stg_2
           GROUP BY contact_id
       ) sub_p ON (sub_p.contact_id = a.contact_id AND 
                   sub_p.max_rank = a.rank)
GROUP BY a.contact_id;

alter table fpc_blast_list_w15_32_cln add num int(10);

update fpc_blast_list_w15_32_cln 
	set num = FLOOR(10000 + RAND() * 89999);



select count(contact_id),actions from fpc_blast_list_w15_32_cln group by actions;

create or replace view weekly_responders_analysis_report as 
select "W15.28" as week, count(distinct contact_id),segment,actions from fpc_blast_list_w15_32_cln 
group by segment,actions
union all 
select "W15.27" as week,count(distinct contact_id),segment,actions from fpc_blast_list_w15_27_cln 
group by segment,actions;

select count(distinct contact_id),actions from phone_leads_final_report_w15_32_cln 
group by actions;

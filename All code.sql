
Login information:



		ssh ls@vm01.lovesystems.com
		Enter PWD: xLKDrL5zP6PkEi
	
	  	MYSQL:marketing.lovesystems.com
		Password:lovesystems1640



==============================================================================================================================================================
LINUX:
cd=== change direction 
ls== list of file

GO TO THE MYSQL DATABASE:
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' dbl

== Get Unclean dataset-----FROM (ifs_export_mysql)

Create table ifs_contact_stg_150428 (
id int(20),
first_name char(10),
last_name char(10),
birthday varchar(100),
phone_1 varchar(100),
phone_2 varchar(100),
email text,
country char(30),
data_created varchar(50),
lead_source varchar(50),
ip_country char(30),
job char(30),
education char(30),
year_birth varchar(100));

====

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE ifs_whole_contact_stg_150428 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl

== 
update ifs_contact_stg_150428 set birthday = right(birthday,4);

UPDATE ifs_contact_stg_150428
SET data_created = LEFT(data_created, locate(' ', data_created) - 1)
WHERE locate(' ',data_created) > 0;


========== get cln dataset.
CREATE TABLE ifs_contact_CLN_150428 (PRIMARY KEY (contact_id)) AS
SELECT  id as contact_id,
first_name as first_name,
last_name as last_name,
IF(phone_1 IS NULL or phone_1 = '', phone_2, phone_1) as phone,
2015 - CONVERT(IF(birthday = '', year_birth, birthday), UNSIGNED INTEGER) as age,
IF(country IS NULL or country = '', ip_country, country) as country,
email as email,
data_created as date_created,
lead_source as lead_source,
job as job,
education as education
FROM ifs_contact_stg_150428;


==
UPDATE ifs_contact_CLN_150428
SET age = NULL 
WHERE age = 2015; 

UPDATE ifs_contact_CLN_150428
SET date_created = STR_TO_DATE(date_created, '%m/%d/%Y');

ALTER TABLE ifs_contact_CLN_150428
ADD life_time int(20) AFTER date_created;


UPDATE ifs_contact_CLN_150428
SET life_time = DATEDIFF(CURRENT_DATE, date_created);

update ifs_contact_CLN_150428
SET life_time = -1
WHERE date_created <= "2013-07-08" or date_created is null;


ALTER TABLE ifs_contact_CLN_150428 ADD INDEX n (contact_id);

ALTER TABLE ifs_contact_CLN_150428 ADD INDEX n_1 (date_created);

ALTER TABLE ifs_contact_CLN_150428 ADD INDEX n_2 (date_created,contact_id);



=== get total spending dataset uncleaned  --- from (ifs_dbl_spend_sql_export)

CREATE TABLE ifs_invoice_stg_150428 (
order_id int(20),
contact_id int(20),
description text,
First_name varchar(20),
Last_name varchar(20),
product_id text,
inv_total varchar(20),
balance varchar(20),
date varchar(50),
lead_source text);

====
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE ifs_invoice_stg_150428 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl

== 

=============== CREATE A CLN TABLE FOR INVOIVE_STG

CREATE TABLE ifs_invoice_cln_150428
AS SELECT *
FROM ifs_invoice_stg_150428;

ALTER TABLE ifs_invoice_cln_150428 DROP lead_source;

UPDATE ifs_invoice_cln_150428
SET inv_total = CAST(REPLACE(REPLACE(IFNULL(inv_total,0),',',''),'$','') AS DECIMAL(10,2));

UPDATE ifs_invoice_cln_150428
SET balance = CAST(REPLACE(REPLACE(IFNULL(balance,0),',',''),'$','') AS DECIMAL(10,2));

UPDATE ifs_invoice_cln_150428
SET date = STR_TO_DATE(date, '%m/%d/%Y');



ALTER TABLE ifs_invoice_cln_150428 MODIFY inv_total DECIMAL(10,2);

ALTER TABLE ifs_invoice_cln_150428 MODIFY balance DECIMAL(10,2);


ALTER TABLE ifs_invoice_cln_150428
ADD inv_paid DECIMAL(10,2) AFTER balance;

UPDATE ifs_invoice_cln_150428
SET inv_paid = inv_total-balance;


======== CREATE a CLEAN TABLE OF TOTAL SPEND

CREATE TABLE ifs_total_spend_CLN_150428
AS SELECT contact_id as contact_id,
first_name as first_name,
last_name as last_name,
lead_source as lead_source,
SUM(inv_total) as total_spend,
SUM(inv_paid) as total_paid
FROM ifs_invoice_cln_150428 
GROUP BY contact_id;

===========  CREATE INDEX FOR ID FOR STG AND CLN table

ALTER TABLE ifs_invoice_stg_150428 ADD INDEX n (contact_id);

ALTER TABLE ifs_total_spend_CLN_150428 ADD INDEX n (contact_id);

============  CREATE CUSTOMER VALUE TABLE 

CREATE TABLE cdb_customer_spend_profile_stg_150428 AS
SELECT contact_id as contact_id,
first_name as first_name,
last_name as last_name,
date_created as date_created ,
life_time as life_time,
lead_source as lead_source
From ifs_contact_CLN_150428;

------

-------

ALTER TABLE cdb_customer_spend_profile_stg_150428 ADD INDEX n (contact_id);

ALTER TABLE cdb_customer_spend_profile_stg_150428 ADD INDEX n1 (date_created);

--------- Create table of unclean spending for stg_2 


CREATE TABLE cdb_customer_spend_profile_stg_2_150428 AS(
 SELECT a.*
  , b.date_created
  , b.lead_source
 , -(datediff(b.date_created, a.date)) AS lifecycle_day 
 FROM ifs_invoice_cln_150428 a
  LEFT JOIN ifs_contact_CLN_150428 b 
  on (a.contact_id = b.contact_id));


CREATE INDEX ifs_invoice_2_150428__contact_id on cdb_customer_spend_profile_stg_2_150428(contact_id);


=============================================


------------------------------
-- cdb_cust_spend_profile_150428
------------------------------

CREATE TABLE cdb_cust_spend_profile_150428 as(
 SELECT a.contact_id
  , a.first_name
  , a.last_name
  , a.date_created
  , a.life_time
  , a.lead_source
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 1 and a.life_time >= 0 ) then b.inv_total 
              WHEN (a.life_time >= 0) then 0
              else null end)) AS cv1d_ts
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 1 and a.life_time >= 0) then b.inv_paid 
              WHEN (a.life_time >= 0) then 0
              else null end)) AS cv1d_tp
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 7 and a.life_time > 1) then b.inv_total 
              WHEN (a.life_time >= 1) then 0
              else null end)) AS cv7d_ts
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 7 and a.life_time > 1) then b.inv_paid 
              WHEN (a.life_time >= 1) then 0
              else null end)) AS cv7d_tp
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 30 and a.life_time > 7) then b.inv_total 
              WHEN (a.life_time >= 7) then 0
              else null end)) AS cv30d_ts
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 30 and a.life_time > 7) then b.inv_paid 
              WHEN (a.life_time >= 7) then 0
              else null end)) AS cv30d_tp
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 182 and a.life_time > 30) then b.inv_total 
              WHEN (a.life_time >= 30) then 0
              else null end)) AS cv182d_ts
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 182 and a.life_time > 30) then b.inv_paid 
              WHEN (a.life_time >= 30) then 0
              else null end)) AS cv182d_tp
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 365 and a.life_time > 182) then b.inv_total 
              WHEN (a.life_time >= 182) then 0
              else null end)) AS cv365d_ts
  , sum((case 
              when (b.lifecycle_day BETWEEN 0 AND 365 and a.life_time > 182) then b.inv_paid 
              WHEN (a.life_time >= 182) then 0
              else null end)) AS cv365d_tp
  , (case 
              when isnull(sum(b.inv_total)) then 0 else sum(b.inv_total) end) AS cvlife_ts  
  , (case 
              when isnull(sum(b.inv_paid)) then 0 else sum(b.inv_paid) end) AS cvlife_tp
  FROM ifs_contact_CLN_150428 a
  LEFT JOIN cdb_customer_spend_profile_stg_2_150428 b
  ON (a.contact_id = b.contact_id)
  GROUP BY contact_id);

select * from cdb_customer_spend_profile_stg_2_150428 where contact_id=3096860;

CREATE INDEX cdb_cust_spend_profile_150428 on cdb_cust_spend_profile_150428 (contact_id);


=================================

CREATE TABLE cdb_value_by_leadsource 
SELECT a.lead_source,
avg(a.cv1d_ts) as a_cv1d_ts,
count(a.cv1d_ts) as c_cv1d_ts,
sum(a.cv1d_ts) as s_cv1d_ts,
avg(a.cv1d_tp) as a_cv1d_tp,
count(a.cv1d_tp) as c_cv1d_tp,
sum(a.cv1d_tp) as s_cv1d_tp,
avg(a.cv7d_ts) as a_cv7d_ts,
count(a.cv7d_ts) as c_cv7d_ts,
sum(a.cv7d_ts) as s_cv7d_ts,
avg(a.cv7d_tp) as a_cv7d_tp,
count(a.cv7d_tp) as c_cv7d_tp,
sum(a.cv7d_tp) as s_cv7d_tp,
avg(a.cv30d_ts) as a_cv30d_ts,
count(a.cv30d_ts) as c_cv30d_ts,
sum(a.cv30d_ts) as s_cv30d_ts,
avg(a.cv30d_tp) as a_cv30d_tp,
count(a.cv30d_tp) as c_cv30d_tp,
sum(a.cv30d_tp) as s_cv30d_tp,
avg(a.cv182d_ts) as a_cv182d_ts,
count(a.cv182d_ts) as c_cv182d_ts,
sum(a.cv182d_ts) as s_cv182d_ts,
avg(a.cv182d_tp) as a_cv182d_tp,
count(a.cv182d_tp) as c_cv182d_tp,
sum(a.cv182d_tp) as s_cv182d_tp,
avg(a.cv365d_ts) as a_cv365d_ts,
count(a.cv365d_ts) as c_cv365d_ts,
sum(a.cv365d_ts) as s_cv365d_ts,
avg(a.cv365d_tp) as a_cv365d_tp,
count(a.cv365d_tp) as c_cv365d_tp,
sum(a.cv365d_tp) as s_cv365d_tp,
avg(a.cvlife_ts) as a_cvlife_ts,
count(a.cvlife_ts) as c_cvlife_ts,
sum(a.cvlife_ts) as s_cvlife_ts,
avg(a.cvlife_tp) as a_cvlife_tp,
count(a.cvlife_tp) as c_cvlife_tp,
sum(a.cvlife_tp) as s_cvlife_tp
from cdb_cust_spend_profile_150428 a
where a.date_created > "2013-07-08"
group by a.lead_source;

------------stats summary:
select count(*) from cdb_value_by_leadsource;

select sum(c_cvlife_ts) from cdb_value_by_leadsource;

select sum(s_cvlife_ts) from cdb_value_by_leadsource;


select * from cdb_cust_spend_profile_150428 where cv1d_ts is not null;


-------------

======= Create a UNCLEAN Table for CUSOTMER ACTIVITIES

CREATE TABLE ifs_customer_activities_Unclean_4_23
(Id int(20),
First_name varchar(20),
Last_name varchar(20),
Email Text,
Batch_id int(20),
Sent varchar(20),
Opened varchar(20),
Clicked varchar(20),
Link text);

=============

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE ifs_customer_activities_Unclean_4_23 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS dbl


============= CREATE A CLEAN ACTIVITY TABLE


CREATE TABLE ifs_customer_activities_CLN_4_23
AS SELECT Id as Contact_id,
First_name as First_name,
Last_name as Last_name,
Email as Email,
Sent as Date_sent,
SUM(CONVERT(IF(Opened = '', 0, 1), UNSIGNED INTEGER)) Num_Opened,
SUM(CONVERT(IF(Clicked = '', 0, 1), UNSIGNED INTEGER)) Num_Clicked
FROM ifs_customer_activities_Unclean_4_23
GROUP BY Id;

===================


UPDATE ifs_customer_activities_Unclean_4_23 SET Sent = str_to_date( Sent, '%m/%d/%Y');




======================= CREATE DATABASE FOR PHONE CONSULT MAIL OUT LIST

CREATE TABLE ifs_phone_consult_mail_out_list_4_27_2015
(id int(20),
segment Text);



============================

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'consult_mail_out.csv' INTO TABLE ifs_phone_consult_mail_out_list_4_27_2015 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS dbl



====================

ALTER TABLE ifs_phone_consult_mail_out_list_4_27_2015 ADD INDEX n (id);




======================  CREATE DATABASE FOR SBM CUSTOMER LIST
CREATE TABLE ifs_phone_consult_SBM_list_7_14_2015
(
date varchar(30),
provider varchar(20),	
Name varchar(20),
Email text,
Phone_number varchar(30),
Id int(20));

UPDATE ifs_phone_consult_SBM_list_7_14_2015
SET date = STR_TO_DATE(date, '%m.%d.%Y');

==========================

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'SBMcustomerlist.csv' INTO TABLE ifs_phone_consult_SBM_list_4_23_2015 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS dbl


==========================  CREATE A MASTER PROFILE BASED ON THE ACTIVITES, INFO, SPEND

CREATE TABLE ifs_master_profile_4_23_2015 AS 
  (SELECT ifs_opt_customer_info_CLN.*, 
          ifs_total_spend_CLN.total_invoice_amt
   FROM   ifs_opt_customer_info_CLN
          LEFT JOIN ifs_total_spend_CLN
                  ON ifs_opt_customer_info_CLN.Contact_id = ifs_total_spend_CLN.Contact_id);

======================================================

CREATE TABLE ifs_master_profile_4_23_2015_1 AS
(SELECT ifs_master_profile_4_23_2015.*, 
  ifs_phone_consult_mail_out_list_4_27_2015.segment
  FROM ifs_master_profile_4_23_2015
  LEFT JOIN ifs_phone_consult_mail_out_list_4_27_2015
        ON ifs_master_profile_4_23_2015.Contact_id = ifs_phone_consult_mail_out_list_4_27_2015.id
);


UPDATE ifs_master_profile_4_23_2015_1
SET segment = "N"
WHERE segment IS NULL;

ALTER TABLE ifs_master_profile_4_23_2015_1
  DROP send_phone_inv_4_10;

===============================================================================================================================================================

=== get total spending dataset uncleaned  --- from (ifs_dbl_spend_sql_export)

CREATE TABLE ifs_invoice_stg_150510 (
order_id int(20),
contact_id int(20),
description text,
First_name varchar(20),
Last_name varchar(20),
product_id text,
inv_total varchar(20),
balance varchar(20),
date varchar(50),
lead_source text);

====
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE ifs_invoice_stg_150510 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl

== 

=============== 

UPDATE ifs_invoice_stg_150510
SET inv_total = CAST(REPLACE(REPLACE(IFNULL(inv_total,0),',',''),'$','') AS DECIMAL(10,2));

UPDATE ifs_invoice_stg_150510
SET balance = CAST(REPLACE(REPLACE(IFNULL(balance,0),',',''),'$','') AS DECIMAL(10,2));

UPDATE ifs_invoice_stg_150510
SET date = STR_TO_DATE(date, '%m/%d/%Y');



ALTER TABLE ifs_invoice_stg_150510 MODIFY inv_total DECIMAL(10,2);

ALTER TABLE ifs_invoice_stg_150510 MODIFY balance DECIMAL(10,2);


ALTER TABLE ifs_invoice_stg_150510
ADD inv_paid DECIMAL(10,2) AFTER balance;

UPDATE ifs_invoice_stg_150510
SET inv_paid = inv_total-balance;


===========  CREATE INDEX FOR ID FOR STG AND CLN table

ALTER TABLE ifs_invoice_stg_150510 ADD INDEX n (contact_id);

==================

============  CREATE CUSTOMER VALUE TABLE 

ALTER TABLE ifs_whole_contact_cln_150507 ADD INDEX n1 (date_created);

--------- Create table of unclean spending for stg_2 

drop table cdb_customer_spend_profile_stg_2_150510;
CREATE TABLE cdb_customer_spend_profile_stg_2_150510 AS(
 SELECT a.*
  , b.date_created
 , -(datediff(b.date_created, a.date)) AS lifecycle_day 
 FROM ifs_invoice_stg_150510 a
  LEFT JOIN ifs_whole_contact_cln_150507 b 
  on (a.contact_id = b.contact_id));

delete from cdb_customer_spend_profile_stg_2_150510 where date_created < "2013-07-15";


CREATE INDEX ifs_invoice_2_150510__contact_id on cdb_customer_spend_profile_stg_2_150510(contact_id);

ALTER table cdb_customer_spend_profile_stg_2_150510 add
purchase_week_num int(30);

update cdb_customer_spend_profile_stg_2_150510 
  set
purchase_week_num = ceiling(lifecycle_day/7);

update cdb_customer_spend_profile_stg_2_150510 
  set
purchase_week_num = 1
where purchase_week_num = 0;

ALTER table cdb_customer_spend_profile_stg_2_150510 add
life_total_week_num int(30);

update cdb_customer_spend_profile_stg_2_150510 
  set
life_total_week_num = ceiling(DATEDIFF("2015-05-01",date_created)/7);


update cdb_customer_spend_profile_stg_2_150510 
  set
life_total_week_num = 1
where life_total_week_num = 0;


=======================
TABLE for CID and LS for the lead source
=======================


create or replace view cdb_value_of_customer_by_week as
  select contact_id, lead_source, purchase_week_num,inv_total 
from 
cdb_customer_spend_profile_stg_2_150510;

select count(distinct lead_source) from cdb_value_of_customer_by_week;

=======================
Table for LEAD source by week
=======================

create TABLE cdb_leadsource_value_by_week_stg as 
select lead_source,purchase_week_num,inv_total
from cdb_customer_spend_profile_stg_2_150510;


create or replace view cdb_leadsource_value_by_week_150511 as 
  select lead_source, sum(inv_total),purchase_week_num
  from cdb_leadsource_value_by_week_stg
  group by lead_source, purchase_week_num;


===================






exit ==== quit the database
use database name
DESCRIBE ifs_opt_customer_info; ==== see the detial of table


CREATE TABLE (TABLE_NAME)
(COLUMN_NAME1 DATA_TYPE()); ======= create new table in mysql


ALTER TABLE ifs_opt_customer_info
ADD Age int(5);                 ======= add new columns

ALTER TABLE ifs_opt_customer_info MODIFY Year_birth Varchar(100); === modify columns

TRUNCATE ifs_opt_customer_info; ==== Clean the table

UPDATE ifs_opt_customer_info
SET Year_birth = NULL 
WHERE Year_birth = 0000;                ===== updata the table with condition.

SELECT DATEDIFF(CURRENT_DATE, STR_TO_DATE(t.birthday, '%d-%m-%Y'))/365 AS ageInYears
  FROM YOUR_TABLE t 

update ifs_opt_customer_info set Birthday = right(Birthday,4); ============ combine to cols

ALTER TABLE ifs_opt_customer_info
  DROP Final_Birth_year;


ALTER TABLE ifs_opt_customer_info MODIFY Birthday int(10);


UPDATE ifs_opt_customer_info SET Birthday = str_to_date( Birthday, '%m/%d/%Y') === convert to the normal date.

select IFNULL(Birthday,Year_birth) FROM ifs_opt_customer_info_Unclean;   ====  if birthday is null then use Year_birth


SELECT IF(Birthday IS NULL or Birthday = '', Year_birth, Birthday ) from ifs_opt_customer_info_Unclean;


select Id,Link = STUFF ((select ','+ltrim(Link) from ifs_customer_activities_Unclean_test where Id=t.Id for XML path('')),1,1,'') from ifs_customer_activities_Unclean_test t
group by Id;


ALTER TABLE leads_1
ADD loaction_id text; 

ALTER TABLE leads_1
  DROP zip;


  ALTER TABLE leads_1 MODIFY loaction_id int(20);

  ALTER TABLE ifs_opt_customer_info
ADD row_n int(5)   



UPDATE ifs_total_spend_CLN_4_28,ifs_opt_customer_info_CLN_4_28
SET
ifs_total_spend_CLN_4_28.lead_source = ifs_opt_customer_info_CLN_4_28.lead_source
where ifs_opt_customer_info_CLN_4_28.contact_id = ifs_total_spend_CLN_4_28.contact_id;  =========== add new col from anther table 


========================================






------------------------------
-- ifs_invoice_2_150428
------------------------------

DROP TABLE ifs_invoice_2_150428;
CREATE TABLE ifs_invoice_2_150428 AS(

 SELECT a.*
 , b.date_created
 , -(datediff(b.date_created, a.date)) AS lifecycle_day 
 , -(to_days(b.date_created) - to_days(a.date)) AS lifecycle_day_2
 
 FROM ifs_invoice_cln_150428 a
  LEFT JOIN ifs_contact_CLN_150428 b on (a.contact_id = b.contact_id)
);

CREATE INDEX ifs_invoice_2_150428__contact_id on ifs_invoice_2_150428(contact_id);

------------------------------
-- cdb_cust_spend_profile_150428
------------------------------
CREATE TABLE cdb_cust_spend_profile_150428 as(

 SELECT a.contact_id
  , a.first_name
  , a.last_name
  , a.date_created
  , a.life_time
  , a.lead_source
 
  , sum((case when (0 <= b.lifecycle_day AND b.lifecycle_day <= 1) then a.inv_total else 0 end)) AS c1dv
  , sum((case when (0 <= b.lifecycle_day AND b.lifecycle_day <= 90) then a.inv_total else 0 end)) AS c90dv
  , (case when isnull(sum(b.inv_total)) then 0 else sum(b.inv_total) end) AS cltv
 
 FROM ifs_contact_CLN_150428 a
  LEFT JOIN ifs_invoice_2_150428 b
  ON (a.contact_id = b.contact_id)
 
 GROUP BY contact_id

 =============================



 Login information:






==============================================================================================================================================================
LINUX:
cd=== change direction 
ls== list of file

GO TO THE MYSQL DATABASE:
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' dbl
============================


======================  create table of opty 

drop table ifs_opty_list_w15_32;
create table ifs_opty_list_w15_32 (
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

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE ifs_opty_list_w15_32 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl

===============================


update ifs_opty_list_w15_32
set next_action_date= LEFT(next_action_date,LOCATE(' ',next_action_date) - 1)
,date_create = LEFT(date_create,LOCATE(' ',date_create) - 1)
, last_update = LEFT(last_update,LOCATE(' ',last_update) - 1);

UPDATE ifs_opty_list_w15_32
SET next_action_date = STR_TO_DATE(next_action_date, '%m/%d/%Y'),
date_create = STR_TO_DATE(date_create, '%m/%d/%Y'),
last_update = STR_TO_DATE(last_update, '%m/%d/%Y');


ALTER TABLE ifs_opty_list_w15_32 ADD INDEX n_1 (opp_id);


UPDATE ifs_opty_list_w15_32
set owner = "Rob"
where owner = "Love Systems Advisor";


================================

IFS_OPTY_WEEKLY_CHECK_REPORT

================================

create or replace view weekly_opty_action_report as 
select
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
"New opty from last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32
where date_create between "2015-07-13" and "2015-07-19" 

union all 

select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
note as Action,
"Opty addressed at last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ",order_revenue) as Result
From ifs_opty_list_w15_32 
where next_action_date between "2015-07-13" and "2015-07-19"
and (stage = "Lost" or stage = "Won")

union all 
select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",a.opp_id)
as Opty_Link,
a.Owner,
a.contact_name as Contact_Name,
a.phone_number as Phone_Number,
concat(b.opp,"--->", a.opp) as Opty_Description,
concat(b.next_action_date,"--->",a.next_action_date) as Next_action_date,
concat(a.next_action," | ",a.note) as Action,
"Opty addressed at last week" as Type,
concat(b.stage,"--->",a.stage) as Working_Stage,
concat(b.loss_reson, "--->",a.loss_reson," | ",b.order_revenue,"--->", a.order_revenue) as Result
From ifs_opty_list_w15_32 a
left join ifs_opty_list_w15_26 b
on b.opp_id = a.opp_id 
where a.next_action_date <> b.next_action_date
and (a.stage = "Working"
and a.next_action_date > "2015-07-19")


union all 
select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
"Opty did not address at last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32
where next_action_date between "2015-07-13" and "2015-07-19"
and last_update not between "2015-07-13" and "2015-07-19"

union all 
select
concat("W15.", WEEK(curdate())+1) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
 "Opty will address this week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32 a
where next_action_date between "2015-07-13" and "2015-07-19" ;


===================================
test
====================================
create or replace view weekly_opty_action_report as
select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",a.opp_id)
as Opty_Link,
a.Owner,
a.contact_name as Contact_Name,
a.phone_number as Phone_Number,
concat(b.opp,"--->", a.opp) as Opty_Description,
concat(b.next_action_date,"--->",b.next_action_date) as Next_action_date,
concat(a.next_action," | ",a.note) as Action,
"Opty addressed at last week_1" as Type,
concat(b.stage,"--->",a.stage) as Working_Stage,
concat(b.loss_reson, "--->",a.loss_reson," | ",b.order_revenue,"--->", a.order_revenue) as Result,
a.next_action_date as a_next_action_date, 
b.next_action_date as b_next_action_date, 
a.next_action_date <> b.next_action_date, 
datediff(a.next_action_date, b.next_action_date)
From ifs_opty_list_w15_32 a
left join ifs_opty_list_w15_32_W15_20 b
on b.opp_id = a.opp_id 
where
a.next_action_date <> b.next_action_date;


===================================


Login information:






===============================================

GO TO THE MYSQL DATABASE:
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' dbl


=============================  all sale report ----  invoice report from ifs.

CREATE TABLE ifs_invoice_stg_1504506 (
order_id int(20),
contact_id int(20),
description text,
First_name varchar(20),
Last_name varchar(20),
product_id text,
inv_total varchar(20),
balance varchar(20),
date varchar(50),
lead_source text);


====
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE ifs_invoice_stg_1504506 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl

== 

=============== CREATE A CLN TABLE FOR INVOIVE_STG

CREATE TABLE ifs_invoice_cln_150506
AS SELECT *
FROM ifs_invoice_stg_1504506;

ALTER TABLE ifs_invoice_cln_150506 DROP lead_source;

UPDATE ifs_invoice_cln_150506
SET inv_total = CAST(REPLACE(REPLACE(IFNULL(inv_total,0),',',''),'$','') AS DECIMAL(10,2));

UPDATE ifs_invoice_cln_150506
SET balance = CAST(REPLACE(REPLACE(IFNULL(balance,0),',',''),'$','') AS DECIMAL(10,2));

UPDATE ifs_invoice_cln_150506
SET date = STR_TO_DATE(date, '%m/%d/%Y');



ALTER TABLE ifs_invoice_cln_150506 MODIFY inv_total DECIMAL(10,2);

ALTER TABLE ifs_invoice_cln_150506 MODIFY balance DECIMAL(10,2);


ALTER TABLE ifs_invoice_cln_150506
ADD inv_paid DECIMAL(10,2) AFTER balance;

UPDATE ifs_invoice_cln_150506
SET inv_paid = inv_total-balance;

ALTER TABLE ifs_invoice_cln_150506 ADD INDEX n (order_id);

ALTER TABLE ifs_invoice_cln_150506 ADD INDEX n1 (contact_id);

ALTER TABLE ifs_invoice_cln_150506 ADD INDEX n2 (product_id);

ALTER TABLE ifs_item_product_id_table ADD INDEX n2 (product_id);

====================================


create table ifs_item_sale_stg_2_150506 AS
SELECT  contact_id,sa.order_id as invoice_id,
a.product_id,sa.inv_total, a.product_price
FROM ifs_item_product_id_table AS a
JOIN ifs_invoice_cln_150506 AS sa
ON FIND_IN_SET(a.product_id, sa.product_id);

ALTER TABLE ifs_item_sale_stg_2_150506 ADD INDEX n2 (invoice_id);

UPDATE ifs_item_sale_stg_2_150506
SET product_price = CAST(REPLACE(REPLACE(IFNULL(product_price,0),',',''),'$','') AS DECIMAL(10,2));


CREATE TABLE ifs_item_sale_stg_3_150506 as
select sum(ifs_item_sale_stg_2_150506.product_price) as sale_total,
ifs_item_sale_stg_2_150506.invoice_id as invoice
From ifs_item_sale_stg_2_150506 
group by ifs_item_sale_stg_2_150506.invoice_id;

ALTER TABLE ifs_item_sale_stg_3_150506 ADD INDEX n2 (invoice);


Create table ifs_item_sale_cln_150506 as
(select a.invoice_id, a.product_id,
	a.inv_total*(a.product_price/b.sale_total) as est_price
from ifs_item_sale_stg_2_150506 a 
left join ifs_item_sale_stg_3_150506 b
on a.invoice_id =b.invoice
);

================================================




=================

Login Info -- 


		ssh ls@vm01.lovesystems.com
		Enter PWD: xLKDrL5zP6PkEi
---	
mysql --user=ls --password=xLKDrL5zP6PkEi ls_bcm
---

================

================ Build a new view for current week

create table alex_bcm_w15_19 as(
	select a.wsid, a.full_wk,a.ws_date, a.instructors,
	a.city,a.title,a.n_clients,a.total_amount,
	a.bc_desc,a.designation, DATEDIFF(a.ws_date,CURRENT_DATE) as days_away
From bc_report_2a a);


====================================== stg table for each week



create table alex_bcm_weekly_report_stg as 	

select 
a.wsid,
a.bc_desc as old_bc_desc, b.bc_desc,
"Removed" as change_type
from alex_bcm_w15_19 a
LEFT join alex_bcm_w15_19_test b
on a.wsid =b.wsid 
where b.title is null

UNION ALL

select 
b.wsid,
a.bc_desc as old_bc_desc, b.bc_desc,
"Added" as change_type
from alex_bcm_w15_19 a
RIGHT join alex_bcm_w15_19_test b
on a.wsid =b.wsid 
where a.title is null

union all 

select 
b.wsid,
a.bc_desc as old_bc_desc, b.bc_desc,
"Update" as change_type
from alex_bcm_w15_19 a
join alex_bcm_w15_19_test b
on a.wsid =b.wsid 
where a.bc_desc <> b.bc_desc;


========= view that update automatic 



create or replace view alex_bcm_weekly_report as (
select
wsid,
(Case 
when change_type = "Removed" then old_bc_desc 
when change_type = "Added" then bc_desc
else CONCAT(old_bc_desc, '-->', bc_desc)
END) as event_info,
change_type
from alex_bcm_weekly_report_stg
);

=============================


Login information:






=========================

GO TO THE MYSQL DATABASE:
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' dbl



==========================
drop table ifs_customer_activities_stg_150506;

CREATE TABLE ifs_customer_activities_stg_150506
(id int(20),
first_name varchar(20),
last_name varchar(20),
email Text,
batch_id int(20),
sent varchar(20),
opened varchar(20),
clicked varchar(20),
link text);




=============

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' 
INTO TABLE ifs_customer_activities_stg_150506 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl

"
============= stg2

ALTER TABLE ifs_customer_activities_stg_150506 ADD INDEX n1 (opened);

ALTER TABLE ifs_customer_activities_stg_150506 ADD INDEX n2 (clicked);

ALTER TABLE ifs_customer_activities_stg_150506 ADD INDEX n (id);

===============

CREATE TABLE ifs_customer_activities_stg_2_150506
AS SELECT id as contact_id,
first_name as first_name,
last_name as last_name,
email as email,
opened as opened,
clicked as clicked
FROM ifs_customer_activities_stg_150506
WHERE opened <> " ";

ALTER TABLE ifs_customer_activities_stg_2_150506 ADD INDEX n1 (opened);

ALTER TABLE ifs_customer_activities_stg_2_150506 ADD INDEX n2 (clicked);

ALTER TABLE ifs_customer_activities_stg_2_150506 ADD INDEX n (contact_id);

UPDATE ifs_customer_activities_stg_2_150506
SET opened = STR_TO_DATE(opened, '%m/%d/%Y');

UPDATE ifs_customer_activities_stg_2_150506
SET clicked = STR_TO_DATE(clicked, '%m/%d/%Y');

============= CREATE A CLEAN ACTIVITY TABLE


CREATE TABLE ifs_customer_activities_cln_W15_19_150427_150505
AS SELECT contact_id as contact_id,
first_name as first_name,
last_name as last_name,
email as email,
SUM(CONVERT(IF(opened > "2015-04-27", 1, 0), UNSIGNED INTEGER)) num_opened,
SUM(CONVERT(IF(clicked <> '' and clicked > "2015-04-27", 1, 0), UNSIGNED INTEGER)) num_clicked
FROM ifs_customer_activities_stg_2_150506
GROUP BY contact_id;

===================

WEEKLY PHONE LEADS PROJECT 

===============================================================================================

===============
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' dbl

==================

SEGMENTS

[1]Don’t have number opened
[2]International number Opened
[3]International number Opened and Clicked or bought
[4]Domestic number Opened
[5]Domestic Clicked or bought

======================

====================CREATE IFS EXPORT TABLE  --- FROM IFS- EMAIL_B
CREATE TABLE ifs_LSI_WSM_mail_blast_result_w15_30(
Contact_Id int(20),
First_Name varchar(20),
Last_Name varchar(20),
Batch_Id int(20),
Sent varchar(20), 
Opened varchar(20),
Clicked varchar(20),
Link_Clicked text);

===================
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'batch.csv'
INTO TABLE ifs_LSI_WSM_mail_blast_result_w15_30 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS" dbl

"


UPDATE ifs_LSI_WSM_mail_blast_result_w15_30
SET Sent = STR_TO_DATE(Sent, '%m/%d/%Y');

UPDATE ifs_LSI_WSM_mail_blast_result_w15_30
SET Opened = STR_TO_DATE(Opened, '%m/%d/%Y');




===================

ALTER TABLE ifs_LSI_WSM_mail_blast_result_w15_30 ADD INDEX n (Batch_Id);


====================CREATE A EMAIL STATS TABLE -- export table from IFS brocast_report
## current week to last 7 weeks

CREATE TABLE ifs_mail_brocast_W15_30(
Batch_Id int(20),
template varchar(50));

ALTER TABLE ifs_mail_brocast_W15_30 CONVERT TO CHARACTER SET utf8;

=====================

## use PHP to import the csv file

select distinct template from ifs_mail_brocast_W15_30;

============================
ALTER TABLE ifs_mail_brocast_W15_30 ADD INDEX n1 (Batch_Id);


============================== CREATE LSI+WSM+curric+One_off TABLE

CREATE TABLE phone_leads_w15_30_stg AS
(SELECT ifs_LSI_WSM_mail_blast_result_w15_30.*, 
  ifs_mail_brocast_W15_30.template
  FROM ifs_LSI_WSM_mail_blast_result_w15_30
  INNER JOIN ifs_mail_brocast_W15_30
        ON ifs_LSI_WSM_mail_blast_result_w15_30.Batch_Id = ifs_mail_brocast_W15_30.Batch_Id
);


==================================

ALTER TABLE phone_leads_w15_30_stg CHANGE template segment varchar(20);

ALTER TABLE phone_leads_w15_30_stg ADD INDEX n1 (Opened);
ALTER TABLE phone_leads_w15_30_stg ADD INDEX nn (Contact_Id);


==============================================



======================== CREATE A LSI+WSM EMAIL+PHONE+SMS LIST


CREATE TABLE phone_leads_w15_30_stg_2 AS
(SELECT phone_leads_w15_30_stg.*,
ifs_whole_contact_cln_150803.phone,
ifs_whole_contact_cln_150803.country,
ifs_whole_contact_cln_150803.email as email_address
From phone_leads_w15_30_stg
	INNER JOIN ifs_whole_contact_cln_150803
		ON ifs_whole_contact_cln_150803.contact_id=phone_leads_w15_30_stg.Contact_Id);

ALTER table phone_leads_w15_30_stg_2 
add seg_country varchar(20);


UPDATE phone_leads_w15_30_stg_2
SET seg_country = case
When country = "United States" THEN "Domestic" 
When country = "Canada" THEN "Domestic" 
When country = "USA" THEN "Domestic" 
When country = "US" THEN "Domestic" 
ELSE "International"
END;

ALTER TABLE phone_leads_w15_30_stg_2
ADD actions varchar(200); 

select distinct segment from phone_leads_w15_30_stg_2;

==================

SEGMENTS

[1]Don’t have number opened --- email -- fpc
[2]International number Opened -- email --- email fpc
[3]International number Opened and Clicked or bought -- Call
[4]Domestic number Opened ----  email and SMS
[5]Domestic Clicked or bought ---  Email, SMS, Call
======================


UPDATE phone_leads_w15_30_stg_2
SET actions = CASE
When Phone = "" THEN "seg1"
When Phone <> "" AND Clicked = "" AND seg_country = "International" THEN "seg2"
WHEN Phone <> "" AND Clicked <>"" AND seg_country = "International" THEN "seg3"
When Phone <> "" AND Clicked = "" AND seg_country = "Domestic" THEN "seg4"
WHEN Phone <> "" AND Clicked <> "" AND seg_country = "Domestic" THEN  "seg5"
ELSE "SOMETHING WORNG"
END;

select count(distinct Contact_id) from phone_leads_w15_30_stg_2 where phone <> " ";


====================== check the segmentation 
select actions, count(Contact_id) as ct from phone_leads_w15_30_stg_2 group by actions;




======================  GET the Phone and SMS leads LIST WITH DUCPLICATED 

drop table phone_leads_weekly_W15_30;
CREATE TABLE phone_leads_weekly_W15_30 AS(
SELECT a.* , b.city,d.owner as opty_owner,d.stage,
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=", d.opp_id) as opty_link
FROM phone_leads_w15_30_stg_2 a 
LEFT JOIN ifs_whole_contact_cln_150803 b
ON a.Contact_id= b.contact_id
left join ifs_opty_list_w15_32 d
On a.Contact_id = d.contact_id
where 
a.actions = "seg3" or a.actions ="seg5"
);

ALTER TABLE phone_leads_weekly_W15_30
add time_city varchar(50);


update phone_leads_weekly_W15_30
set time_city = case
when (country ="United States" or country = "Canada") and (phone <> " " and LEFT(phone,1) <> 1) then left(right(phone,10),3)
when (country ="United States" or country = "Canada") and (phone <> " " and LEFT(phone,1) = 1)  then right(left(phone,4),3)
when city = " " and country <> "United States" then country
when country = " " then city
else country
end;


ALTER TABLE phone_leads_weekly_W15_30 ADD INDEX n1 (time_city);



===================

Invoice weekly sales TABLE

===================

Create table invoice_slae_weekly_W15_30 (
contact_id int(20),
name varchar(30),
phone varchar(50),
email varchar(100),
country varchar(30),
product text,
invoice varchar(20));


mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'invoice.csv'
INTO TABLE invoice_slae_weekly_W15_30 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS" dbl

"
UPDATE invoice_slae_weekly_W15_30
SET invoice = CAST(REPLACE(REPLACE(IFNULL(invoice,0),',',''),'$','') AS DECIMAL(10,2));

alter table invoice_slae_weekly_W15_30
add seg_country varchar(20);

UPDATE invoice_slae_weekly_W15_30
SET seg_country = case
When country = "United States" THEN "Domestic" 
When country = "Canada" THEN "Domestic" 
When country = "USA" THEN "Domestic" 
When country = "US" THEN "Domestic" 
ELSE "International"
END;

ALTER TABLE invoice_slae_weekly_W15_30
add time_city varchar(50);

update invoice_slae_weekly_W15_30
set time_city = case
when ((seg_country = "Domestic" or country=" ") and phone <> " ") then right(left(phone, locate(')', phone)-1),3)
else country
end;

ALTER TABLE invoice_slae_weekly_W15_30 ADD INDEX n1 (time_city);


===================
CREAT TABLE OF SEG 3 OR SEG 5 FROM Invoice
===================


create or replace view phone_leads_inovoice_list_w15_30 as 
	select 
a.*, c.time_zone, d.owner as opty_owner,d.stage,
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=", d.opp_id) as opty_link
FROM invoice_slae_weekly_W15_30 a 
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

select count(*) from phone_leads_inovoice_list_w15_30;

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

drop table phone_leads_final_report_w15_30_stg;
create table phone_leads_final_report_w15_30_stg as
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
	from phone_leads_weekly_W15_30
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
	from phone_leads_inovoice_list_w15_30

	union all 
	select 
	contact_id,
	name,
	what_done,
	segment,
	actions,
	phone,
	country,
	seg_country,
	owner,
	opty_link,
	stage,time_city,
	Null as Sent,
	Null as Opened,
	Null as Clicked

	from DOB_weekly_check_list
	;


ALTER table phone_leads_final_report_w15_30_stg add rank int(20);

update phone_leads_final_report_w15_30_stg 
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




create or replace view phone_leads_final_report_w15_30_stg_new as 
	select a.*
	from 
	phone_leads_final_report_w15_30_stg a
	left join phone_leads_final_report_w15_30_stg b
	on 
	a.contact_id = b.contact_id
	and b.rank>a.rank 
	left join  phone_leads_final_report_w15_30_stg c
	on c.contact_id = a.contact_id 
	and c.rank = a.rank
	where a.Sent >= "2015-07-13" or a.segment = "purchase" or a.segment = "DOB";

create or replace view phone_leads_final_report_w15_30_stg_old as 
	select a.*
	from 
	phone_leads_final_report_w15_30_stg a
	left join phone_leads_final_report_w15_30_stg b
	on 
	a.contact_id = b.contact_id
	and b.rank>a.rank 
	left join  phone_leads_final_report_w15_30_stg c
	on c.contact_id = a.contact_id 
	and c.rank = a.rank
	where a.Sent < "2015-07-13";

create table phone_leads_final_report_w15_30_stg_2 as 
SELECT a.*, "New" as type
FROM   phone_leads_final_report_w15_30_stg_new a
JOIN   (
           SELECT   contact_id, MAX(rank) max_rank
           FROM     phone_leads_final_report_w15_30_stg_new
           GROUP BY contact_id
       ) sub_p ON (sub_p.contact_id = a.contact_id AND 
                   sub_p.max_rank = a.rank)
GROUP BY a.contact_id

union all 

SELECT a.*, "Old" as type
FROM   phone_leads_final_report_w15_30_stg_old a
JOIN   (
           SELECT   contact_id, MAX(rank) max_rank
           FROM     phone_leads_final_report_w15_30_stg_old
           GROUP BY contact_id
       ) sub_p ON (sub_p.contact_id = a.contact_id AND 
                   sub_p.max_rank = a.rank)
GROUP BY a.contact_id;


select count(contact_id) from phone_leads_final_report_w15_30_stg_2;

select count(distinct contact_id) from phone_leads_final_report_w15_32_cln_1;


create table phone_leads_final_report_w15_32_cln_1_1 as 
	select a.*,
	b.CC, b.time_zone
	from 
	phone_leads_final_report_w15_30_stg_2 a
	left join 
	time_zone_lookup b
	on a.time_city = b.city;



update phone_leads_final_report_w15_32_cln_1_1
	set time_zone = "PST + 3 or PST"
	WHERE seg_country = "Domestic" and time_zone is null;


select count(contact_id) from phone_leads_final_report_w15_32_cln_1_1;

select distinct stage from phone_leads_final_report_w15_32_cln_1_1;

create table phone_leads_w15_30_no_call (
id int(20),
reason varchar(20)
);


ALTER TABLE phone_leads_w15_30_no_call ADD INDEX n1 (id);

drop table phone_leads_final_report_w15_32_cln_1;
create table phone_leads_final_report_w15_32_cln_1 as 
	select 
	a.*,
	b.reason
	from phone_leads_final_report_w15_32_cln_1_1 a 
	left join phone_leads_w15_30_no_call b
	on a.contact_id = b.id;

delete from phone_leads_final_report_w15_32_cln_1 where reason is not null;

ALTER TABLE phone_leads_final_report_w15_32_cln_1 ADD INDEX n1 (contact_id);


drop table phone_leads_final_report_w15_30_auto;
create table phone_leads_final_report_w15_30_auto as 
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
	from phone_leads_final_report_w15_32_cln_1
	where 
	((stage = "Won" or stage = "Lost") and seg_country = "Domestic")
	or 
	(stage is null and seg_country = "Domestic");

DROP table phone_leads_final_report_w15_30_manual;
create table phone_leads_final_report_w15_30_manual as 
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
	from phone_leads_final_report_w15_32_cln_1
	where 
	 seg_country = "International" 
	 and 
	 (stage is null or stage = "Won" or stage = "Lost");

DROP table phone_leads_final_report_w15_30_awakend;
create table phone_leads_final_report_w15_30_awakend as 
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
	from phone_leads_final_report_w15_32_cln_1
	where 
	stage  = "Working" or stage = "New";


select count(contact_id) from phone_leads_final_report_w15_32_cln_1;
select count(contact_id) from phone_leads_final_report_w15_30_awakend;
select count(contact_id) from phone_leads_final_report_w15_30_manual;
select count(contact_id) from phone_leads_final_report_w15_30_auto;


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

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'opty.csv' INTO TABLE ifs_opty_list_w15_32_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl

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

IFS_OPTY_WEEKLY_CHECK_REPORT

================================

create or replace view weekly_opty_action_report_w15_30 as 
select
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_id,
phone_number,
city,
state,
country,
opp,
contact_name as Contact_Name,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
"New opty from last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32
where date_create between "2015-07-13" and "2015-07-19" 

union all 

select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_id,
phone_number,
city,
state,
country,
opp,
contact_name as Contact_Name,
opp as Opty_Description,
next_action_date as Next_action_date,
note as Action,
"Opty addressed at last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ",order_revenue) as Result
From ifs_opty_list_w15_32 
where next_action_date between "2015-07-13" and "2015-07-19"
and (stage = "Lost" or stage = "Won")

union all 
select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",a.opp_id)
as Opty_Link,
a.Owner,
a.contact_id,
a.phone_number,
a.city,
a.state,
a.country,
a.opp,
a.contact_name as Contact_Name,
concat(b.opp,"--->", a.opp) as Opty_Description,
concat(b.next_action_date,"--->",a.next_action_date) as Next_action_date,
concat(a.next_action," | ",a.note) as Action,
"Opty addressed at last week" as Type,
concat(b.stage,"--->",a.stage) as Working_Stage,
concat(b.loss_reson, "--->",a.loss_reson," | ",b.order_revenue,"--->", a.order_revenue) as Result
From ifs_opty_list_w15_32 a
left join ifs_opty_list_w15_26 b
on b.opp_id = a.opp_id 
where a.next_action_date <> b.next_action_date
and (a.stage = "Working"
and a.next_action_date > "2015-07-19")


union all 
select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_id,
phone_number,
city,
state,
country,
opp,
contact_name as Contact_Name,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
"Opty did not address at last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32
where next_action_date between "2015-07-13" and "2015-07-19"
and last_update not between "2015-07-13" and "2015-07-19"

union all 
select
concat("W15.", WEEK(curdate())+1) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_id,
phone_number,
city,
state,
country,
opp,
contact_name as Contact_Name,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
 "Opty will address this week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32 a
where next_action_date between "2015-07-20" and "2015-07-26";



### create live opty call list 
drop table phone_leads_final_report_w15_30_live_opty_stg;
create table phone_leads_final_report_w15_30_live_opty_stg as 
	select
	contact_id,
	Contact_Name,
	CONCAT("https://lovesystems.infusionsoft.com/Contact/manageContact.jsp?view=edit&ID=",contact_id) as link,
	Phone_Number,
	country,
	Action as what_done,
	opp,
	Owner,
	Opty_Link,Working_Stage,
	Action,type
	from weekly_opty_action_report_w15_30
	where 
	(type  = "Opty will address this week" or type  = "Opty did not address at last week")
	and 
	Phone_Number <> " ";

select phone_number from weekly_opty_action_report_w15_30 where type ="Opty did not address at last week";

UPDATE phone_leads_final_report_w15_30_live_opty_stg
SET Phone_Number = " "
where right(left(Phone_Number,2),1) not REGEXP '^[0-9]+$';

ALTER TABLE phone_leads_final_report_w15_30_live_opty_stg
add time_city varchar(50);

update phone_leads_final_report_w15_30_live_opty_stg
set time_city = case
when country ="United States" or country = "Canada" or country = "US" then right(left(Phone_Number,4),3)
when country ="United States" or country = "Canada" or country = "US" then right(left(Phone_Number,4),3)
when country is null and not(right(left(Phone_Number,2),1) not REGEXP '^[0-9]+$') then right(left(Phone_Number,4),3)
else country
end;

delete from  phone_leads_final_report_w15_30_live_opty_stg where Phone_Number = " ";

==================
Segment based customer report
==================




select count(distinct contact_id),actions from weekly_phone_leads_segnment_report 
group by actions;

select count(distinct contact_id),actions from lsi_wsm_phone_leads_report_w15_23 
group by actions;

select count(distinct contact_id),actions from phone_leads_w15_30_stg_2 
group by actions;

create or replace view weekly_responders_analysis_report as 
select "W15.28" as week, count(distinct contact_id),segment,actions from phone_leads_w15_30_stg_2 
group by segment,actions
union all 
select "W15.27" as week,count(distinct contact_id),segment,actions from phone_leads_w15_30_stg_2 
group by segment,actions;

select count(distinct contact_id),actions from phone_leads_final_report_w15_32_cln_1 
group by actions;

select count(distinct contact_id),country from DOB_weekly_check_list 
group by country;

==================
Table for the text message
==================

create table weekly_text_message_list_li_W15_32_stg as 
	select 
	a.contact_id,a.segment,a.phone,b.next_action_date
	from phone_leads_final_report_w15_32_cln_1 a
	left join ifs_opty_list_w15_32 b
	on a.contact_id = b.contact_id
	where actions = "seg5"
	
	union ALL
	select
	a.Contact_id,a.segment,a.phone,b.next_action_date
	from 
	phone_leads_w15_30_stg_2 a
	left join ifs_opty_list_w15_32 b
	on a.Contact_id = b.contact_id
	where 
	actions = "seg4";



delete from weekly_text_message_list_li_W15_32_stg where next_action_date >= "2015-08-02";

ALTER table weekly_text_message_list_li_W15_32_stg add rank int(20);

update weekly_text_message_list_li_W15_32_stg 
set 
rank =case
when segment = "purchase" then 6
when segment = "fpc" then 5
when segment = "wsm" then 4
when segment = "one-off" then 3
when segment = "lsi" then 2
when segment = "curric" then 1
end;

alter table weekly_text_message_list_li_W15_32_stg add index rw (rank);

alter table weekly_text_message_list_li_W15_32_stg add index rw_1 (contact_id);

select * from weekly_text_message_list_li_W15_32_stg where segment = "purchase";

create table weekly_text_message_list_li_W15_32_stg_2 as 
	select a.contact_id, a.segment,a.phone,a.rank
	from 
	weekly_text_message_list_li_W15_32_stg a
	left join weekly_text_message_list_li_W15_32_stg b
	on 
	a.contact_id = b.contact_id
	and b.rank>a.rank 
	left join  weekly_text_message_list_li_W15_32_stg c
	on c.contact_id = a.contact_id 
	and c.rank = a.rank;

alter table weekly_text_message_list_li_W15_32_stg_2 add index rw (rank);

alter table weekly_text_message_list_li_W15_32_stg_2 add index rw_1 (contact_id);

create table weekly_text_message_list_li_W15_32_cln as 
SELECT a.contact_id, a.segment,a.phone,a.rank,c.first_name
FROM   weekly_text_message_list_li_W15_32_stg_2 a
JOIN   (
           SELECT   contact_id, MAX(rank) max_rank
           FROM     weekly_text_message_list_li_W15_32_stg_2
           GROUP BY contact_id
       ) sub_p ON (sub_p.contact_id = a.contact_id AND 
                   sub_p.max_rank = a.rank)
left join ifs_whole_contact_cln_150803 c 
on 
a.contact_id = c.contact_id
GROUP BY a.contact_id;


====================================
table for the FPC blast list 
====================================

drop table fpc_blast_list_w15_30_stg;

create table fpc_blast_list_w15_30_stg as 
	select Contact_id,segment,actions
	from phone_leads_w15_30_stg_2
	where actions ="seg1"
	or actions ="seg2"
	or actions ="seg4"

	union all 
	select 
	contact_id,segment,actions
	from 
	phone_leads_final_report_w15_32_cln_1
	where 
	actions = "seg5"
	or actions = "seg3";


ALTER table fpc_blast_list_w15_30_stg add rank int(20);

update fpc_blast_list_w15_30_stg 
set 
rank =case
when actions = "seg5" then 5
when actions = "seg4" then 4
when actions = "seg3" then 3
when actions = "seg2" then 2
when actions = "seg1" then 1
end;


select distinct actions from phone_leads_w15_30_stg_2;
alter table fpc_blast_list_w15_30_stg add index rw (rank);

alter table fpc_blast_list_w15_30_stg add index rw_1 (contact_id);

create table fpc_blast_list_w15_30_stg_2 as 
	select a.*
	from 
	fpc_blast_list_w15_30_stg a
	left join fpc_blast_list_w15_30_stg b
	on 
	a.contact_id = b.contact_id
	and b.rank>a.rank 
	left join  fpc_blast_list_w15_30_stg c
	on c.contact_id = a.contact_id 
	and c.rank = a.rank;

alter table fpc_blast_list_w15_30_stg_2 add index rw (rank);

alter table fpc_blast_list_w15_30_stg_2 add index rw_1 (contact_id);

create table fpc_blast_list_w15_30_cln as 
SELECT a.*
FROM   fpc_blast_list_w15_30_stg_2 a
JOIN   (
           SELECT   contact_id, MAX(rank) max_rank
           FROM     fpc_blast_list_w15_30_stg_2
           GROUP BY contact_id
       ) sub_p ON (sub_p.contact_id = a.contact_id AND 
                   sub_p.max_rank = a.rank)
GROUP BY a.contact_id;

alter table fpc_blast_list_w15_30_cln add num int(10);

update fpc_blast_list_w15_30_cln 
	set num = FLOOR(10000 + RAND() * 89999);



select count(contact_id),actions from fpc_blast_list_w15_30_cln group by actions;

create or replace view weekly_responders_analysis_report as 
select "W15.28" as week, count(distinct contact_id),segment,actions from fpc_blast_list_w15_30_cln 
group by segment,actions
union all 
select "W15.27" as week,count(distinct contact_id),segment,actions from fpc_blast_list_w15_27_cln 
group by segment,actions;

select count(distinct contact_id),actions from phone_leads_final_report_w15_32_cln_1 
group by actions;


=====================================================

new lead source by week

=====================================================

drop table new_lead_source_20150526_stg;
create table new_lead_source_20150526_stg as 
	select a.contact_id,a.order_id,a.description,a.product_id,b.date_created,
	a.inv_total,a.balance,a.date,
	b.lead_source,b.life_time
	from ifs_invoice_cln_150522 a
	left join ifs_whole_contact_cln_after_2013_07_15 b
	on a.contact_id = b.contact_id;


ALTER table new_lead_source_20150526_stg add
lifecycle_day int(30);

update new_lead_source_20150526_stg 
  set
lifecycle_day = datediff(date,date_created);




ALTER table new_lead_source_20150526_stg add
purchase_week_num int(30);

update new_lead_source_20150526_stg 
  set
purchase_week_num = ceiling(lifecycle_day/7);


delete from new_lead_source_20150526_stg where life_time is null 
	or lifecycle_day is null or purchase_week_num is null;


create table new_lead_source_20150526_stg2 as 
	select
	lead_source,purchase_week_num,sum(inv_total) as sum_total, count(contact_id) as count_orders,count(order_id)
	from 
	new_lead_source_20150526_stg
	group by 
	lead_source, purchase_week_num; 

alter table new_lead_source_20150526_stg2 add INDEX 2(purchase_week_num);

alter table new_lead_source_20150526_stg2 add INDEX 1(lead_source);

alter table new_lead_source_20150526_stg2 add INDEX rw(lead_source,purchase_week_num);


select max(purchase_week_num) from new_lead_source_20150526_stg2;

create table new_lead_source_20150526_stg3 as 
	select 
	distinct(lead_source)
	from new_lead_source_20150526_stg2;

create table new_lead_source_20150526_stg4 ( 
	purchase_week_num int(10));


create table new_lead_source_20150526_stg5 as 
SELECT 
a.lead_source,
b.purchase_week_num 
FROM new_lead_source_20150526_stg3  a
CROSS JOIN new_lead_source_20150526_stg4 b;


create table new_lead_source_20150526_stg6 as 
	select
	a.*,
	b.sum_total as invoice
	from new_lead_source_20150526_stg5 a
	left join new_lead_source_20150526_stg2 b
	on a.lead_source = b.lead_source and a.purchase_week_num = b.purchase_week_num;

	update new_lead_source_20150526_stg6 
	set 
	invoice = 0 
	where invoice is null;

alter table new_lead_source_20150526_stg6 add INDEX rw(lead_source,purchase_week_num);


create table new_lead_source_20150526_final as 
	select 
	a.*,
	sum(b.invoice) as cum_inv,
	c.count_orders,
	from new_lead_source_20150526_stg6 a 
	LEFT join new_lead_source_20150526_stg6 b
	on a.lead_source = b.lead_source
	and b.purchase_week_num <= a.purchase_week_num 
	left join new_lead_source_20150526_stg2 c
	on a.purchase_week_num = c.purchase_week_num 
	and a.lead_source =c.lead_source
	group by a.lead_source, a.purchase_week_num;

	update new_lead_source_20150526_final 
	set 
	count_orders = 0 
	where count_orders is null;


	create table new_lead_source_20150526_final_1 as 
	select 
	a.*,
	sum(d.count) as all_id_count
	from new_lead_source_20150526_final a
	left join ifs_whole_contact_cln_after_2013_07_15_piv d
	on d.lead_source = a.lead_source
	and a.purchase_week_num <= d.life_week 
	group by a.lead_source, a.purchase_week_num;


	update new_lead_source_20150526_final_1
	set 
	all_id_count = 0 
	where all_id_count is null;

select * from ifs_whole_contact_cln_after_2013_07_15_piv limit 10;

drop table new_lead_source_20150526_final_1;


===========piv table======== of lead sources
create table new_lead_source_all_id_number_table as 
	select 
	* 
	from 
	ifs_whole_contact_cln_after_2013_07_15;

select count(contact_id) from ifs_whole_contact_cln_after_2013_07_15;

ALTER table new_lead_source_all_id_number_table add
purchase_week_num int(30);

update new_lead_source_all_id_number_table 
  set purchase_week_num = case 
  when life_time = 1 then 0
  else 
  ceiling(life_time/7)
  end;

select * from ifs_whole_contact_cln_after_2013_07_15_piv limit 10;
create table ifs_whole_contact_cln_after_2013_07_15_piv as
	select lead_source,
	purchase_week_num as life_week,
	count(contact_id) as count	
	from  new_lead_source_all_id_number_table
	group by lead_source, purchase_week_num;

drop table ifs_whole_contact_cln_after_2013_07_15_piv;
alter table ifs_whole_contact_cln_after_2013_07_15_piv add INDEX rw(lead_source);
alter table ifs_whole_contact_cln_after_2013_07_15_piv add INDEX 1(life_week);
alter table ifs_whole_contact_cln_after_2013_07_15_piv add INDEX 2(lead_source,life_week);


============================
check the blank lead_source
============================


create or replace view drop_down_list as 
	select 
	contact_id,
	life_time,date_created,lead_source,
	 ceiling(life_time/7) as life_time_week 
	from ifs_whole_contact_cln_after_2013_07_15;

create table drop_down_list_3_17 as 
	select * 
	from drop_down_list
	where lead_source = " ";


create view drop_down_list_final as 
select * from drop_down_list_3_17 where date_created = "2015-03-17" 
or date_created = "2015-01-23";

select date_created, count(contact_id), life_time_week from drop_down_list_3_17 group by life_time_week;

================

=======================================================
CREATE THE Calender TABLE 
=======================================================


CREATE TABLE calendar_table (
	dt date NOT NULL PRIMARY KEY);

CREATE TABLE ints ( i tinyint );
 
INSERT INTO ints VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);
 

SELECT datediff('2040-12-31','2001-01-01');

INSERT INTO calendar_table (dt)
SELECT DATE('2001-01-01') + INTERVAL a.i*10000 + b.i*1000 + c.i*100 + d.i*10 + e.i DAY
FROM ints a JOIN ints b JOIN ints c JOIN ints d JOIN ints e
WHERE (a.i*10000 + b.i*1000 + c.i*100 + d.i*10 + e.i) <= 14609
ORDER BY 1;

create table date as 
	select DATE_FORMAT(dt , '%m/%d/%Y')  AS datecol from calendar_table;

UPDATE date
SET datecol = STR_TO_DATE(datecol, '%m/%d/%Y');
=================== 

=========================================
create the Whole contact list
=========================================

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




mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'optin.csv' INTO TABLE ifs_optin_id_150713 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl

====
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE ifs_whole_contact_stg_150803 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl



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
email as email,
FROM ifs_whole_contact_stg_150803;

==
UPDATE ifs_whole_contact_cln_150803
SET age = NULL 
WHERE age = 2015; 

UPDATE ifs_whole_contact_cln_150803
SET date_created = STR_TO_DATE(date_created, '%m/%d/%Y');

UPDATE ifs_whole_contact_cln_150803
SET DOB = STR_TO_DATE(DOB, '%m/%d/%Y');

ALTER TABLE ifs_whole_contact_cln_150803
ADD life_time int(20) AFTER date_created;


UPDATE ifs_whole_contact_cln_150803
SET life_time = DATEDIFF(CURRENT_DATE, date_create);

update ifs_whole_contact_cln_150803
SET life_time = -1
WHERE date_created <= "2013-07-08" or date_created is null;

UPDATE ifs_whole_contact_cln_150803
SET phone = " "
where left(phone,1) not REGEXP '^[0-9]+$';



ALTER TABLE ifs_whole_contact_cln_150803 ADD INDEX n (contact_id);

ALTER TABLE ifs_whole_contact_cln_150803 ADD INDEX n_1 (date_created);

ALTER TABLE ifs_whole_contact_cln_150803 ADD INDEX n_3 (DOB);


ALTER TABLE ifs_whole_contact_cln_150803 ADD INDEX n_2 (date_created,contact_id);



====================================================================
Opty check
====================================================================
ALTER TABLE ifs_whole_contact_cln_150803
ADD in_opty_list varchar(5); 

UPDATE ifs_whole_contact_cln_150803
Inner Join ifs_contact_CLN_150428
On ifs_whole_contact_cln_150803.contact_id = ifs_contact_CLN_150428.contact_id
SET ifs_whole_contact_cln_150803.in_opty_list = "Yes";

UPDATE ifs_whole_contact_cln_150803
SET in_opty_list = "No"
WHERE in_opty_list is null;


ALTER TABLE ifs_whole_contact_cln_150803
add time_city varchar(50);

update ifs_whole_contact_cln_150803
set time_city = case
when country ="United States" and (phone <> " " and LEFT(phone,1) <> 1) then left(right(phone,10),3)
when country ="United States" and (phone <> " " and LEFT(phone,1) = 1)  then right(left(phone,4),3)
when city = " " and country <> "United States" then country
when country = " " then city
else country
end;


ALTER TABLE ifs_whole_contact_cln_150803 ADD INDEX n_3 (time_city);

create or replace view customer_time_zone as 
  select 
  a.contact_id,a.first_name, a.country,a.city,a.time_city,
  b.time_zone
  from ifs_whole_contact_cln_150803 a
  left join time_zone_lookup b
  on a.time_city = b.city;

 ==========================================

 ==============================
 WEEKLY PHONE LEADS CALL Result
 ==============================
create table sale_team_call_auto_result_w15_25_stg(
name varchar(20),
Phone varchar(20),
note text,
contact_id int(20),
caller varchar(20));


alter table sale_team_call_auto_result_w15_25_stg add date_2 varchar(100);



create table dbl_aaaaa AS
SELECT  contact_id,sa.order_id as invoice_id,
a.product_id,sa.inv_total, a.product_price
FROM ifs_item_product_id_table AS a
JOIN ifs_invoice_cln_150506 AS sa
ON FIND_IN_SET(a.product_id, sa.product_id);


create table sale_team_call_result_w15_28_stg(
opty_id varchar(20),
date_1 varchar(20),
caller_1 varchar(30),
date_2 varchar(20),
caller_2 varchar(20),
date_3 varchar(20),
caller_3 varchar(20)
);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' 
INTO TABLE sale_team_call_result_w15_28_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl

"
UPDATE sale_team_call_result_w15_28_stg
SET date_1 = STR_TO_DATE(date_1, '%m/%d/%Y');

UPDATE sale_team_call_result_w15_28_stg
SET date_2 = STR_TO_DATE(date_2, '%m/%d/%Y');

UPDATE sale_team_call_result_w15_28_stg
SET date_3 = STR_TO_DATE(date_3, '%m/%d/%Y');


select distinct caller_1 from sale_team_call_result_w15_28_stg;

create table sale_team_call_result_w15_28_stg_2 as 
	select 
	opty_id,caller_1 as caller,date_1 as date,
	"call_once" as attempt 
	from 
	sale_team_call_result_w15_28_stg
	where 
	caller_1 <> " "

	union ALL
	select
	opty_id,caller_2 as caller,date_2 as date,
	"call_twice"
	from 
	sale_team_call_result_w15_28_stg
	where 
	caller_2 <> " "

	union ALL
	select
	opty_id,caller_3 as caller,date_3 as date,
	"call_three_times"
	from 
	sale_team_call_result_w15_28_stg
	where 
	caller_3 <> " "
	;

alter table sale_team_call_result_w15_28_stg_2 add 
day_name varchar(20);

UPDATE sale_team_call_result_w15_28_stg_2
SET day_name = DAYNAME(date);

alter table sale_team_call_result_w15_28_stg_2 add 
target int(20);

UPDATE sale_team_call_result_w15_28_stg_2
SET target = case
when caller = "Bill Quaintance" then 86
when caller = "Jeremy Lubin"  then 70
when caller = "Rob Cooney"   then 100 
when caller = "Li Hu" then 33
Else 0
end;

alter table sale_team_call_result_w15_28_stg_2 add 
work varchar(20);

UPDATE sale_team_call_result_w15_28_stg_2
    SET work = case
    when caller = "Bill Quaintance" and day_name = "Wednesday" then "Y"
    when caller = "Bill Quaintance" and day_name = "Thursday" then "Y"
    when caller = "Jeremy Lubin" and day_name = "Wednesday" then "Y"
    when caller = "Jeremy Lubin" and day_name = "Thursday" then "Y"
    when caller = "Jeremy Lubin" and day_name = "Friday" then "Y"
    when caller = "Rob Cooney"  and day_name = "Wednesday" then "Y"
    when caller = "Rob Cooney" and day_name = "Thursday"then "Y"
    when caller = "Rob Cooney" and day_name = "Friday" then "Y"
    when caller = "Rob Cooney" and day_name = "Sunday" then "Y"
    when caller = "Rob Cooney" and day_name = "Sunday" then "Y"
    when caller = "Li Hu" and day_name = "Tuesday" then "Y"
    when caller = "Li Hu" and day_name = "Thursday" then "Y"
    when caller = "Li Hu" and day_name = "Friday" then "Y"
    Else "N"
    end;



===========================
create table sale_team_call_result_w15_24_aggregate as 
	select 
	"W15.23" as week_num,
	caller,
	date,day_name,target,
	count(opty_id) as number_called
	from sale_team_call_result_w15_28_stg_2
	group by caller, date;

alter table sale_team_call_result_w15_24_aggregate add 
target int(20);

UPDATE sale_team_call_result_w15_24_aggregate
SET target = case
when caller = "Bill Quaintance" then 87
when caller = "Jeremy Lubin" then 70
when caller = "Rob Cooney"  then 100 
when caller = "Li Hu" then 33
Else NULL
end;



========================================================================

create or replace view sale_team_call_result_w15_24_final_result as 
  select 
  caller as Caller,
  concat(
  count(
    case
    when day_name ="Monday" and date ="2015-06-01" then opty_id 
    else null
    end),
  	"/",
  		target
  		, " --- ", 100*count(
    case
    when day_name ="Monday" and date ="2015-06-01"   then opty_id
    else null
    end)/target,"%" ) as "Monday - 2015-06-01",

  concat(
  count(
    case
    when day_name ="Tuesday" and date ="2015-06-02" then opty_id
    else null
	end),"/", target, " --- ", 100*count(
    case
    when day_name ="Tuesday" and date ="2015-06-02"  then opty_id
    else null
	end)/target,"%" ) as "Tuesday - 2015-06-02",

  concat(
  count(
    case
    when day_name ="Wednesday" and date ="2015-06-03"  then opty_id
    else null
		end),"/", target, " --- ", 100*count(
    case
    when day_name ="Wednesday" and date ="2015-06-03"  then opty_id
    else null
		end)/target,"%" ) as "Wednesday - 2015-06-03",

  concat(
  count(
    case
    when day_name ="Thursday" and date ="2015-06-04"  then opty_id
    else null
		end),"/", target, " --- ", 100*count(
    case
    when day_name ="Thursday" and date ="2015-06-04"  then opty_id
    else null
		end)/target,"%" ) as "Thursday - 2015-06-04",

  concat(
  count(
    case
    when day_name ="Friday" and date ="2015-06-05"  then opty_id
    else null
		end),"/", target, " --- ", 100*count(
    case
    when day_name ="Friday" and date ="2015-06-05"  then opty_id
    else null
		end)/target,"%" ) as "Friday - 2015-06-05",

  concat(
  count(
    case
    when day_name ="Sunday" and date ="2015-06-07"  then opty_id
    else null
		end),"/", target, " --- ", 100*count(
    case
    when day_name ="Sunday" and date ="2015-06-07"  then opty_id
    else null
		end)/target,"%" ) as "Sunday - 6.07",

    concat(
  	count(
    case
    when day_name ="Monday" and date ="2015-06-08"  then opty_id
    else null
     end),
  	"/", target, " --- ", 100*count(
    case
    when day_name ="Monday" and date ="2015-06-08"  then opty_id
    else null
    end)/target,"%" ) as "Monday - 2015-06-08"
    from sale_team_call_result_w15_28_stg_2
    group by caller;


=======================
SBM-IFS-OPTY CHECK TABLE
=======================
### UPLOAD CSV VIA TOAD... NEED TO PROCESS BY EXCEL
drop table ifs_phone_consult_SBM_list_for_opty_check;
CREATE TABLE ifs_phone_consult_SBM_list_for_opty_check
(
booking_date varchar(50),
time varchar(20),	
provider varchar(20),	
Name varchar(20),
Email text,
Phone_number varchar(30),
Id int(20));

CREATE OR REPLACE VIEW ifs_phone_consult_SBM_list_for_opty_check_result as 
select 
a.*,b.owner,b.opp_id,b.note,b.phone_number as ifs_phone,b.first_name,b.last_name
from ifs_phone_consult_SBM_list_for_opty_check a
left join ifs_opty_list_w15_32 b
on b.contact_id = a.Id;

=========================

==============
Product_revenue_table 
==============

create table products_info_table  (
	Id int(20),
	product_name text,
	price varchar(20),
	category varchar(100));


update products_info_table 
	set category = case 
	when product_name like "%IVS%" or product_name like "%BOOK%" 
	or product_name like "%Video%" or product_name like "%Audio%"
	or product_name like "ZZ%" or product_name like "%digital%"
	or product_name like "%Series%" or product_name like "%Quickstart%"
	or product_name like "%Dating Genie%" or product_name like "%Essentials%"
	or product_name like "%Relationship%" or product_name like "%The Dating Essentials%"
	or product_name like "%DVD%" or product_name like "%Vol%"

	then "Product"
	else "Live_training"
	end;


create table products_category_table (
category varchar(20),
perceent_revenue DECIMAL(10,2)
);

INSERT INTO products_category_table 
(category, perceent_revenue)
VALUES ("Product",'0.8');

INSERT INTO products_category_table 
(category, perceent_revenue)
VALUES ("Live_training",'0.55');
===================================

====================
opty_CREATE_BY_SBM_FPC_CHECK
====================
CREATE TABLE ifs_phone_consult_SBM_list_7_14_2015
(
date varchar(30),
provider varchar(20),	
Name varchar(20),
Email text,
Phone_number varchar(30),
Id int(20));

UPDATE ifs_phone_consult_SBM_list_7_14_2015
SET date = STR_TO_DATE(date, '%m.%d.%Y');

update ifs_phone_consult_SBM_list_7_14_2015
	set provider = "Jeremy Lubin"
	where provider = "Jeremy" ;



create or replace view opty_by_sbm_check_result as 
	select a.Id,
	a.name,a.date as SBM_date_create,a.provider,
	concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=", b.opp_id) as opty_link,
	b.owner,b.opp,b.date_create,b.last_update, b.perecent,b.next_action,b.next_action_date,
	b.note,b.loss_reson,b.stage,"May updated opty by FPC" as type
	from ifs_phone_consult_SBM_list_7_14_2015 a 
	INNER join ifs_opty_list_w15_32 b
	on a.Id =  b.contact_id 
	and(b.last_update > a.date and a.provider=b.owner )
	group by a.Id

	union all 

	select 
	a.Id,
	a.name,a.date as SBM_date_create,a.provider,
	concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=", b.opp_id) as opty_link,
	b.owner,b.opp,b.date_create,b.last_update, b.perecent,b.next_action,b.next_action_date,b.note,b.loss_reson,
	b.stage,"Opty create by FPC" as type
	from ifs_phone_consult_SBM_list_7_14_2015 a 
	INNER join ifs_opty_list_w15_32 b
	on a.Id =  b.contact_id 
	and b.date_create> a.date
	group by a.Id;

select count(Id) from opty_by_sbm_check_result;


==================================================================

Alex Mail batch invoice report by sent

==================================================================

## ifs invoice all sale report for monday of week to 9days later

create table alex_mail_invoice_invoice_stg_w15_20 (
	inv_id int(20),
	contact_id int(20),
	product_id int(20),
	product varchar(20),
	inv_total varchar(20),
	date text);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE alex_mail_invoice_invoice_stg_w15_20 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS" dbl
"
## ifs get last 30days, and use data in date range
create table alex_mail_invoice_batch_stg_w15_20 (
contact_id int(20),
mail_id int(20),
sent text,
opened text
);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE alex_mail_invoice_batch_stg_w15_20 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS" dbl

"

## ifs email brocast report
create table alex_mail_invoice_brocast_stg_w15_20 (
mail_id int(20),
date text,
template text
);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE alex_mail_invoice_brocast_stg_w15_20 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS" dbl

"

=====================
import the data from IFS by followed format in toad
=====================

=================
clean the TABLEs
=================

UPDATE alex_mail_invoice_brocast_stg_w15_20
SET date = LEFT(date, locate(' ', date) - 1);

UPDATE alex_mail_invoice_brocast_stg_w15_20
SET date = STR_TO_DATE(date, '%m/%d/%Y');

ALTER TABLE alex_mail_invoice_brocast_stg_w15_20 ADD INDEX n1 (mail_id);


UPDATE alex_mail_invoice_invoice_stg_w15_20
SET date = STR_TO_DATE(date, '%m/%d/%Y');

UPDATE alex_mail_invoice_invoice_stg_w15_20
SET inv_total = CAST(REPLACE(REPLACE(IFNULL(inv_total,0),',',''),'$','') AS DECIMAL(10,2));

ALTER TABLE alex_mail_invoice_invoice_stg_w15_20 ADD INDEX n1 (contact_id);



delete from alex_mail_invoice_batch_stg_w15_20 where sent not BETWEEN "5/11/2015" and "5/17/2015";

UPDATE alex_mail_invoice_batch_stg_w15_20
SET sent = STR_TO_DATE(sent, '%m/%d/%Y');


ALTER TABLE alex_mail_invoice_batch_stg_w15_20 ADD INDEX n1 (contact_id);

ALTER TABLE alex_mail_invoice_batch_stg_w15_20 ADD INDEX n (mail_id);

ALTER TABLE alex_mail_invoice_batch_stg_w15_20 ADD INDEX n2 (contact_id,mail_id);

=============================================================

create table alex_mail_invoice_date_windows_w15_24 as 
	select 
	a.mail_id,
	b.datecol
	from alex_mail_invoice_brocast_stg_w15_20 a
	cross join date b
	on 
	b.datecol between a.date and DATE_ADD(a.date, INTERVAL 3 DAY);

ALTER TABLE alex_mail_invoice_date_windows_w15_24 ADD INDEX n1 (mail_id);

==============================================================

create table alex_mail_invoice_batch_contact_windows_w15_20 as 
	select 
	a.mail_id,a.contact_id,
	max(b.datecol) as last_date 
	from alex_mail_invoice_batch_stg_w15_20 a 
	left join alex_mail_invoice_date_windows_w15_24 b 
	on a.mail_id = b.mail_id 
	group by a.mail_id, a.contact_id;

ALTER TABLE alex_mail_invoice_batch_contact_windows_w15_20 ADD INDEX n1 (contact_id);
ALTER TABLE alex_mail_invoice_batch_contact_windows_w15_20 ADD INDEX n (last_date);

delete from alex_mail_invoice_batch_contact_windows_w15_20 where last_date is null;
select count(contact_id) from alex_mail_invoice_batch_contact_windows_w15_20 where last_date is null;
===================================================================

drop table alex_mail_invoice_inter2_w15_20;

create table alex_mail_invoice_inter2_w15_20 as 
	select 
	a.inv_id,b.mail_id,a.inv_total as "earned",
	a.product,c.template
	from alex_mail_invoice_invoice_stg_w15_20 a 
	left join alex_mail_invoice_batch_contact_windows_w15_20 b
	on a.contact_id = b.contact_id 
	and b.last_date >= a.date
	left join alex_mail_invoice_brocast_stg_w15_20 c
	on c.mail_id =b.mail_id ;

select sum(earned) from alex_mail_invoice_inter2_w15_20_cre where mail_id = 237338;
create table alex_mail_invoice_inter2_w15_20_cre as 
	select 
	* 
	from 
	alex_mail_invoice_inter2_w15_20
	where template like "%IVS%" or template like "%BCM%" 
	or template like "%LSI%" or template like "%WSM%";

select sum(earned) from alex_mail_invoice_inter2_w15_20_cre where mail_id = 237338;

alter table alex_mail_invoice_inter2_w15_20_cre add effect_sales decimal(10,2) after mail_id;

update alex_mail_invoice_inter2_w15_20_cre m 
	Inner join 
		(
		select inv_id, 
		count(mail_id) as total
		from alex_mail_invoice_inter2_w15_20_cre 
		group by inv_id 
		) r 
	on m.inv_id  = r.inv_id
	set 
	m.effect_sales = 1/total;

	alter table alex_mail_invoice_inter2_w15_20_cre add allocation varchar(20) after mail_id;

	update alex_mail_invoice_inter2_w15_20_cre
		set allocation = concat(effect_sales*100,"%");

update alex_mail_invoice_inter2_w15_20_cre
	set earned = earned * effect_sales;

ALTER TABLE alex_mail_invoice_inter2_w15_20_cre ADD INDEX n1 (mail_id);


----------------

alter table alex_mail_invoice_inter2_w15_20 add effect_sales decimal(10,2) after mail_id;

update alex_mail_invoice_inter2_w15_20 m 
	Inner join 
		(
		select inv_id, 
		count(mail_id) as total
		from alex_mail_invoice_inter2_w15_20 
		group by inv_id 
		) r 
	on m.inv_id  = r.inv_id
	set 
	m.effect_sales = 1/total;

	alter table alex_mail_invoice_inter2_w15_20 add allocation varchar(20) after mail_id;

	update alex_mail_invoice_inter2_w15_20
		set allocation = concat(effect_sales*100,"%");

update alex_mail_invoice_inter2_w15_20
	set earned = earned * effect_sales;
--------------------

============================================
	create final result review 
============================================

create or replace view alex_mail_invoice_batch_piv_w15_20 as 
	select mail_id,
	count(contact_id) as num_sent
from 
alex_mail_invoice_batch_stg_w15_20
group by mail_id;

create or replace view alex_mail_invoice_inter2_w15_20_piv_w15_20 as 
	select 
	mail_id,
	count(inv_id) as num_sale,
	sum(effect_sales) as effect_sales,
	sum(earned) as earned
	from alex_mail_invoice_inter2_w15_20
	group by 
	mail_id;

==== final result view ======


create or replace view alex_mail_invoice_result_w15_20 as 
	select 
	a.mail_id,b.num_sent as num_deliv,
	a.num_sale, a.effect_sales,a.earned,
	a.earned/b.num_sent as "earned_over_deliv"
	from alex_mail_invoice_inter2_w15_20_piv_w15_20 a 
	left join alex_mail_invoice_batch_piv_w15_20 b 
	on a.mail_id = b.mail_id;

===============================

create or replace view alex_mail_invoice_inter2_w15_20_cre_piv_w15_20 as 
	select 
	mail_id,
	count(inv_id) as num_sale,
	sum(effect_sales) as effect_sales,
	sum(earned) as earned
	from alex_mail_invoice_inter2_w15_20_cre
	group by 
	mail_id;

select sum(earned) from alex_mail_invoice_inter2_w15_20 where mail_id = 
237338;
==== final result view ======


create or replace view alex_mail_invoice_result_w15_20_cre as 
	select 
	a.mail_id,b.num_sent as num_deliv,
	a.num_sale, a.effect_sales,a.earned,
	a.earned/b.num_sent as "earned_over_deliv"
	from alex_mail_invoice_inter2_w15_20_cre_piv_w15_20 a 
	left join alex_mail_invoice_batch_piv_w15_20 b 
	on a.mail_id = b.mail_id;

===================================


==================================================================

Alex Mail batch invoice report for opend and adv only

==================================================================

## ifs invoice all sale report for monday of week to 9days later
create table alex_mail_invoice_invoice_w15_24_stg (
	inv_id int(20),
	contact_id int(20),
	product_id int(20),
	product varchar(100),
	inv_total varchar(20),
	date text);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE alex_mail_invoice_invoice_w15_24_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS" dbl
"

## ifs get last 30days, and use data in date range
create table alex_mail_invoice_batch_w15_24_stg (
contact_id int(20),
mail_id int(20),
sent text,
opened text
);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE alex_mail_invoice_batch_w15_24_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS" dbl

"
## ifs email brocast report
create table alex_mail_invoice_brocast_w15_24_stg (
mail_id int(20),
date varchar(30),
template text,
total_sent int(10),
dev_num int(10)
);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'brocast.csv'
INTO TABLE alex_mail_invoice_brocast_w15_24_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
IGNORE 1 LINES; SHOW WARNINGS" dbl

"

=====================
import the data from IFS by followed format in toad
=====================

=================
clean the TABLEs
=================

UPDATE alex_mail_invoice_brocast_w15_24_stg 
SET date = LEFT(date, locate(' ', date) - 1);

UPDATE alex_mail_invoice_brocast_w15_24_stg 
SET date = STR_TO_DATE(date, '%m/%d/%Y');

ALTER TABLE alex_mail_invoice_brocast_w15_24_stg  ADD INDEX n1 (mail_id);
ALTER TABLE alex_mail_invoice_brocast_w15_24_stg  ADD INDEX n (date);

ALTER TABLE date  ADD INDEX n (datecol);

UPDATE alex_mail_invoice_invoice_w15_24_stg
SET date = STR_TO_DATE(date, '%m/%d/%Y');

UPDATE alex_mail_invoice_invoice_w15_24_stg
SET inv_total = CAST(REPLACE(REPLACE(IFNULL(inv_total,0),',',''),'$','') AS DECIMAL(10,2));

ALTER TABLE alex_mail_invoice_invoice_w15_24_stg ADD INDEX n1 (contact_id);

select count(*) from alex_mail_invoice_batch_w15_24_stg;

delete from alex_mail_invoice_batch_w15_24_stg where opened not BETWEEN "6/1/2015" and "6/7/2015";

delete from alex_mail_invoice_batch_w15_24_stg where mail_id = "0";

UPDATE alex_mail_invoice_batch_w15_24_stg
SET opened = STR_TO_DATE(opened, '%m/%d/%Y');


ALTER TABLE alex_mail_invoice_batch_w15_24_stg ADD INDEX n1 (contact_id);

ALTER TABLE alex_mail_invoice_batch_w15_24_stg ADD INDEX n (mail_id);

ALTER TABLE alex_mail_invoice_batch_w15_24_stg ADD INDEX n2 (contact_id,mail_id);

ALTER TABLE alex_mail_invoice_batch_w15_24_stg MODIFY opened varchar(100);

ALTER TABLE alex_mail_invoice_batch_w15_24_stg ADD INDEX n3 (opened);

ALTER TABLE alex_mail_invoice_batch_w15_24_stg ADD last_date varchar(100);

update alex_mail_invoice_batch_w15_24_stg 
	set
	last_date =  DATE_ADD(opened, INTERVAL 3 DAY);

create table alex_mail_invoice_opened_window as 
	select *
	from alex_mail_invoice_batch_w15_24_stg
	group by 
	contact_id,mail_id;

=============================================================


===================================================================
drop table alex_mail_invoice_inter2_w15_24;

create table alex_mail_invoice_inter2_w15_24 as 
	select 
	a.inv_id,b.mail_id,a.inv_total as "earned",
	a.product,c.template,c.total_sent,c.dev_num
	from alex_mail_invoice_invoice_w15_24_stg a 
	left join alex_mail_invoice_opened_window b
	on a.contact_id = b.contact_id 
	and  a.date BETWEEN b.opened and b.last_date
	left join alex_mail_invoice_brocast_w15_24_stg c
	on c.mail_id =b.mail_id ;

alter table alex_mail_invoice_piv add adv varchar(20);



create table alex_mail_invoice_inter2_w15_24_cre as 
	select 
	* 
	from 
	alex_mail_invoice_inter2_w15_24
	where template like "%IVS%" or template like "%BCM%" 
	or template like "%LSI%" or template like "%WSM%";

alter table alex_mail_invoice_piv add effect_sales decimal(10,2) after mail_id;

update alex_mail_invoice_piv m 
	Inner join 
		(
		select inv_id, 
		count(mail_id) as total
		from alex_mail_invoice_piv
		where adv = "n" 
		group by inv_id 
		) r 
	on m.inv_id  = r.inv_id
	set 
	m.effect_sales = 1/total;

	alter table alex_mail_invoice_inter2_w15_24_cre add allocation varchar(20) after mail_id;

	update alex_mail_invoice_inter2_w15_24_cre
		set allocation = concat(effect_sales*100,"%");

update alex_mail_invoice_inter2_w15_24_cre
	set earned = earned * effect_sales;

ALTER TABLE alex_mail_invoice_inter2_w15_24_cre ADD INDEX n1 (mail_id);

----------

alter table alex_mail_invoice_inter2_w15_24 add effect_sales decimal(10,2) after mail_id;

update alex_mail_invoice_inter2_w15_24 m 
	Inner join 
		(
		select inv_id, 
		count(mail_id) as total
		from alex_mail_invoice_inter2_w15_24 
		group by inv_id 
		) r 
	on m.inv_id  = r.inv_id
	set 
	m.effect_sales = 1/total;

	alter table alex_mail_invoice_inter2_w15_24 add allocation varchar(20) after mail_id;

	update alex_mail_invoice_inter2_w15_24
		set allocation = concat(effect_sales*100,"%");

update alex_mail_invoice_inter2_w15_24
	set earned = earned * effect_sales;

ALTER TABLE alex_mail_invoice_inter2_w15_24 ADD INDEX n1 (mail_id);


select distinct(template) from alex_mail_invoice_inter2_w15_24;

============================================
	create final result review 
============================================

create or replace view alex_mail_invoice_batch_piv_w15_20_1 as 
	select mail_id,
	count(contact_id) as num_opened
from 
alex_mail_invoice_batch_w15_24_stg
group by mail_id;

create or replace view alex_mail_invoice_inter2_w15_24_piv_w15_20 as 
	select 
	mail_id,
	count(inv_id) as num_sale,
	sum(effect_sales) as effect_sales,
	sum(earned) as earned
	from alex_mail_invoice_inter2_w15_24
	group by 
	mail_id;

create or replace view alex_mail_invoice_inter2_w15_24_cre_piv_w15_20 as 
	select 
	mail_id,
	count(inv_id) as num_sale,
	sum(effect_sales) as effect_sales,
	sum(earned) as earned
	from alex_mail_invoice_inter2_w15_24_cre
	group by 
	mail_id;
==== final result view ======


create or replace view alex_mail_invoice_result_w15_20_1 as 
	select 
	a.mail_id,b.num_opened,c.num_sent as num_deliv,
	a.num_sale, a.effect_sales,a.earned,
	a.earned/b.num_opened as "earned_over_open"
	from alex_mail_invoice_inter2_w15_24_piv_w15_20 a 
	left join alex_mail_invoice_batch_piv_w15_20_1 b 
	on a.mail_id = b.mail_id
	left join 
	alex_mail_invoice_batch_piv_w15_20 c
	on a.mail_id = c.mail_id;

create or replace view alex_mail_invoice_result_w15_20_1_cre as 
	select 
	a.mail_id,b.num_opened,c.num_sent as num_deliv,
	a.num_sale, a.effect_sales,a.earned,
	a.earned/b.num_opened as "earned_over_open"
	from alex_mail_invoice_inter2_w15_24_cre_piv_w15_20 a 
	left join alex_mail_invoice_batch_piv_w15_20_1 b 
	on a.mail_id = b.mail_id
	left join 
	alex_mail_invoice_batch_piv_w15_20 c
	on a.mail_id = c.mail_id;
===============================

result table for David
================================

Create or replace view alex_mail_invoice_result_w15_20_by_sent as 
select 
a.mail_id,a.num_deliv,a.num_sale as non_adv_sale_num,b.num_sale as adv_sale_num,
a.effect_sales as non_adv_effect_sale,b.effect_sales as adv_effect_sale,
a.earned as non_adv_earned, b.earned as adv_earned,
a.earned_over_deliv as "non_adv_$/deliv",
b.earned_over_deliv as "adv_$/deliv"
from 
alex_mail_invoice_result_w15_20 a 
left join 
alex_mail_invoice_result_w15_20_cre b 
on 
a.mail_id = b.mail_id;


Create or replace view alex_mail_invoice_result_w15_20_by_open as 
select 
a.mail_id,a.num_deliv,a.num_opened as non_adv_num_opened,
b.num_opened as adv_num_opened, a.num_sale as non_adv_sale_num,b.num_sale as adv_sale_num,
a.effect_sales as non_adv_effect_sale,b.effect_sales as adv_effect_sale,
a.earned as non_adv_earned, b.earned as adv_earned,
a.earned_over_open as "non_adv_$/open",
b.earned_over_open as "adv_$/open"
from 
alex_mail_invoice_result_w15_20_1 a 
left join 
alex_mail_invoice_result_w15_20_1_cre b 
on 
a.mail_id = b.mail_id;

==============================

Recenty activity table 

==============================

use dbl;

create table recenty_activity_stg (
contact_id int(20),
first_name varchar(100),
last_name varchar(100),
email text,
type text,
des text,
date text);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' dbl


mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE recenty_activity_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl
"

select distinct type from recenty_activity_stg;

===========================================================

CREATE TABLE OPT_OUT_list (
contact_id int(20),
type varchar(20)

);

alter table OPT_OUT_list add index rw(contact_id);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE OPT_OUT_list FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl
"

CREATE TABLE ifs_batch_list_0609(
Contact_Id int(20),
First_Name varchar(20),
Last_Name varchar(20),
Batch_Id int(20),
Sent varchar(20), 
Opened varchar(20),
Clicked varchar(20),
Link_Clicked text);

alter table ifs_batch_list_0609 add index rw(Contact_Id);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE ifs_batch_list_0609 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl
"

create table opt_out_list_stg as 
	select 
	a.Contact_id,
	a.Batch_Id,
	a.sent,
	a.Opened,
	a.Link_Clicked,
	b.type
	from 
			OPT_OUT_list b 
	 	left join 
	ifs_batch_list_0609 a
	on 
	a.Contact_id = b.contact_id;

create table opt_out_list_cln as 
select * from opt_out_list_stg where Contact_id is not null;

create or replace view opt_out_list as 
	select 
	Batch_Id,
	count(Contact_id) as count,
	sent,Opened,

=================================================


sale team weekly sale report 

==================================================

create table sale_team_weekly_invoice_w15_29_stg (
name varchar(20),
date varchar(50),
inv_id int(20),
product_id varchar(20),
product_name varchar(100),
contact_id int(20),
inv_total varchar(50),
total_paid varchar(20),
referral_id int(20),
sources varchar(20)
);


mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE sale_team_weekly_invoice_w15_29_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl
"

alter table sale_team_weekly_invoice_w15_29_stg add index rw(date);
alter table sale_team_weekly_invoice_w15_29_stg add index rw_1(inv_total);
alter table sale_team_weekly_invoice_w15_29_stg add index rw_2(inv_id);
alter table sale_team_weekly_invoice_w15_29_stg add index rw_3(referral_id);



UPDATE sale_team_weekly_invoice_w15_29_stg
SET date = STR_TO_DATE(date, '%m/%d/%Y');


drop table sale_team_weekly_invoice_w15_29_cln;
create table sale_team_weekly_invoice_w15_29_cln as 
	select 
	a.inv_id,
	a.name,
	a.referral_id,
	a.inv_total,
	a.total_paid as amt_paid,
	a.date,
	a.sources,
	a.product_name,
	b.week_number
	from sale_team_weekly_invoice_w15_29_stg a
	left join date_and_week_num b
	on a.date = b.date;

UPDATE sale_team_weekly_invoice_w15_29_cln
SET amt_paid = CAST(REPLACE(REPLACE(IFNULL(amt_paid,0),',',''),'$','') AS DECIMAL(10,2));

UPDATE sale_team_weekly_invoice_w15_29_cln
SET inv_total = CAST(REPLACE(REPLACE(IFNULL(inv_total,0),',',''),'$','') AS DECIMAL(10,2));

alter table sale_team_weekly_invoice_w15_29_cln add 
referral_partner varchar(20);

update sale_team_weekly_invoice_w15_29_cln 
	set 
	referral_partner = case 
	when referral_id = 7 then "Jeremy"
	when referral_id = 9 then "Bill"
	when referral_id = 4738 then "Rob"
	when referral_id = 4964 then "Li Hu"
	when referral_id = 4662 then "Savoy"
	else "Other"
	end;



drop table sale_team_sale_report_final_w15_29;
create table sale_team_sale_report_final_w15_29 as 
  select 
  week_number as "Week:",
  sum(
    case
    when referral_partner ="Jeremy" and sources ="Offline" then inv_total
    end)      as "Jeremy",
        sum(
    case
    when referral_partner ="Bill" and sources ="Offline" then inv_total
    end) 
      as "Bill"
,
  sum(
    case
    when referral_partner ="Rob" and sources ="Offline" then inv_total
    end) 
      as "Rob"
,
  sum(
    case
    when referral_partner ="Li Hu" and sources ="Offline" then inv_total
    end) 
      as "Li"
,
  sum(
    case
    when referral_partner ="Savoy" and sources ="Offline" then inv_total
    end) 
      as "Savoy"
 ,
 sum(case
    when (referral_partner ="Jeremy" or referral_partner ="Bill" or referral_partner ="Rob")
    and sources ="Offline" 
    then inv_total
    end) as "pgm advisors"
 ,
  sum(case
    when (referral_partner ="Jeremy" or referral_partner ="Bill" or referral_partner ="Rob"
    	or referral_partner ="Li Hu" or referral_partner ="Savoy")
    and sources ="Offline" 
    then inv_total
    end) as "Total advised sales"
,
  sum(case
    when (referral_partner <>"Jeremy" and  referral_partner <>"Bill" and referral_partner <>"Rob"
    	and  referral_partner <>"Li Hu" and  referral_partner <>"Savoy")
    and sources ="Offline" 
    then inv_total
    end) as "Other Offline sale"
  ,
   sum(case
    when  sources ="Online" 
    then inv_total
    end) as "Online sales" 
,

  sum( inv_total) as "Total sales",
    count( inv_total) as "# sales"


from sale_team_weekly_invoice_w15_29_cln
group by week_number;


update sale_team_sale_report_final_w15_29 set Jeremy = 0 where Jeremy is null;

update sale_team_sale_report_final_w15_29 set Bill = 0 where Bill is null;

update sale_team_sale_report_final_w15_29 set Rob = 0 where Rob is null;

update sale_team_sale_report_final_w15_29 set Li = 0 where Li is null;

update sale_team_sale_report_final_w15_29 set Savoy = 0 where Savoy is null;

=============================

DOB check 

=============================
drop table DOB_weekly_check_list;

create table DOB_weekly_check_list as 
	select 
	a.contact_id,a.first_name,a.last_name,a.phone,a.email,a.DOB,a.country,
	b.owner,b.stage
	from ifs_whole_contact_cln_150803 a
	left join ifs_opty_list_w15_32 b
	on a.contact_id = b.contact_id
	where 
	MONTH(a.DOB) = 07  
	and 
	a.phone <> " "
	and day(a.DOB) between 06 and 12
	;

============================

item sale report 
create table ifs_item_sale_stg_2_150506 AS
SELECT  contact_id,sa.order_id as invoice_id,
a.product_id,sa.inv_total, a.product_price
FROM ifs_item_product_id_table AS a
JOIN ifs_invoice_cln_150506 AS sa
ON FIND_IN_SET(a.product_id, sa.product_id);
==========================


alter table date_and_week_num add number_week  int(20);
alter table date_and_week_num add week_number  varchar(20);

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'date.csv' INTO TABLE date_and_week_num FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl

UPDATE date_and_week_num
SET date = STR_TO_DATE(date, '%m/%d/%Y');

update date_and_week_num 
	set 
	number_week= WEEKOFYEAR(date);


update date_and_week_num
	set year = case 
	when 


	update  date_and_week_num
		set week_number = case 
		when length(number_week) = 1
		then  CONCAT("W",right(year,2),".0",number_week)
		when length(number_week)=2
		then  CONCAT("W",right(year,2),".",number_week)
		end;


=============================================================


SBM-FPC-weekly Sign up table 


=============================================================

drop table SBM_weekly_sign_up_stg;
create table SBM_weekly_sign_up_stg (
date varchar(20),
provider varchar(20),
record_date varchar(20)
);

UPDATE SBM_weekly_sign_up_stg
SET record_date = LEFT(record_date, locate(' ', record_date) - 1)
WHERE locate(' ',record_date) > 0;

UPDATE SBM_weekly_sign_up_stg
SET date = STR_TO_DATE(date, '%m.%d.%Y');


drop table SBM_weekly_sign_up_cln;
create table SBM_weekly_sign_up_cln as 
	select 
	a.date,a.provider,
	b.week_number,
	 "consult" as type
	from SBM_weekly_sign_up_stg a
	left join date_and_week_num b
	on a.date = b.date

	union all 

	select 
	a.record_date,a.provider,
	b.week_number,
	"sign" as type
	from SBM_weekly_sign_up_stg a
	left join date_and_week_num b
	on a.record_date = b.date;


	create or replace view SBM_sign_number as 
	select
	week_number,
	sum(
		case 
		when  type = "sign"
		then 1
		else 0
		end
		) as number_created,
	sum(
		case 
		when type = "consult"
		then 1 
		else 0
		end ) as number_consult
	from SBM_weekly_sign_up_cln
	group by week_number;

	create or replace view SBM_sign_number_by_provider as 
	select
	week_number, provider,
	sum(
		case 
		when  type = "sign"
		then 1
		else 0
		end
		) as number_signed,
	sum(
		case 
		when type = "consult"
		then 1 
		else 0
		end ) as number_consult
	from SBM_weekly_sign_up_cln
	group by week_number,provider;


create table FPC_Do_not_sent_list (
date varchar(20),
name varchar(30),
email text,
phone_number int(20)
);

UPDATE FPC_Do_not_sent_list
SET date = STR_TO_DATE(date, '%m.%d.%Y');

alter table FPC_Do_not_sent_list add dont_sent_until varchar(20);

update FPC_Do_not_sent_list
	set 
	dont_sent_until =  DATE_ADD( date, INTERVAL 6 month ) ;
==================================================
create table sale_team_fpc_sale_check_stg (
	name varchar(100),
	date varchar(20),
	inv_id int(20),
	product_id varchar(50),
	product_name varchar(200),
	contact_id int(20),
	inv_total varchar(20),
	total_paid varchar(20),
	partern int(20),
	sources varchar(200));

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE sale_team_fpc_sale_check_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl


drop table sale_team_fpc_sale_check_stg_2;

create table sale_team_fpc_sale_check_stg_2 AS
SELECT sa.inv_id,sa.name,sa.date,a.Id,a.product_name,a.price, sa.contact_id,sa.inv_total,sa.total_paid,sa.partern,sa.sources
FROM products_info_table AS a
JOIN sale_team_fpc_sale_check_stg AS sa
ON FIND_IN_SET(a.Id, sa.product_id);




==========================================================================
Auto dialing Daily call result check
==========================================================================

create table auto_daily_check_monday_result(
first_name varchar(100),
Phone varchar(50),
duration varchar(20),
result varchar(100),
note text,
id int(20),
ifs_link text,
what_to_sell text,
time_zone text,
caller varchar(20));

alter table auto_daily_check_monday_result add index rw(result);

alter table auto_daily_check_monday_result add day varchar(20);
alter table auto_daily_check_tuesday_result add day varchar(20);
alter table auto_daily_check_wednesday_result add day varchar(20);

update auto_daily_check_monday_result set day = "monday";
update auto_daily_check_tuesday_result set day = "tuesday";
update auto_daily_check_wednesday_result set day = "wednesday";

==========================================================================
Result mapping table 
==========================================================================
create table auto_daily_check_result_mapping
	(disposition varchar(100),
		next_round varchar(20),
		action varchar(100)
		);
	alter table auto_daily_check_result_mapping add index rw(disposition);

===========================================================================
result table 
===========================================================================

create table auto_daily_check_tuesday_result_final as 
	select a.*,
	b.*,"tuesday" as day
	from auto_daily_check_tuesday_result a
	left join auto_daily_check_result_mapping b 
	on 
	a.result  = b.disposition
	where 
	b.next_round= "Yes";

alter table auto_daily_check_monday_result_final add day varchar(20);
alter table auto_daily_check_tuesday_result_final add day varchar(20);
alter table auto_daily_check_wednesday_result_final add day varchar(20);

update auto_daily_check_monday_result_final set day = "monday";
update auto_daily_check_tuesday_result_final set day = "tuesday";
update auto_daily_check_wednesday_result_final set day = "wednesday";

drop view auto_daily_all_result_final;
create or replace view auto_daily_all_result as 
	select *
	from auto_daily_check_monday_result
	union all 
		select *
	from auto_daily_check_tuesday_result
	union all 
		select *
	from auto_daily_check_wednesday_result;


create or replace view auto_daily_check_stats_result as 
  select 
  caller,day as Day,
  count(first_name) as "number of customer should call",
   sum(
    case
    when result <> " "  then 1 
    else 0
    end) as "number of calls",
  count(first_name) -   sum(
    case
    when result <> " "  then 1 
    else 0
    end) as "Number did not call",
  sum(
    case
    when result ="Interested" or result = "INTERESTED - FOLLOW UP" or 
    result = "interested - opty" then 1 
    else 0
    end) as "number of opty",
   sum(
    case
    when duration <> " " then 1 
    else 0
    end) as "number of pick up",   
   
    concat(
    	 sum(
    case
    when duration <> " " then 1 
    else 0
    end)/sum(
    case
    when result <> " "  then 1 
    else 0
    end)*100,"%") as "% of pick-up over called"
  from auto_daily_all_result
    group by caller,day;


=================================


======================================================================================
create or replace view weekly_opty_action_report as 
select
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
"New opty from last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32
where date_create between "2015-06-01" and "2015-06-07"

create or replace view weekly_opty_action_report as 
select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
note as Action,
"Opty addressed at last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ",order_revenue) as Result
From ifs_opty_list_w15_32 
where next_action_date between "2015-06-08" and "2015-06-14"
and (stage = "Lost" or stage = "Won");

select count(result), type from weekly_opty_action_report group by type;





==========================================================================================

New sale team weekly invoice report 

==========================================================================================

drop table sale_team_sale_report_new_final_w15_25;
create table sale_team_sale_report_new_final_w15_25 as 
  select 
  week_number as "Week:",
  sum(
    case
    when referral_partner ="Jeremy" and sources ="Offline" then inv_total
    end) 
      as "Jeremy",
        sum(
    case
    when referral_partner ="Bill" and sources ="Offline" then inv_total
    end) 
      as "Bill"
,
  sum(
    case
    when referral_partner ="Rob" and sources ="Offline" then inv_total
    end) 
      as "Rob"
,
  sum(
    case
    when referral_partner ="Li Hu" and sources ="Offline" then inv_total
    end) 
      as "Li"
,
  sum(
    case
    when referral_partner ="Savoy" and sources ="Offline" and inv_total < 15000 
    then inv_total
    end) 
      as "Savoy"
 ,
 sum(case
    when (referral_partner = "Other")
    then inv_total
    end) as "Other"
 ,
  sum(case
    when (product_name="One-on-One with Venture" and inv_total >= 15000) then inv_total
    end) as "PR"
,
  sum(case
    when ((inv_total =297 or inv_total = 0.01 or inv_total = 997 or inv_total =700) and referral_partner ="Li Hu")
    then inv_total
    end) as "MM"
,

  sum( inv_total) as "Total sales",
    count( inv_total) as "# sales"


from sale_team_weekly_invoice_w15_29_cln
group by week_number;


update sale_team_sale_report_final_w15_29 set Jeremy = 0 where Jeremy is null;

update sale_team_sale_report_final_w15_29 set Bill = 0 where Bill is null;

update sale_team_sale_report_final_w15_29 set Rob = 0 where Rob is null;

update sale_team_sale_report_final_w15_29 set Li = 0 where Li is null;

update sale_team_sale_report_final_w15_29 set Savoy = 0 where Savoy is null;

=======================================================
customers country count stats 
=======================================================

select count(distinct id) from geo_mapping 
where geocell like  or 'North America / Canada%';

create or replace view geo_US as 
select distinct id, "US" as country from geo_mapping 
where geocell like 'North America / United States%';

create or replace view geo_CANADA as 
select distinct id,"CANADA" as country from geo_mapping 
where geocell like 'North America / Canada%';

create or replace view geo_NA as 
	SELECT distinct id,"NA" as country from geo_mapping WHERE geocell = 'N / A' AND ct = 4;


create table geo_non_int as 
	select distinct id from geo_US 
	union all 
	select distinct id from geo_CANADA 
	union all 
	select distinct id from geo_NA; 

	alter table geo_non_int add index rw (id);
	alter table geo_mapping add index rw (id);

select count(distinct id) from geo_mapping;

select count(distinct id) from geo_non_int;
select count(distinct id) from geo_US;
select count(distinct id) from geo_CANADA;
select count(distinct id) from geo_NA;

drop view geo_int;
create table geo_int as 

	select a.id, "INT" as country 

	from geo_mapping a 
	left join geo_non_int b
	on a.id <> b.id;


====================
Auto List report 
====================
drop table auto_list;
create table auto_list  
(Name varchar(100),
duration varchar(100),
result varchar(100),
Note varchar(100),
id int(20),
caller varchar(20)
);


## need to process the data in the excel before import to the MYSQL

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'auto.csv' INTO TABLE auto_list FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl


UPDATE auto_list
SET Note = STR_TO_DATE(Note, '%m/%d/%Y');


UPDATE auto_list
SET duration = left(duration,1);

ALTER TABLE auto_list MODIFY duration int(10);




=========================================================================================================


================
ALLWORKS Phone Report 
================
change Ip to the 192.168.1.11, 255,255,255..

go to the http://192.168.1.12:8080/ Password:12345

Download the Report 
######

Create table sale_team_weekly_phone_call_time_w15_29_stg
(
ID int(20),
date varchar(20),
time text,
legnth varchar(20),
from_who varchar(20),
cid text,
cid_num int(20),
port_1 text,
to_whom text,
cid_name text,
cid_number int(20),
port_2 text,
pin text,
digits text,
tc int(20));



mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE sale_team_weekly_phone_call_time_w15_29_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl


select distinct from_who from sale_team_weekly_phone_call_time_w15_29_stg;

select distinct cid_name from sale_team_weekly_phone_call_time_w15_29_stg;

Create table sale_team_weekly_phone_call_time_w15_29_cln as 
	select 
	ID,date,legnth,from_who,to_whom,cid_name
	from 
	sale_team_weekly_phone_call_time_w15_29_stg
	where
	from_who = "SALES1 INTERN1" or from_who = "JEREMY - LUBIN" or from_who = "WILLIAM - QUAINTANCE"
	or 
	((from_who = "LSI 1" or from_who = "LSI 2" or from_who = "LSI 3" or from_who = "LSI 4" or from_who = "LSI 5"
	or from_who = "LSI 6") and (cid_name ="JEREMY LUBIN" or cid_name = "WILLIAM - QUAINTANCE" 
	or cid_name = "SALES1 INTERN1"));

alter table sale_team_weekly_phone_call_time_w15_29_cln add owner varchar(20);

update sale_team_weekly_phone_call_time_w15_29_cln 
	set 
	owner  = case 
	when from_who = "SALES1 INTERN1" or cid_name = "SALES1 INTERN1" then "Rob"
	when from_who = "JEREMY - LUBIN" or cid_name = "JEREMY - LUBIN" or cid_name="JEREMY LUBIN" then "Jeremy"
	when from_who = "WILLIAM - QUAINTANCE" or cid_name = "WILLIAM - QUAINTANCE" then "Bill"
	else "Wrong"
	end;

UPDATE sale_team_weekly_phone_call_time_w15_29_cln
SET date = STR_TO_DATE(date, '%m/%d/%Y');

alter table sale_team_weekly_phone_call_time_w15_29_cln add length_sec varchar(20);

update sale_team_weekly_phone_call_time_w15_29_cln 
set 
length_sec = time_to_sec(legnth);


alter table sale_team_weekly_phone_call_time_w15_29_cln add index rw (date);

alter table sale_team_weekly_phone_call_time_w15_29_cln add length_hour varchar(20);

update sale_team_weekly_phone_call_time_w15_29_cln 
set 
length_hour = time_format(SEC_TO_TIME(length_sec),'%Hh %im');

time_format(SEC_TO_TIME(sum(a.length_sec),'%Hh %im %ss') as sum_2,



create table sale_team_weekly_phone_call_time_banchmark 
	(
		caller varchar(20),
		time varchar(20)

		);


drop table sale_team_weekly_phone_call_time_report_w15_29;

create table sale_team_weekly_phone_call_time_report_w15_29 as 
	select 
	a.owner as "Caller",
	b.week_number,a.date,
  SEC_TO_TIME(sum(a.length_sec
    )) as "total_call_sec",
    
    count(
    a.ID) as "number of calls",

    count(distinct a.date) as "number_day_worked",

     SEC_TO_TIME((sum(a.length_sec
    ))/c.days) as "ave_time_day",

     SEC_TO_TIME(c.time) as banch_mark,

    concat(((sum(a.length_sec)/c.days)/c.time-1)*100,"%") as "variance"

   from sale_team_weekly_phone_call_time_w15_29_cln a 
   left join date_and_week_num b 
   on a.date = b.date
   left join sale_team_weekly_phone_call_time_banchmark c
   on a.owner = c.caller
   group by a.owner,b.week_number,a.date;


=============================================================

update phone_leads_w15_30_stg_2 set 
	segment = "Freeinner"
where Link_Clicked="https://love-systems.leadpages.net/igbook-dl/";


select count(contact_id),segment from phone_leads_w15_30_stg_2 group by segment;

drop table inner_check;
create table inner_check as
select * from phone_leads_w15_30_stg_2 
where 
segment  = "Freeinner";

alter table inner_check add index rw(contact_id);


drop table inner_check_2;
create table inner_check_2 as 
	select a.* 
	from 
	phone_leads_w15_30_stg_2 a
	INNER join inner_check b 
	on a.contact_id = b.contact_id;

drop table inner_check_3;
create table inner_check_3 as 
select Contact_id, count(distinct segment) as ct from inner_check_2 
GROUP by Contact_id;

select count(Contact_Id) from inner_check_3 where ct = 1;


mysql -h www.theattractionforums.com -P 3306 --user=dev --password='dgkknhg$##k'


mysql -h www.theattractionforums.com -P 3306 --user=root --password='mB5k5J0wyY'

mysql -h www.theattractionforums.com -P 3306 --user=taf_vb_prod2 --password='7Y9Q3guQs'

=============================================================

Weekly sale performance report 

==============================================================


create table sale_team_performance_schedule
	(
		week_number varchar(20),
		name varchar(20),
		days int(10),
		target_sale int(20)
);
=================================================================
## sales report 
============================================================

create table sale_team_weekly_invoice_w15_29_stg (
name varchar(20),
date varchar(50),
inv_id int(20),
product_id varchar(20),
product_name varchar(100),
contact_id int(20),
inv_total varchar(50),
total_paid varchar(20),
referral_id int(20),
sources varchar(20)
);


mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv'
INTO TABLE sale_team_weekly_invoice_w15_29_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'IGNORE 1 LINES; SHOW WARNINGS" dbl
"

alter table sale_team_weekly_invoice_w15_29_stg add index rw(date);
alter table sale_team_weekly_invoice_w15_29_stg add index rw_1(inv_total);
alter table sale_team_weekly_invoice_w15_29_stg add index rw_2(inv_id);
alter table sale_team_weekly_invoice_w15_29_stg add index rw_3(referral_id);



UPDATE sale_team_weekly_invoice_w15_29_stg
SET date = STR_TO_DATE(date, '%m/%d/%Y');


drop table sale_team_weekly_invoice_w15_29_cln;
create table sale_team_weekly_invoice_w15_29_cln as 
	select 
	a.inv_id,
	a.name,
	a.referral_id,
	a.inv_total,
	a.total_paid as amt_paid,
	a.date,
	a.sources,
	a.product_name,
	b.week_number
	from sale_team_weekly_invoice_w15_29_stg a
	left join date_and_week_num b
	on a.date = b.date;

UPDATE sale_team_weekly_invoice_w15_29_cln
SET amt_paid = CAST(REPLACE(REPLACE(IFNULL(amt_paid,0),',',''),'$','') AS DECIMAL(10,2));

UPDATE sale_team_weekly_invoice_w15_29_cln
SET inv_total = CAST(REPLACE(REPLACE(IFNULL(inv_total,0),',',''),'$','') AS DECIMAL(10,2));

alter table sale_team_weekly_invoice_w15_29_cln add 
referral_partner varchar(20);

update sale_team_weekly_invoice_w15_29_cln 
	set 
	referral_partner = case 
	when referral_id = 7 then "Jeremy"
	when referral_id = 9 then "Bill"
	when referral_id = 4738 then "Rob"
	when referral_id = 4964 then "Li Hu"
	when referral_id = 4662 then "Savoy"
	else "Other"
	end;

drop table sale_team_sale_report_final_w15_29;
create table sale_team_sale_report_final_w15_29 as 
	select
	a.referral_partner as member,
	sum(a.inv_total) as sale,
	b.days,
	b.target_sale
	from sale_team_weekly_invoice_w15_29_cln a 
	left join sale_team_performance_schedule b
	on a.referral_partner = b.name
	where (a.referral_partner ="Jeremy" or a.referral_partner ="Bill" or a.referral_partner ="Rob")
	and a.sources ="Offline"
	group by a.referral_partner;




drop table sale_team_sale_report_final_w15_29;


## FPC 

drop table SBM_weekly_sign_up_stg
create table SBM_weekly_sign_up_stg (
date varchar(20),
provider varchar(20),
record_date varchar(20)
);

UPDATE SBM_weekly_sign_up_stg
SET record_date = LEFT(record_date, locate(' ', record_date) - 1)
WHERE locate(' ',record_date) > 0;

UPDATE SBM_weekly_sign_up_stg
SET date = STR_TO_DATE(date, '%m.%d.%Y');


drop table SBM_weekly_sign_up_cln;
create table SBM_weekly_sign_up_cln as 
	select 
	a.date,a.provider,
	b.week_number,
	 "consult" as type
	from SBM_weekly_sign_up_stg a
	left join date_and_week_num b
	on a.date = b.date

	union all 

	select 
	a.record_date,a.provider,
	b.week_number,
	"sign" as type
	from SBM_weekly_sign_up_stg a
	left join date_and_week_num b
	on a.record_date = b.date;

	update SBM_weekly_sign_up_cln 
		set provider  = case 
		when 
		provider  = "Bill Quaintance" then "Bill"
		when 
		provider  = "Rob Cooney" then "Rob"
		when 
		provider  = "Jeremy" then "Jeremy"
		when
		provider = "Li Hu" then "Li"
		when 
		provider = "Dylan Smith" then "Nick"
		end;

	create or replace view SBM_sign_number as 
	select
	week_number,
	sum(
		case 
		when  type = "sign"
		then 1
		else 0
		end
		) as number_created,
	sum(
		case 
		when type = "consult"
		then 1 
		else 0
		end ) as number_consult
	from SBM_weekly_sign_up_cln
	group by week_number;

	create or replace view SBM_sign_number_by_provider as 
	select
	week_number, provider,date,
	sum(
		case 
		when  type = "sign"
		then 1
		else 0
		end
		) as number_signed,
	sum(
		case 
		when type = "consult"
		then 1 
		else 0
		end ) as number_consult
	from SBM_weekly_sign_up_cln
	group by week_number,provider;

drop table sale_team_performance_fpc;
create table sale_team_performance_fpc as 
	select * 
	from SBM_sign_number_by_provider
	where 
	(provider ="Jeremy" or provider ="Bill Quaintance" or provider ="Rob Cooney") and (date between "2015-07-13" and "2015-07-19" );


	## Opty table 
create or replace view weekly_opty_action_report as 
select
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
"New opty from last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32
where date_create between "2015-07-13" and "2015-07-19" 

union all 

select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
note as Action,
"Opty addressed at last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ",order_revenue) as Result
From ifs_opty_list_w15_32 
where next_action_date between "2015-07-13" and "2015-07-19"
and (stage = "Lost" or stage = "Won")

union all 
select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",a.opp_id)
as Opty_Link,
a.Owner,
a.contact_name as Contact_Name,
a.phone_number as Phone_Number,
concat(b.opp,"--->", a.opp) as Opty_Description,
concat(b.next_action_date,"--->",a.next_action_date) as Next_action_date,
concat(a.next_action," | ",a.note) as Action,
"Opty addressed at last week" as Type,
concat(b.stage,"--->",a.stage) as Working_Stage,
concat(b.loss_reson, "--->",a.loss_reson," | ",b.order_revenue,"--->", a.order_revenue) as Result
From ifs_opty_list_w15_32 a
left join ifs_opty_list_w15_26 b
on b.opp_id = a.opp_id 
where a.next_action_date <> b.next_action_date
and (a.stage = "Working"
and a.next_action_date > "2015-07-19")


union all 
select 
concat("W15.", WEEK(curdate())) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
"Opty did not address at last week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32
where next_action_date between "2015-07-13" and "2015-07-19"
and last_update not between "2015-07-13" and "2015-07-19"

union all 
select
concat("W15.", WEEK(curdate())+1) as "Week Number",
concat("https://lovesystems.infusionsoft.com/Opportunity/manageOpportunity.jsp?view=edit&ID=",opp_id)
as Opty_Link,
Owner,
contact_name as Contact_Name,
phone_number as Phone_Number,
opp as Opty_Description,
next_action_date as Next_action_date,
concat(next_action," | ",note) as Action,
 "Opty will address this week" as Type,
stage as Working_Stage,
concat(loss_reson," | ", order_revenue) as Result
From ifs_opty_list_w15_32 a
where next_action_date between "2015-07-13" and "2015-07-19" ;

drop table sale_team_performance_opty;

create table sale_team_performance_opty as 
	select 
	"W15.28" as week_number,
	Owner,type,count("Week Number") as count
	from weekly_opty_action_report_w15_30
	where owner <> "Li Hu"
	group by owner, type;


#### allworks call time result 
change Ip to the 192.168.1.11, 255,255,255..

go to the http://192.168.1.12:8080/ Password:12345

Download the Report 
######
drop table sale_team_weekly_phone_call_time_w15_29_stg;
Create table sale_team_weekly_phone_call_time_w15_29_stg
(
ID int(20),
date varchar(20),
time text,
legnth varchar(20),
from_who varchar(20),
cid text,
cid_num int(20),
port_1 text,
to_whom text,
cid_name text,
cid_number int(20),
port_2 text,
pin text,
digits text,
tc int(20));



mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE 'export.csv' INTO TABLE sale_team_weekly_phone_call_time_w15_29_stg FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl


select distinct from_who from sale_team_weekly_phone_call_time_w15_29_stg;

select distinct cid_name from sale_team_weekly_phone_call_time_w15_29_stg;

drop table sale_team_weekly_phone_call_time_w15_29_cln;
Create table sale_team_weekly_phone_call_time_w15_29_cln as 
	select 
	ID,date,legnth,from_who,to_whom,cid_name
	from 
	sale_team_weekly_phone_call_time_w15_29_stg
	where
	from_who = "SALES1 INTERN1" or from_who = "JEREMY - LUBIN" or from_who = "WILLIAM - QUAINTANCE"
	or 
	(cid_name ="JEREMY LUBIN" or cid_name = "WILLIAM - QUAINTANCE" 
	or cid_name = "SALES1 INTERN1" 
	or to_whom = "SALES1 INTERN1" or to_whom = "JEREMY - LUBIN" or to_whom  = "CA [JEREMY]" 
	or to_whom ="CA [WILLIAM]" or to_whom = "WILLIAM - QUAINTANCE" or to_whom = "CA [SALES1]");

alter table sale_team_weekly_phone_call_time_w15_29_cln add owner varchar(20);

update sale_team_weekly_phone_call_time_w15_29_cln 
	set 
	owner  = case 
	when from_who = "SALES1 INTERN1" or cid_name = "SALES1 INTERN1" or to_whom = "SALES1 INTERN1" 
	or to_whom =  "CA [SALES1]" then "Rob"
	when from_who = "JEREMY - LUBIN" or cid_name = "JEREMY - LUBIN" or cid_name="JEREMY LUBIN" 
	or to_whom = "JEREMY - LUBIN" or to_whom  = "CA [JEREMY]" then "Jeremy"
	when from_who = "WILLIAM - QUAINTANCE" or cid_name = "WILLIAM - QUAINTANCE" 
	or to_whom ="CA [WILLIAM]" or to_whom = "WILLIAM - QUAINTANCE" then "Bill"
	else "Wrong"
	end;

UPDATE sale_team_weekly_phone_call_time_w15_29_cln
SET date = STR_TO_DATE(date, '%m/%d/%Y');

alter table sale_team_weekly_phone_call_time_w15_29_cln add length_sec varchar(20);

update sale_team_weekly_phone_call_time_w15_29_cln 
set 
length_sec = time_to_sec(legnth);


alter table sale_team_weekly_phone_call_time_w15_29_cln add index rw (date);

alter table sale_team_weekly_phone_call_time_w15_29_cln add length_hour varchar(20);

update sale_team_weekly_phone_call_time_w15_29_cln 
set 
length_hour = time_format(SEC_TO_TIME(length_sec),'%Hh %im');




create table sale_team_weekly_phone_call_time_banchmark 
	(
		caller varchar(20),
		time varchar(20)

		);


drop table sale_team_weekly_phone_call_time_report_w15_29;

create table sale_team_weekly_phone_call_time_report_w15_29 as 
	select 
	a.owner as "Caller",
	b.week_number,
  SEC_TO_TIME(sum(a.length_sec
    )) as "total_call_sec",
    
    count(
    a.ID) as "number of calls",

    count(distinct a.date) as "number_day_worked",

     SEC_TO_TIME((sum(a.length_sec
    ))/c.days) as "ave_time_day",

     SEC_TO_TIME(c.time) as banch_mark,

    concat(((sum(a.length_sec)/c.days)/c.time-1)*100,"%") as "variance"

   from sale_team_weekly_phone_call_time_w15_29_cln a 
   left join date_and_week_num b 
   on a.date = b.date
   left join sale_team_weekly_phone_call_time_banchmark c
   on a.owner = c.caller
   group by a.owner,b.week_number;

select * from sale_team_weekly_phone_call_time_w15_29_cln where owner = "Rob";

#### call result 

create table sale_team_call_result_w15_28_stg(
name varchar(20),
date_1 varchar(20),
caller_1 varchar(30),
date_2 varchar(20),
caller_2 varchar(20),
out_come varchar(20)
);

	update sale_team_call_result_w15_28_stg 
		set caller_1  = case 
		when 
		caller_1  = "Bill Quaintance" then "Bill"
		when 
		caller_1  = "Rob Cooney" then "Rob"
		when 
		caller_1  = "Jeremy Lubin" then "Jeremy"
		when 
		caller_1 =" " then " "
		end;

drop table sale_team_performance_call_follow_up_w15_29;


create table sale_team_performance_call_follow_up_w15_29 as 
	select 
	"W15.28" as week_number,caller_1,
	sum(
		case 
		when (date_1 <> " " and date_2 <> " ") or out_come <> " " 
		then 1 else 0 
		end) as  full_address,
	sum(
		case
		when 
		(date_1 <> " " or date_2 <> " ") and out_come = " " 
		then 1
		else 0
		end
		) as  partly_address,
	sum(
		case 
		when 
		(date_1 = " " and date_2 = " ") and out_come = " "
		then 1
		else 0
		end
		) as non_address
	from sale_team_call_result_w15_28_stg
	where caller_1 = "Bill" or caller_1 = "Jeremy" or caller_1 = "Rob"
	group by caller_1;


## auto dialing call result 

create table sale_team_performance_auto_stg_w15_28 as 
	select 
	* 
	from auto_daily_check_w15_28_01_result

	union all 
	select 
		* 
	from auto_daily_check_w15_28_02_result
	union all 
	select 
	* 
	from auto_daily_check_w15_28_03_result

	union all 
	select 
	* 
	from auto_daily_check_w15_28_04_result

	union all 
	select 
	* 
	from auto_daily_check_w15_28_05_result;


drop table sale_team_performance_auto_stg_w15_28;




select distinct result from sale_team_performance_auto_stg_w15_28;

select distinct day,  caller from sale_team_performance_auto_stg_w15_28 group by caller, day;

select count(id),id ,  caller from sale_team_performance_auto_stg_w15_28 group by id;

drop table sale_team_performance_auto_full_add_w15_28;


create table sale_team_performance_auto_full_add_w15_28 as 
	select
	a.caller,
	a.id,
	a.result as result1,
	b.result as result2,
	c.result as result3,
	null as result4,
	null as result5 
	from auto_daily_check_w15_28_02_result a 
	left join auto_daily_check_w15_28_03_result b 
	on a.id =b.id
	left join auto_daily_check_w15_28_04_result c 
	on a.id =c.id
	where a.caller = "Bill"
	group by id

	union all 
	select
	a.caller,
	a.id,
	a.result as result1,
	b.result as result2,
	c.result as result3,
	d.result as result4,
	e.result as result5 
	from auto_daily_check_w15_28_01_result a 
	left join auto_daily_check_w15_28_02_result b 
	on a.id =b.id
	left join auto_daily_check_w15_28_03_result c 
	on a.id =c.id 
	left join auto_daily_check_w15_28_04_result d
	on a.id =d.id 
	left join auto_daily_check_w15_28_05_result e
	on a.id =e.id 
	where a.caller ="Jeremy"
	group by id

	union all 

	select
	a.caller,
	a.id,
	a.result as result1,
	b.result as result2,
	null as result3,
	null as result4,
	null as result5
	from auto_daily_check_w15_28_02_result a 
	left join auto_daily_check_w15_28_04_result b 
	on a.id =b.id
	where a.caller= "Rob"
	group by id ;

drop table list_for_eric;
create table list_for_eric as 
	select 
	*,
	"27" AS result5
	from sale_team_performance_auto_full_add
	where 
	(result1 = " " AND result2 = " " AND  result3 = " ") 
	or 
	(result1 = " " AND result2 = " " AND  result3 = " " AND result4=" ")
	Union all 
	select 
	* 
	from 
	weekly_auto_dial_result_table_full_add_w15_28
	where 
	(result1 = " " AND result2 = " " AND  result3 = " " AND (caller = "Bill" or caller = "Rob"))
	or 
	(result1 = " " AND result2 = " " AND caller  = "Li")
	or 
	(result1 = " " AND result2 = " " AND  result3 = " " And result4 = " " AND result5 = " " 
		and caller  = "Jeremy"); 

update sale_team_performance_auto_full_add_w15_28
	set 
	result1 = " "
	where result1 is null;


update sale_team_performance_auto_full_add_w15_28
	set 
	result2 = " "
	where result2 is null;

update sale_team_performance_auto_full_add_w15_28
	set 
	result3 = " "
	where result3 is null;

update sale_team_performance_auto_full_add_w15_28
	set 
	result4 = " "
	where result4 is null;

drop table sale_team_performance_auto;

select distinct result1,count(result1) from sale_team_performance_auto_full_add_w15_28 group by result1;

select distinct result,count(result) from sale_team_performance_auto_stg_w15_28 group by result;

update sale_team_performance_auto_full_add_w15_28
	set 
	result1 = "no_count"
	where result1 = "CANCEL" OR result1 ="DO NOT CALL" or result1 ="INTERESTED - FOLLOW UP" or result1 ="INTERESTED - OPTY"
	or result1 ="It&#039;s a BAD NUMBER" or result1 ="Its a BAD NUMBER" or result1 ="Just Hangup" or 
	result1 ="NOT INTERESTED"
	or result1 ="WRONG NUMBER" or result1 ="WRONG PERSON";


update sale_team_performance_auto_full_add_w15_28
	set 
	result2 = "no_count"
	where result2 = "CANCEL" OR result2 ="DO NOT CALL" or result2 ="INTERESTED - FOLLOW UP" or result2 ="INTERESTED - OPTY"
	or result2 ="It&#039;s a BAD NUMBER" or result2 ="Its a BAD NUMBER" or result2 ="Just Hangup" or 
	result2 ="NOT INTERESTED"
	or result2 ="WRONG NUMBER" or result2 ="WRONG PERSON";

update sale_team_performance_auto_full_add_w15_28
	set 
result3 = "no_count"
	where result3 = "CANCEL" OR result3 ="DO NOT CALL" or result3 ="INTERESTED - FOLLOW UP" or result3 ="INTERESTED - OPTY"
	or result3 ="It&#039;s a BAD NUMBER" or result3 ="Its a BAD NUMBER" or result3 ="Just Hangup" or 
	result3 ="NOT INTERESTED"
	or result3 ="WRONG NUMBER" or result3 ="WRONG PERSON";

update sale_team_performance_auto_full_add_w15_28
	set
result4 = "no_count"
	where result4 = "CANCEL" OR result4 ="DO NOT CALL" or result4 ="INTERESTED - FOLLOW UP" or result4 ="INTERESTED - OPTY"
	or result4 ="It&#039;s a BAD NUMBER" or result4 ="Its a BAD NUMBER" or result4 ="Just Hangup" or 
	result4 ="NOT INTERESTED"
	or result4 ="WRONG NUMBER" or result4 ="WRONG PERSON";


drop table sale_team_performance_auto;
create table sale_team_performance_auto_w15_28 as 
	select 
	caller,
	count(distinct id) as total_request,
	sum(case 
		when (result1 <> " " and result2 <> " " and result3 <> " ") or 
		(result1 = "no_count" or result2 ="no_count" or result3 ="no_count")
		then 1
		else 0
		end) as full_address,
	sum(case 
		when (result1 = " " or  result2 = " " or result3 = " ")
		and (not(result1 = " " AND result2 = " " AND  result3 = " " )
			and not(result1 = "no_count" or result2 ="no_count" or result3 ="no_count"))
		then 1
		else 0
		end) as partly_address,
	sum(case 
		when (result1 = " " AND result2 = " " AND  result3 = " " )
		then 1
		else 0
		end) as non_address
	from 
	sale_team_performance_auto_full_add_w15_28
	where 
	caller = "Bill"

union all  
	select
	caller,
	count(distinct id) as total_request,
	0 as full_address,
	sum(case 
		when not(result1 = " " AND result2 = " " ) or 
		(result1 = "no_count" and result2 ="no_count")
		then 1
		else 0
		end) as partly_address,
	sum(case 
		when (result1 = " " AND result2 = " ")
		then 1
		else 0
		end) as non_address
	from 
	sale_team_performance_auto_full_add_w15_28
	where 
	caller = "Rob"

union all 
select 
caller,
	count(distinct id) as total_request,
	sum(case 
		when (result1 <> " " and result2 <> " " and result3 <> " " and result3 <> " ")
		or 
		(result1 = "no_count" or result2 ="no_count" or result3 ="no_count")
		then 1
		else 0
		end) as full_address,
	sum(case 
		when (result1 = " " or  result2 = " " or result3 = " ")
		and (not(result1 = " " AND result2 = " " AND  result3 = " " )
			and not(result1 = "no_count" or result2 ="no_count" or result3 ="no_count"))
		then 1
		else 0
		end) as partly_address,
	sum(case 
		when (result1 = " " AND result2 = " " AND  result3 = " " )
		then 1
		else 0
		end) as non_address
	from 
	sale_team_performance_auto_full_add_w15_28
	where 
	caller = "Jeremy";

select count(distinct Contact_id) from ifs_whole_contact_cln_150803 where phone <> " ";

============================================================
Auto dialing weekly result table 
=========================================================

create table auto_dial_weekly_result_stg_w15_28 as 
	select 
	* 
	from auto_daily_check_w15_28_01_result

	union all 
	select 
		* 
	from auto_daily_check_w15_28_02_result
	union all 
	select 
	* 
	from auto_daily_check_w15_28_03_result

	union all 
	select 
	* 
	from auto_daily_check_w15_28_04_result

	union all 
	select 
	* 
	from auto_daily_check_w15_28_05_result;


drop table sale_team_performance_auto_stg_w15_28;




select distinct result from sale_team_performance_auto_stg_w15_28;

select distinct day,  caller from sale_team_performance_auto_stg_w15_28 group by caller, day;

select count(id),id ,  caller from sale_team_performance_auto_stg_w15_28 group by id;

drop table weekly_auto_dial_result_table_full_add_w15_28;


create table weekly_auto_dial_result_table_full_add_w15_28 as 
	select
	a.caller,
	a.id,
	a.result as result1,
	b.result as result2,
	c.result as result3,
	null as result4,
	null as result5 
	from auto_daily_check_w15_28_02_result a 
	left join auto_daily_check_w15_28_03_result b 
	on a.id =b.id
	left join auto_daily_check_w15_28_04_result c 
	on a.id =c.id
	where a.caller = "Bill"
	group by id

	union all 
	select
	a.caller,
	a.id,
	a.result as result1,
	b.result as result2,
	c.result as result3,
	d.result as result4,
	e.result as result5 
	from auto_daily_check_w15_28_01_result a 
	left join auto_daily_check_w15_28_02_result b 
	on a.id =b.id
	left join auto_daily_check_w15_28_03_result c 
	on a.id =c.id 
	left join auto_daily_check_w15_28_04_result d
	on a.id =d.id 
	left join auto_daily_check_w15_28_05_result e
	on a.id =e.id 
	where a.caller ="Jeremy"
	group by id

	union all 

	select
	a.caller,
	a.id,
	a.result as result1,
	b.result as result2,
	c.result as result3,
	null as result4,
	null as result5
	from auto_daily_check_w15_28_01_result a 
	left join auto_daily_check_w15_28_03_result b 
	on a.id =b.id
	left join auto_daily_check_w15_28_05_result c 
	on a.id =c.id
	where a.caller= "Rob"
	group by id 

	Union all 
	select
	a.caller,
	a.id,
	a.result as result1,
	b.result as result2,
	null as result3,
	null as result4,
	null as result5
	from auto_daily_check_w15_28_02_result a 
	left join auto_daily_check_w15_28_04_result b 
	on a.id =b.id
	where a.caller= "Li"
	group by id ;

update weekly_auto_dial_result_table_full_add_w15_28
	set 
	result1 = " "
	where result1 is null;


update weekly_auto_dial_result_table_full_add_w15_28
	set 
	result2 = " "
	where result2 is null;

update weekly_auto_dial_result_table_full_add_w15_28
	set 
	result3 = " "
	where result3 is null;

update weekly_auto_dial_result_table_full_add_w15_28
	set 
	result4 = " "
	where result4 is null;

update weekly_auto_dial_result_table_full_add_w15_28
	set 
	result5 = " "
	where result5 is null;

drop table sale_team_performance_auto;

select distinct result1,count(result1) from weekly_auto_dial_result_table_full_add_w15_28 group by result1;

select distinct result,count(result) from sale_team_performance_auto_stg_w15_28 group by result;

update weekly_auto_dial_result_table_full_add_w15_28
	set 
	result1 = "no_count"
	where result1 = "CANCEL" OR result1 ="DO NOT CALL" or result1 ="INTERESTED - FOLLOW UP" or result1 ="INTERESTED - OPTY"
	or result1 ="It&#039;s a BAD NUMBER" or result1 ="Its a BAD NUMBER" or result1 ="Just Hangup" or 
	result1 ="NOT INTERESTED"
	or result1 ="WRONG NUMBER" or result1 ="WRONG PERSON";


update weekly_auto_dial_result_table_full_add_w15_28
	set 
	result2 = "no_count"
	where result2 = "CANCEL" OR result2 ="DO NOT CALL" or result2 ="INTERESTED - FOLLOW UP" or result2 ="INTERESTED - OPTY"
	or result2 ="It&#039;s a BAD NUMBER" or result2 ="Its a BAD NUMBER" or result2 ="Just Hangup" or 
	result2 ="NOT INTERESTED"
	or result2 ="WRONG NUMBER" or result2 ="WRONG PERSON";

update weekly_auto_dial_result_table_full_add_w15_28
	set 
result3 = "no_count"
	where result3 = "CANCEL" OR result3 ="DO NOT CALL" or result3 ="INTERESTED - FOLLOW UP" or result3 ="INTERESTED - OPTY"
	or result3 ="It&#039;s a BAD NUMBER" or result3 ="Its a BAD NUMBER" or result3 ="Just Hangup" or 
	result3 ="NOT INTERESTED"
	or result3 ="WRONG NUMBER" or result3 ="WRONG PERSON";

update weekly_auto_dial_result_table_full_add_w15_28
	set
result4 = "no_count"
	where result4 = "CANCEL" OR result4 ="DO NOT CALL" or result4 ="INTERESTED - FOLLOW UP" or result4 ="INTERESTED - OPTY"
	or result4 ="It&#039;s a BAD NUMBER" or result4 ="Its a BAD NUMBER" or result4 ="Just Hangup" or 
	result4 ="NOT INTERESTED"
	or result4 ="WRONG NUMBER" or result4 ="WRONG PERSON";

update weekly_auto_dial_result_table_full_add_w15_28
	set
result5 = "no_count"
	where result5 = "CANCEL" OR result5 ="DO NOT CALL" or result5 ="INTERESTED - FOLLOW UP" or result5 ="INTERESTED - OPTY"
	or result5 ="It&#039;s a BAD NUMBER" or result5 ="Its a BAD NUMBER" or result5 ="Just Hangup" or 
	result5 ="NOT INTERESTED"
	or result5 ="WRONG NUMBER" or result5 ="WRONG PERSON";


drop table weekly_auto_dial_result_w15_28;
create table weekly_auto_dial_result_w15_28 as 
	select 
	caller,
	count(distinct id) as total_request,
	sum(case 
		when (result1 <> " " and result2 <> " " and result3 <> " ") or 
		(result1 = "no_count" or result2 ="no_count" or result3 ="no_count")
		then 1
		else 0
		end) as full_address,
	sum(case 
		when (result1 = " " or  result2 = " " or result3 = " ")
		and (not(result1 = " " AND result2 = " " AND  result3 = " " )
			and not(result1 = "no_count" or result2 ="no_count" or result3 ="no_count"))
		then 1
		else 0
		end) as partly_address,
	sum(case 
		when (result1 = " " AND result2 = " " AND  result3 = " " )
		then 1
		else 0
		end) as non_address
	from 
	weekly_auto_dial_result_table_full_add_w15_28
	where 
	caller = "Bill"

union all  
	select
	caller,
	count(distinct id) as total_request,
	sum(case 
		when (result1 <> " " and result2 <> " " and result3 <> " ") or 
		(result1 = "no_count" or result2 ="no_count" or result3 ="no_count")
		then 1
		else 0
		end) as full_address,
	sum(case 
		when (result1 = " " or  result2 = " " or result3 = " ")
		and (not(result1 = " " AND result2 = " " AND  result3 = " " )
		and not(result1 = "no_count" or result2 ="no_count" or result3 ="no_count"))
		then 1
		else 0
		end) as partly_address,
	sum(case 
		when (result1 = " " AND result2 = " " AND result3 = " ")
		then 1
		else 0
		end) as non_address
	from 
	weekly_auto_dial_result_table_full_add_w15_28
	where 
	caller = "Rob"

union all 
select 
caller,
	count(distinct id) as total_request,
	sum(case 
		when (result1 <> " " and result2 <> " " and result3 <> " ")
		or (result3 <> " " and result4 <> " " and result5 <> " ")
		or (result2 <> " " and result3 <> " " and result5 <> " ")
		or 
		(result1 = "no_count" or result2 ="no_count" or result3 ="no_count" or result5 ="no_count"
			or result5 ="no_count")
		then 1
		else 0
		end) as full_address,
	sum(case 
		when (result1 = " " or  result2 = " " or result3 = " ")
		and (not(result1 = " " AND result2 = " " AND  result3 = " " )
			and not(result1 = "no_count" or result2 ="no_count" or result3 ="no_count"
				or result4 ="no_count"
				or result5 ="no_count"))
		then 1
		else 0
		end) as partly_address,
	sum(case 
		when (result1 = " " AND result2 = " " AND  result3 = " " AND result4 = " " AND  result5 = " " )
		then 1
		else 0
		end) as non_address
	from 
	weekly_auto_dial_result_table_full_add_w15_28
	where 
	caller = "Jeremy"
	union all 

	select 
	caller,
	count(distinct id) as total_request,
    sum(case 
		when (result1 <> " " and result2 <> " ") or 
		(result1 = "no_count" or result2 ="no_count")
		then 1
		else 0
		end) as full_address,
	sum(case 
		when (result1 = " " or  result2 = " ")
		and (not(result1 = " " AND result2 = " ")
			and not(result1 = "no_count" or result2 ="no_count"))
		then 1
		else 0
		end) as partly_address,
	sum(case 
		when (result1 = " " AND result2 = " ")
		then 1
		else 0
		end) as non_address
	from 
	weekly_auto_dial_result_table_full_add_w15_28
	where 
	caller = "Li";

================
Number of phone numebrs of responders and all contact
================


select count(distinct Contact_id) from ifs_whole_contact_cln_150803 where phone <> " ";

select distinct phone from ifs_whole_contact_cln_150803;

select count(contact_id) from ifs_whole_contact_cln_150803;

select count(distinct contact_id) from phone_leads_w15_30_stg_2 where phone <> " ";

select count(distinct contact_id) from phone_leads_w15_30_stg_2;


=======


create table ifs_all_info (
id int(20),
email varchar(20));

mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE '1111.csv' INTO TABLE ifs_all_info FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl


create table taf_all_user (
email varchar(20),
sky int(20));
mysql -h lswarehouse.c4v4smk6kele.us-west-1.rds.amazonaws.com -P 3306 --user=mroot --password='lovesystems1640' --execute="LOAD DATA LOCAL INFILE '2222.csv' INTO TABLE taf_all_user FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES; SHOW WARNINGS" dbl


ALTER TABLE ifs_all_info ADD INDEX n1 (email);
ALTER TABLE taf_all_user ADD INDEX n1 (email);

drop table count;
create table count as 
  select 
  a.id,a.email as "ifs-email",b.email as "Mail-taf"
  from ifs_all_info a 
  inner join 
  taf_all_user b
  on 
  a.email = b.email;


insert into itvpmp.tb_ps_households(id_country,ts,variable,value) select '2',DATE_FORMAT(NOW(),'%Y-%m-%d:00:00:00'),optin, count(*) from itvrawdata.ps_households_pl group by optin;
update itvpmp.tb_ps_households set variable = 'HH CURRENTLY OptOut' where variable = 'false' and id_country = 2;
update itvpmp.tb_ps_households set variable = 'HH CURRENTLY OptIn' where variable = 'true' and id_country = 2;
insert into itvpmp.tb_ps_households(id_country,ts,variable,value) select '2',DATE_FORMAT(NOW(),'%Y-%m-%d:00:00:00'),'total', count(*) from itvrawdata.ps_households_pl;
update itvpmp.tb_ps_households set variable = 'TOTAL NUM OF HHs' where variable = 'total' and id_country = 2;


insert into itvpmp.tb_ps_households(id_country,ts,variable,value) select '9',DATE_FORMAT(NOW(),'%Y-%m-%d:00:00:00'),optin, count(*) from itvrawdata.ps_households_cz group by optin;
update itvpmp.tb_ps_households set variable = 'HH CURRENTLY OptOut' where variable = 'false' and id_country = 9;
update itvpmp.tb_ps_households set variable = 'HH CURRENTLY OptIn' where variable = 'true' and id_country = 9;
insert into itvpmp.tb_ps_households(id_country,ts,variable,value) select '9',DATE_FORMAT(NOW(),'%Y-%m-%d:00:00:00'),'total', count(*) from itvrawdata.ps_households_cz;
update itvpmp.tb_ps_households set variable = 'TOTAL NUM OF HHs' where variable = 'total' and id_country = 9;

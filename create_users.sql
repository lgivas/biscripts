create user 'itvpmp'@'localhost' identified by 'xxxxxx';
grant all on itvpmp.* to 'itvpmp'@'localhost';
grant all on itvpmp.* to 'itvrawdata'@'localhost';
grant all on itvrawdata.* to 'itvpmp'@'localhost';
grant SUPER, SELECT, EXECUTE on *.* to 'itvpmp'@'localhost';
grant file on *.* to 'itvpmp'@'localhost';
create user 'itvpmp'@'%' identified by 'xxxx';
grant all on itvpmp.* to 'itvpmp'@'%';
grant SUPER, SELECT, EXECUTE on *.* to 'itvpmp'@'%';
flush privilges

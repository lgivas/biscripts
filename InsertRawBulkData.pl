###############################################################################################
# Name: InsertRawBulkData.pl
# Version: 1.1
# Author: Maximo F. Alves
# Purpose: inserts large raw data amounts 
# Description: 
# - read config file(abort if not found or not consistent)   
# - for each line list files on related directory
# - for each file found, extract time stamp from file name and use it together with Root table name to create new table
# - for each file after creating the table parse the file contents  and inset into db table
# - before parsing starts uploads look up tables into memory
# - if necessary updates look up table (first in db and them in memory)
#
#
# Raw data file name: typename.timestamp.csv
# Config file name: InsertRawBulkData.cfg
# - each line holds one table type
# - line format:Root table name;path to raw files 
# 
# LATEST IMPROVEMENTS:
# July 2014: VLM insert by Simon
# July 2014: RENG threads by Carlos 
# 31 Aug 2015 : CMDC - traxis/TWC/Reng number of requests by Mehdi 
# 25 Sep 2015 : tb_sgw_requests - added new column "method" - Mehdi
# 28 Sep 2015 : added peakhour19-23 agg for AMS and PS - Mehdi
# 30 Sep 2015 : added peakhour 19-23 for VLM and sgw and per day agg for ps, sgw, ams and vlm - Mehdi
###############################################################################################

use DBI;
use Time::Local;
use strict;
use lib "/opt/itvpmp/bin";
use PMP;

######################################################
#                    Global variables                # 
######################################################

my ($outbuffer, $logbuffer, %systems);
my ($sql, $sth, @row);
my $DEL  = 0;
my $VERBOSE = 0;
my $RM = '/bin/rm -f ';
my $UNZIP = '/bin/gunzip ';
my $configfile = "/opt/itvpmp/bin/InsertRawBulkData.cfg";
my $RAWDATARETENTION = 5; #keeps raw data table for n-1 days
my (%rawfile, %newtables);

######################################################
#                    Main Routine                    # 
######################################################
&parse_command_line();
&read_config;

PMP->enable_logging("InsertBulkRawData");
$logger->debug_message("START");
PMP->connect("itvrawdata");

foreach my $table (keys %rawfile){
	chomp( $rawfile{$table});
	opendir(DIR, $rawfile{$table}) or die "ERROR: Could not open $rawfile{$table} $!";
	$logger->debug_message("STARTING FILE INGEST LOOP for $rawfile{$table}");
	my ($aux, $resp, $finaltablename, $sql, $id_country, $country_code);
	while (my $file = readdir(DIR)){
		next if(!(($file=~/^\d{8}/) || ($file=~/^\d{4}-\d{2}-\d{2}-/)) );		
		$logger->debug_message("insert file: $file");
		$aux = $UNZIP . $rawfile{$table} . "/" . $file;
		$resp = `$aux`; 		
		$file =~ s/\.gz//;			
		($id_country, $country_code) = &get_country_info($rawfile{$table});
		$finaltablename = &prepare_table($table,$file,$country_code);

		&parse_and_insert($rawfile{$table},$file,$table,$finaltablename, $id_country);
		$aux = $RM . $rawfile{$table} . "/" . $file;
		$resp = `$aux` if(!$NOSQLACTION); 			
	}
	$logger->debug_message("FINISHED FILE INGEST LOOP for $rawfile{$table}");	
	
	$logger->debug_message("STARTING TABLE MAINTEANANCE LOOP $rawfile{$table}");
	foreach my $tablename (keys %newtables){
		&execute_mainteananca_task($table,$tablename,$id_country);
	}
	$logger->debug_message("FINISHED TABLE MAINTEANANCE LOOP $rawfile{$table}");	
	#Clean %newtables hash
	%newtables = ();
}
$logger->debug_message("Drop old tables");
foreach my $table (keys %rawfile){
		&drop_old_raw_tables($table) if(($table=~/cmdc/)||($table=~/reng/)||($table=~/tmsondem/) ||($table=~/ams/) ||($table=~/mdsstbregist/)||($table=~/wsp/)||($table=~/^psrequest/)||($table=~/vlm/)||($table=~/sgw/)) ;
}

		
######################################################
#                   SUB ROUTINES                     # 
######################################################s

sub get_country_info{
	my ($table) = @_;
	#/logs/NL/HRZ/RENG
	my ($id_country, $country_code, $sql, @row);
	$table =~ /\/logs\/(\w{2})\/[a-zA-Z]+/;
	$country_code = $1;
	$sql = "select id_country from itvpmp.tb_country where name = '$country_code'";
	$sth = PMP->query_data($sql);
	while ((@row) = $sth->fetchrow_array) {		
		$id_country = $row[0];
	}
	return ($id_country, $country_code);
}
sub execute_mainteananca_task {
	my ($table, $tablename, $id_country) = @_;
	my ($sql);

	
	if($table=~/cmdc/){
		#$logger->debug_message("... remove control_bit 0");
		#$sql = "delete from $tablename where control_bit = 0";
		#$sth = PMP->query_data($sql);
		$logger->debug_message("... Insert data into agregated table tb_cmdc_requests");
		$sql = 'insert into itvpmp.tb_cmdc_requests (id_country,ts,req_method,req_count, avg_cmdc,avg_TWC,avg_RENG,avg_Traxis,http_OKPerc,http_404Perc,http_500Perc,reng_client_type,cmdc_node, twc_count, reng_count, traxis_count)
                select ' . $id_country . ', date_format(t.ts,"%Y-%m-%d %H:%i:00") as datets,
                t.cmdc_api as API_method,
                count(t.cmdc_api) as Total_request,
                avg(t.cmdc_resp_time) as avg_cmdc,
                avg(t.twc_resp_time) as avg_twc,
                avg(t.reng_resp_time) as avg_reng,
                avg(t.traxis_resp_time) as avg_traxis,
                (SUM(IF(t.http_resp_code=200 || t.http_resp_code=204,1,0)) / count(t.cmdc_api)*100) as httpOKPercentage,
                (SUM(IF(t.http_resp_code=404,1,0)) / count(t.cmdc_api)*100) as http404Percentage,
                (SUM(IF(t.http_resp_code=500,1,0)) / count(t.cmdc_api)*100) as http500Percentage,
                t.client_type as client_type,
                cmdc_node, SUM(if(t.twc_resp_time is not null,1,0)),SUM(if(t.reng_resp_time is not null,1,0)),SUM(if(t.traxis_resp_time is not null,1,0))' . " from $tablename t group by hour(t.ts),minute(t.ts), API_method, client_type, cmdc_node";  
		$sth = PMP->query_data($sql);
		
		#Below is inserting aggregated response times over 24 hours.
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg ( 
		`id_country`, `req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. ' ,CAST(date(t.ts) as DATETIME) as timedate, "per day" as type, "cmdc" as component, t.cmdc_api, t.cmdc_node,count(t.id) as total_req, sum(if(t.cmdc_resp_time <500,1,0))as lt500, sum(if(t.cmdc_resp_time>= 500 && t.cmdc_resp_time <1000,1,0)) as b500t1000,
		sum(if(t.cmdc_resp_time>= 1000 && t.cmdc_resp_time <2000,1,0)) as b1000t2000, sum(if(t.cmdc_resp_time>= 2000 && t.cmdc_resp_time <3000,1,0)) as b2000t3000,
		sum(if(t.cmdc_resp_time>= 3000 && t.cmdc_resp_time <4000,1,0)) as b3000t4000,sum(if(t.cmdc_resp_time>= 4000 && t.cmdc_resp_time <10000,1,0)) as b4000t10000,
		sum(if(t.cmdc_resp_time>= 10000,1,0)) as gt10000
		' . "from itvrawdata.$tablename t group by date(t.ts), t.cmdc_api, t.cmdc_node";
		$sth = PMP->query_data($sql);

		#Below is inserting aggregated response times in peak times (19 - 23 hour)
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg ( 
		`id_country`,`req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. ' ,CAST(date(t.ts) as DATETIME) as timedate, "peakhour19-23" as type, "cmdc" as component, t.cmdc_api, t.cmdc_node,count(t.id) as total_req, 
		sum(if(t.cmdc_resp_time <500,1,0))as lt500, sum(if(t.cmdc_resp_time>= 500 && t.cmdc_resp_time <1000,1,0)) as b500t1000,
		sum(if(t.cmdc_resp_time>= 1000 && t.cmdc_resp_time <2000,1,0)) as b1000t2000, sum(if(t.cmdc_resp_time>= 2000 && t.cmdc_resp_time <3000,1,0)) as b2000t3000,
		sum(if(t.cmdc_resp_time>= 3000 && t.cmdc_resp_time <4000,1,0)) as b3000t4000,sum(if(t.cmdc_resp_time>= 4000 && t.cmdc_resp_time <10000,1,0)) as b4000t10000,
		sum(if(t.cmdc_resp_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		where hour(t.ts) >= 17
		and hour(t.ts) < 21
		group by date(t.ts), t.cmdc_api, t.cmdc_node";
		$sth = PMP->query_data($sql);

		#Below is inserting the top5 based on numbers of requests
		(my $tbdbdate = $tablename) =~ s/cmdc_\w{2}_(\d\d\d\d)(\d\d)(\d\d)/$1-$2-$3/;	
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg(`id_country`, `req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. ' ,CAST(concat(date(t1.ts) ," ", sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)))as DATETIME) as timedate, "top5req" as type,"cmdc" as component, t1.cmdc_api, t1.cmdc_node,count(t1.id) as countReq,
		sum(if(t1.cmdc_resp_time <500,1,0))as lt500, sum(if(t1.cmdc_resp_time>= 500 && t1.cmdc_resp_time <1000,1,0)) as b500t1000,
		sum(if(t1.cmdc_resp_time>= 1000 && t1.cmdc_resp_time <2000,1,0)) as b1000t2000, sum(if(t1.cmdc_resp_time>= 2000 && t1.cmdc_resp_time <3000,1,0)) as b2000t3000,
		sum(if(t1.cmdc_resp_time>= 3000 && t1.cmdc_resp_time <4000,1,0)) as b3000t4000,sum(if(t1.cmdc_resp_time>= 4000 && t1.cmdc_resp_time <10000,1,0)) as b4000t10000,
		sum(if(t1.cmdc_resp_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename" . ' t1
		join (select time(t.ts) as reqtime
		from itvpmp.tb_cmdc_requests t 
		where date(t.ts) = "' . "$tbdbdate". '"
		group by date(t.ts), time(t.ts)
		order by sum(t.req_count) DESC
		LIMIT 5) as t2
		on (sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)) = t2.reqtime)
		group by sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)), t1.cmdc_api, t1.cmdc_node';
		$sth = PMP->query_data($sql);

		#Below is inserting the top5 based on request times
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg ( 
		`id_country`, `req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. ' ,CAST(concat(date(t1.ts) ," ", sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)))as DATETIME) as timedate, "top5resp" as type,"cmdc" as component, 
		t1.cmdc_api, t1.cmdc_node,count(t1.id) as countReq,
		sum(if(t1.cmdc_resp_time <500,1,0))as lt500, sum(if(t1.cmdc_resp_time>= 500 && t1.cmdc_resp_time <1000,1,0)) as b500t1000,
		sum(if(t1.cmdc_resp_time>= 1000 && t1.cmdc_resp_time <2000,1,0)) as b1000t2000, sum(if(t1.cmdc_resp_time>= 2000 && t1.cmdc_resp_time <3000,1,0)) as b2000t3000,
		sum(if(t1.cmdc_resp_time>= 3000 && t1.cmdc_resp_time <4000,1,0)) as b3000t4000,sum(if(t1.cmdc_resp_time>= 4000 && t1.cmdc_resp_time <10000,1,0)) as b4000t10000,
		sum(if(t1.cmdc_resp_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename" . ' t1
		join (select time(t.ts) as reqtime, sum(t.avg_cmdc* t.req_count)/sum(t.req_count), avg(t.avg_cmdc)
		from itvpmp.tb_cmdc_requests t 
		where date(t.ts) = "' . "$tbdbdate" . '"
		group by date(t.ts), time(t.ts)
		order by sum(t.avg_cmdc* t.req_count)/sum(t.req_count) DESC
		LIMIT 5) as t2
		on (sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)) = t2.reqtime)
		group by sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)), t1.cmdc_api, t1.cmdc_node';
		$sth = PMP->query_data($sql);
		
		#Below is inserting the top5 based on concurrent threads
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg ( 
		`id_country`, `req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. ' ,CAST(concat(date(t1.ts) ," ", sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)))as DATETIME) as timedate, "top5concurthread" as type,"cmdc" as component, t1.cmdc_api, t1.cmdc_node,count(t1.id) as countReq,
		sum(if(t1.cmdc_resp_time <500,1,0))as lt500, sum(if(t1.cmdc_resp_time>= 500 && t1.cmdc_resp_time <1000,1,0)) as b500t1000,
		sum(if(t1.cmdc_resp_time>= 1000 && t1.cmdc_resp_time <2000,1,0)) as b1000t2000, sum(if(t1.cmdc_resp_time>= 2000 && t1.cmdc_resp_time <3000,1,0)) as b2000t3000,
		sum(if(t1.cmdc_resp_time>= 3000 && t1.cmdc_resp_time <4000,1,0)) as b3000t4000,sum(if(t1.cmdc_resp_time>= 4000 && t1.cmdc_resp_time <10000,1,0)) as b4000t10000,
		sum(if(t1.cmdc_resp_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename" . ' t1
		join (select time(t.ts) as reqtime, sum(t.avg_cmdc* t.req_count)/sum(t.req_count), avg(t.avg_cmdc)
		from itvpmp.tb_cmdc_requests t
		where date(t.ts) = "' . "$tbdbdate" . '" 
		group by date(t.ts),time(t.ts)
		order by sum(t.avg_cmdc* t.req_count)/60000 DESC
		LIMIT 5) as t2
		on (sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)) = t2.reqtime)
		group by sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)), t1.cmdc_api, t1.cmdc_node';
		$sth = PMP->query_data($sql);
	}elsif($table=~/sgw_requests/){
		$logger->debug_message("... Insert data into agregated table tb_sgw_requests");
		$sql = 'insert into itvpmp.tb_sgw_requests (id_country, ts, component, method, node, total_count, avg_rt)
        select ' . $id_country . ', date_format(t.ts,"%Y-%m-%d %H:%i:00") as datets,
		if(t.component="acs" || t.component="ams" || t.component="cmdc" || t.component="mds" || t.component="ps" || t.component="tms" || t.component="vlm" || t.component="wsp", t.component, null) as component,
        if(t.component="acs" || t.component="ams" || t.component="cmdc" || t.component="mds" || t.component="ps" || t.component="tms" || t.component="vlm" || t.component="wsp", "Compo", t.component) as method,
		t.sgwNode, sum(t.request_count), avg(t.avg_rt)
        from itvrawdata.' . "$tablename" . ' t
        group by  hour(t.ts),minute(t.ts), t.component, t.sgwNode';
		$sth = PMP->query_data($sql);

		#Below is inserting the peak hour (19 - 23) aggregation for the reng. Split in response times range.
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`,`req_date`, `type`, `component`, `api`,`compo` , `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(date(t.ts) as DATETIME) as timedate, "peakhour19-23" as type,
		"sgw" as component,
        if(t.component="acs" || t.component="ams" || t.component="cmdc" || t.component="mds" || t.component="ps" || t.component="tms" || t.component="vlm" || t.component="wsp" || t.component="Compo", "Compo", t.component) as api,
        if(t.component="acs" || t.component="ams" || t.component="cmdc" || t.component="mds" || t.component="ps" || t.component="tms" || t.component="vlm" || t.component="wsp", t.component, null) as compo,
		t.sgwNode ,count(t.id) as total_req, 
		sum(if(t.avg_rt <500,1,0))as lt500, sum(if(t.avg_rt>= 500 && t.avg_rt <1000,1,0)) as b500t1000,
		sum(if(t.avg_rt>= 1000 && t.avg_rt <2000,1,0)) as b1000t2000, sum(if(t.avg_rt>= 2000 && t.avg_rt <3000,1,0)) as b2000t3000,
		sum(if(t.avg_rt>= 3000 && t.avg_rt <4000,1,0)) as b3000t4000,sum(if(t.avg_rt>= 4000 && t.avg_rt <10000,1,0)) as b4000t10000,
		sum(if(t.avg_rt>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		where hour(t.ts) >= 17
		and hour(t.ts) < 21
		group by date(t.ts), t.sgwNode";
		$sth = PMP->query_data($sql);
		
		
		#Below is inserting aggregated response times over 24 hours.
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`,`req_date`, `type`, `component`, `api`, `compo`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(date(t.ts) as DATETIME) as timedate, "per day" as type,
		"sgw" as component,
        if(t.component="acs" || t.component="ams" || t.component="cmdc" || t.component="mds" || t.component="ps" || t.component="tms" || t.component="vlm" || t.component="wsp" || t.component="Compo", "Compo", t.component) as api,
        if(t.component="acs" || t.component="ams" || t.component="cmdc" || t.component="mds" || t.component="ps" || t.component="tms" || t.component="vlm" || t.component="wsp", t.component, null) as compo,
		t.sgwNode ,count(t.id) as total_req, 
		sum(if(t.avg_rt <500,1,0))as lt500, sum(if(t.avg_rt>= 500 && t.avg_rt <1000,1,0)) as b500t1000,
		sum(if(t.avg_rt>= 1000 && t.avg_rt <2000,1,0)) as b1000t2000, sum(if(t.avg_rt>= 2000 && t.avg_rt <3000,1,0)) as b2000t3000,
		sum(if(t.avg_rt>= 3000 && t.avg_rt <4000,1,0)) as b3000t4000,sum(if(t.avg_rt>= 4000 && t.avg_rt <10000,1,0)) as b4000t10000,
		sum(if(t.avg_rt>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		group by date(t.ts), t.sgwNode";
		$sth = PMP->query_data($sql);	
		
		
	}elsif($table=~/sgw_errors/){
		$logger->debug_message("... Insert data into agregated table tb_sgw_requests");
		$sql = "insert into itvpmp.tb_sgw_errors (id_country, ts, node, category,message, total_count)
        select $id_country,  t.ts, t.sgwNode,
         t.category, t.message, count(1) as tt
        from $tablename t
        group by  hour(t.ts),minute(t.ts),t.sgwNode, t.category, t.message ";
		$sth = PMP->query_data($sql);	
		
			
	}elsif($table=~/reng_/){	
		$logger->debug_message("... Insert data into agregated table tb_reng_requests");
        $sql = 'insert into itvpmp.tb_reng_requests (id_country,ts,api_method,source_ip,http_method,http_response_code,client_type,reng_node,d4a_customer_flag,orion_customer_flag,total_request,resp_time,thread_id,subid) 
        select ' . $id_country . ',date_format(t.ts,"%Y-%m-%d %H:%i:00") as datets,
        api_method,
        source_ip,
        http_method,
        http_response_code,
        client_type,
        reng_node,
        d4a_customer_flag,
        orion_customer_flag,
        count(api_method) as total_request,
        avg(resp_time) as avg_resp_time, 		
        thread_id' . ",
        subid
        from $tablename t 
        group by hour(t.ts),minute(t.ts), api_method, source_ip, http_method, http_response_code, client_type,reng_node, d4a_customer_flag, orion_customer_flag";	
		$sth = PMP->query_data($sql);

		#Below is inserting the 24hour aggregation for the RENG. Split in response times range
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`, `req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. ' ,CAST(date(t.ts) as DATETIME) as timedate, "per day" as type, "reng" as component, t.api_method, t.reng_node,count(t.id) as total_req, 
		sum(if(t.resp_time <500,1,0))as lt500, sum(if(t.resp_time>= 500 && t.resp_time <1000,1,0)) as b500t1000,
		sum(if(t.resp_time>= 1000 && t.resp_time <2000,1,0)) as b1000t2000, sum(if(t.resp_time>= 2000 && t.resp_time <3000,1,0)) as b2000t3000,
		sum(if(t.resp_time>= 3000 && t.resp_time <4000,1,0)) as b3000t4000,sum(if(t.resp_time>= 4000 && t.resp_time <10000,1,0)) as b4000t10000,
		sum(if(t.resp_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename" . ' t
		group by date(t.ts), t.api_method, t.reng_node';
		$sth = PMP->query_data($sql);
		
		#Below is inserting the peak hour (19 - 23) aggregation for the reng. Split in response times range.
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`,`req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(date(t.ts) as DATETIME) as timedate, "peakhour19-23" as type,"reng" as component, t.api_method, t.reng_node ,count(t.id) as total_req, 
		sum(if(t.resp_time <500,1,0))as lt500, sum(if(t.resp_time>= 500 && t.resp_time <1000,1,0)) as b500t1000,
		sum(if(t.resp_time>= 1000 && t.resp_time <2000,1,0)) as b1000t2000, sum(if(t.resp_time>= 2000 && t.resp_time <3000,1,0)) as b2000t3000,
		sum(if(t.resp_time>= 3000 && t.resp_time <4000,1,0)) as b3000t4000,sum(if(t.resp_time>= 4000 && t.resp_time <10000,1,0)) as b4000t10000,
		sum(if(t.resp_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		where hour(t.ts) >= 17
		and hour(t.ts) < 21
		group by date(t.ts), t.api_method, t.reng_node";
		$sth = PMP->query_data($sql);
				
		#Below is inserting the top 5 based on request totals
		(my $tbdbdate = $tablename) =~ s/reng_\w{2}_(\d\d\d\d)(\d\d)(\d\d)/$1-$2-$3/;
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg ( 
		`id_country`,`req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(concat(date(t1.ts) ," ", sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)))as DATETIME) as timedate, "top5req" as type,"reng" as component, t1.api_method, t1.reng_node,count(t1.id) as countReq,
		sum(if(t1.resp_time <500,1,0))as lt500, sum(if(t1.resp_time>= 500 && t1.resp_time <1000,1,0)) as b500t1000,
		sum(if(t1.resp_time>= 1000 && t1.resp_time <2000,1,0)) as b1000t2000, sum(if(t1.resp_time>= 2000 && t1.resp_time <3000,1,0)) as b2000t3000,
		sum(if(t1.resp_time>= 3000 && t1.resp_time <4000,1,0)) as b3000t4000,sum(if(t1.resp_time>= 4000 && t1.resp_time <10000,1,0)) as b4000t10000,
		sum(if(t1.resp_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename" . ' t1
		join (select time(t.ts) as reqtime
		from itvpmp.tb_reng_requests t 
		where date(t.ts) = "' . "$tbdbdate" . '"
		group by date(t.ts),time(t.ts)
		order by sum(t.total_request) DESC
		LIMIT 5) as t2
		on (sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)) = t2.reqtime)
		group by sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)), t1.api_method, t1.reng_node';
		$sth = PMP->query_data($sql);

		#Below is inserting the top 5 based on response time
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg ( 
		`id_country`, `req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. ' ,CAST(concat(date(t1.ts) ," ", sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)))as DATETIME) as timedate, "top5resp" as type,"reng" as component, t1.api_method, t1.reng_node,count(t1.id) as countReq,
		sum(if(t1.resp_time <500,1,0))as lt500, sum(if(t1.resp_time>= 500 && t1.resp_time <1000,1,0)) as b500t1000,
		sum(if(t1.resp_time>= 1000 && t1.resp_time <2000,1,0)) as b1000t2000, sum(if(t1.resp_time>= 2000 && t1.resp_time <3000,1,0)) as b2000t3000,
		sum(if(t1.resp_time>= 3000 && t1.resp_time <4000,1,0)) as b3000t4000,sum(if(t1.resp_time>= 4000 && t1.resp_time <10000,1,0)) as b4000t10000,
		sum(if(t1.resp_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename" . ' t1
		join (select time(t.ts) as reqtime, sum(t.resp_time* t.total_request)/sum(t.total_request), avg(t.resp_time)
		from itvpmp.tb_reng_requests t 
		where date(t.ts) = "' . "$tbdbdate" . '"
		group by date(t.ts),time(t.ts)
		order by sum(t.resp_time* t.total_request)/sum(t.total_request) DESC
		LIMIT 5) as t2
		on (sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)) = t2.reqtime)
		group by sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)), t1.api_method, t1.reng_node';
		$sth = PMP->query_data($sql);
		
		#Below is inserting the top 5 based on concurrent threads
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`, `req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. ' ,CAST(concat(date(t1.ts) ," ", sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)))as DATETIME) as timedate, "top5concurthread" as type,"reng" as component, t1.api_method, t1.reng_node,count(t1.id) as countReq,
		sum(if(t1.resp_time <500,1,0))as lt500, sum(if(t1.resp_time>= 500 && t1.resp_time <1000,1,0)) as b500t1000,
		sum(if(t1.resp_time>= 1000 && t1.resp_time <2000,1,0)) as b1000t2000, sum(if(t1.resp_time>= 2000 && t1.resp_time <3000,1,0)) as b2000t3000,
		sum(if(t1.resp_time>= 3000 && t1.resp_time <4000,1,0)) as b3000t4000,sum(if(t1.resp_time>= 4000 && t1.resp_time <10000,1,0)) as b4000t10000,
		sum(if(t1.resp_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename" . ' t1
		join (select time(t.ts) as reqtime, sum(t.resp_time* t.total_request)/sum(t.total_request), avg(t.resp_time)
		from itvpmp.tb_reng_requests t 
		where date(t.ts) = "' . "$tbdbdate" . '"
		group by date(t.ts),time(t.ts)
		order by sum(t.resp_time * t.total_request)/60000 DESC
		LIMIT 5) as t2
		on (sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)) = t2.reqtime)
		group by sec_to_time(time_to_sec(t1.ts)- time_to_sec(t1.ts)%(60)), t1.api_method, t1.reng_node';
		$sth = PMP->query_data($sql);		



	}elsif($table=~/^ps_/){
		$logger->debug_message("... Insert into itvpmp.tb_ps_requests");
		$sql = "insert into itvpmp.tb_ps_requests (id_country, ts,ps_api,node,ps_module,sucess_count,failed_count) select $id_country , current.ts,current.ps_api,current.node, 
		        current.ps_module, (current.sucess_count - IFNULL(prev.sucess_count,0)) as deltaSucces, (current.failed_count - IFNULL(prev.failed_count,0)) as deltaFailed 
                from itvrawdata.tb_raw_ps_requests current left join itvrawdata.tb_raw_ps_requests prev on current.ps_api = prev.ps_api and current.node = prev.node 
                and current.ps_module = prev.ps_module and TIMESTAMPDIFF(HOUR, prev.ts, current.ts) =1 and current.sucess_count >= prev.sucess_count 
				and current.failed_count >= prev.failed_count";
		$sth = PMP->query_data($sql);		
		$logger->debug_message("... truncate table tb_raw_ps_requests");	
		$sql = "truncate table tb_raw_ps_requests";
		$sth = PMP->query_data($sql);		
	}elsif($table=~/^psrequest/){
#24 April 2014 - Maximo	
		$logger->debug_message("... Insert into itvpmp.tb_ps_replay");
		$sql = 'insert into itvpmp.tb_ps_replay (id_country,ts,module_name,api_method,ps_node,avg_response_time,total_request,total_failure)
	        select  ' . $id_country . ', date_format(t.ts,"%Y-%m-%d %H:%i:00") as datets,
	        module,
	        api,
	        node,
	        avg(t.rt) as avg_response_time,
	        count(t.api) as total_request,
		count(nullif(t.status,0))  as total_failure' . "
	        from $tablename t
	        group by hour(t.ts),minute(t.ts),module, api, node";
		$sth = PMP->query_data($sql);

		#Below is inserting the peak hour (19 - 23) aggregation for the reng. Split in response times range.
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`,`req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(date(t.ts) as DATETIME) as timedate, "peakhour19-23" as type,"ps" as component, t.api, t.node ,count(t.id) as total_req, 
		sum(if(t.rt <500,1,0))as lt500, sum(if(t.rt>= 500 && t.rt <1000,1,0)) as b500t1000,
		sum(if(t.rt>= 1000 && t.rt <2000,1,0)) as b1000t2000, sum(if(t.rt>= 2000 && t.rt <3000,1,0)) as b2000t3000,
		sum(if(t.rt>= 3000 && t.rt <4000,1,0)) as b3000t4000,sum(if(t.rt>= 4000 && t.rt <10000,1,0)) as b4000t10000,
		sum(if(t.rt>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		where hour(t.ts) >= 17
		and hour(t.ts) < 21
		group by date(t.ts), t.api, t.node";
		$sth = PMP->query_data($sql);	
		
		#Below is inserting aggregated response times over 24 hours.
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`,`req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(date(t.ts) as DATETIME) as timedate, "per day" as type,"ps" as component, t.api, t.node ,count(t.id) as total_req, 
		sum(if(t.rt <500,1,0))as lt500, sum(if(t.rt>= 500 && t.rt <1000,1,0)) as b500t1000,
		sum(if(t.rt>= 1000 && t.rt <2000,1,0)) as b1000t2000, sum(if(t.rt>= 2000 && t.rt <3000,1,0)) as b2000t3000,
		sum(if(t.rt>= 3000 && t.rt <4000,1,0)) as b3000t4000,sum(if(t.rt>= 4000 && t.rt <10000,1,0)) as b4000t10000,
		sum(if(t.rt>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		group by date(t.ts), t.api, t.node";
		$sth = PMP->query_data($sql);
	
	}elsif($table=~/tmsondem/){	
		$logger->debug_message("... Insert data into agregated table tb_tms_ondem");
        $sql = 'insert into itvpmp.tb_tms_ondem (id_country,ts,module_name,api_method,tms_node,avg_response_time,total_request) 
        select  ' . $id_country . ', date_format(t.ts,"%Y-%m-%d %H:%i:00") as datets,
		module_name,
        api_method,
        tms_node,
        avg(t.response_time) as avg_tms,        
        count(api_method) as total_request' . " 
        from $tablename t 
        group by hour(t.ts),minute(t.ts),module_name, api_method, tms_node";	
		$sth = PMP->query_data($sql);
		
	}elsif($table=~/pshh/){	
		#nothing to do

	 }elsif($table=~/^errorstat_/){
                #nothing to do
            
	}elsif($table=~/tmstmm/){	
		#nothing to do
		
	}elsif(($table=~/mdsstbregist/) && ($tablename =~ /^mdsstbregist_/)){	
		$logger->debug_message("... Insert data into agregated table tb_mds_stbregistrations");
        $sql = "insert into itvpmp.tb_mds_stbregistrations (id_country, req_date,req_time,mds_node,count) 
        select $id_country , date(t.ts) as datets,
        sec_to_time(time_to_sec(t.ts)- time_to_sec(t.ts)%(1*60)) AS timekey,
        mds_node,
        count(mds_node) as count  		
        from $tablename t 
        group by timekey,mds_node";	
		$sth = PMP->query_data($sql);		
		
	}elsif(($table =~/mdsstbregist/) && ($tablename eq 'tb_mds_stbregistrationcountgroups')){	
		#nothing to do
		
	}elsif($table=~/ams/){	
		$logger->debug_message("... Insert data into agregated table tb_ams_requests");
        $sql = 'insert into itvpmp.tb_ams_requests(id_country,ts,thread_id,ams_node,avg_response_time,total_request) 
        select ' . $id_country . ', date_format(t.ts,"%Y-%m-%d %H:%i:00") as datets,
		thread_id,
        ams_node,
        avg(t.response_time) as avg_ams,        
        count(thread_id) as total_request
        ' . " from $tablename t 
        group by  hour(t.ts),minute(t.ts),thread_id,ams_node";	
		$sth = PMP->query_data($sql);
		
		#Below is inserting the peak hour (19 - 23) aggregation for the reng. Split in response times range.
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`,`req_date`, `type`, `component`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(date(t.ts) as DATETIME) as timedate, "peakhour19-23" as type,"ams" as component, t.ams_node ,count(t.id) as total_req, 
		sum(if(t.response_time <500,1,0))as lt500, sum(if(t.response_time>= 500 && t.response_time <1000,1,0)) as b500t1000,
		sum(if(t.response_time>= 1000 && t.response_time <2000,1,0)) as b1000t2000, sum(if(t.response_time>= 2000 && t.response_time <3000,1,0)) as b2000t3000,
		sum(if(t.response_time>= 3000 && t.response_time <4000,1,0)) as b3000t4000,sum(if(t.response_time>= 4000 && t.response_time <10000,1,0)) as b4000t10000,
		sum(if(t.response_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		where hour(t.ts) >= 17
		and hour(t.ts) < 21
		group by date(t.ts), t.ams_node";
		$sth = PMP->query_data($sql);
		
		#Below is inserting aggregated response times over 24 hours.

		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`,`req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(date(t.ts) as DATETIME) as timedate, "per day" as type,"ams" as component, "", t.ams_node ,count(t.id) as total_req, 
		sum(if(t.response_time <500,1,0))as lt500, sum(if(t.response_time>= 500 && t.response_time <1000,1,0)) as b500t1000,
		sum(if(t.response_time>= 1000 && t.response_time <2000,1,0)) as b1000t2000, sum(if(t.response_time>= 2000 && t.response_time <3000,1,0)) as b2000t3000,
		sum(if(t.response_time>= 3000 && t.response_time <4000,1,0)) as b3000t4000,sum(if(t.response_time>= 4000 && t.response_time <10000,1,0)) as b4000t10000,
		sum(if(t.response_time>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		group by date(t.ts), t.ams_node";
		$sth = PMP->query_data($sql);	
		
	}elsif($table=~/wsp/){
		$logger->debug_message("... Insert data into agregated table tb_wsp_requests");
        $sql = "insert into itvpmp.tb_wsp_requests (id_country,req_date,req_time,thread_id,ams_node,avg_response_time,total_request)
        select  ' . $id_country . ' , date(t.ts) as datets,
        sec_to_time(time_to_sec(t.ts)- time_to_sec(t.ts)%(15*60)) AS timekey,
                thread_id,
        ams_node,
        avg(t.response_time) as avg_ams,
        count(thread_id) as total_request
        from $tablename t
        group by timekey,thread_id,ams_node";
                $sth = PMP->query_data($sql);
         }elsif($table=~/vlm/){
                $logger->debug_message("... Insert data into agregated table tb_vlm_requests");
        $sql = 'insert into itvpmp.tb_vlm_requests(id_country,ts,status_code,http_method,avg_resp_time,total_request,vlm_node,mode) 
        select   ' . $id_country . ' , date_format(t.ti,"%Y-%m-%d %H:%i:00") as datets,
         status_code,http_method, avg(t.tdiff) as avg_resp_time,count(t.id) as total_request ,vlm_node,
         case when t.url like "%lastPlayDateTime%" and t.http_method = "PUT" then "Purchase/Play" when t.url like "%lastPlayPosition%"
                and t.http_method = "PUT" then "Stop Play" when t.url not like "%last%" and t.http_method = "PUT" then "Authorisation"
                when t.http_method = "GET" and t.url like "%crid%" then "My Purchased" when t.http_method = "GET" and t.url like "%-creationDate%" then "My Library"
                else "Main Menu" end as mode
         from itvrawdata.' . "$tablename  t  group by hour(t.ti),minute(t.ti),http_method,status_code";
                $sth = PMP->query_data($sql);
				
		#Below is inserting the peak hour (19 - 23) aggregation for the reng. Split in response times range.
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`,`req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(date(t.ti) as DATETIME) as timedate, "peakhour19-23" as type,"vlm" as component, t.vlm_node ,count(t.id) as total_req, 
		sum(if(t.tdiff <500,1,0))as lt500, sum(if(t.tdiff>= 500 && t.tdiff <1000,1,0)) as b500t1000,
		sum(if(t.tdiff>= 1000 && t.tdiff <2000,1,0)) as b1000t2000, sum(if(t.tdiff>= 2000 && t.tdiff <3000,1,0)) as b2000t3000,
		sum(if(t.tdiff>= 3000 && t.tdiff <4000,1,0)) as b3000t4000,sum(if(t.tdiff>= 4000 && t.tdiff <10000,1,0)) as b4000t10000,
		sum(if(t.tdiff>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		where hour(t.ti) >= 17
		and hour(t.ti) < 21
		group by date(t.ti), t.vlm_node";
		$sth = PMP->query_data($sql);	
				
		#Below is inserting aggregated response times over 24 hours.
		$sql = 'INSERT INTO itvpmp.tb_resptimes_agg (`id_country`,`req_date`, `type`, `component`, `api`, `node`, `count_req`, `lt500`, `b500t1000`, `b1000t2000`, `b2000t3000`, `b3000t4000`, `b4000t10000`, `gt10000`)
		select ' . $id_country. '  ,CAST(date(t.ti) as DATETIME) as timedate, "per day" as type,"vlm" as component, t.vlm_node ,count(t.id) as total_req, 
		sum(if(t.tdiff <500,1,0))as lt500, sum(if(t.tdiff>= 500 && t.tdiff <1000,1,0)) as b500t1000,
		sum(if(t.tdiff>= 1000 && t.tdiff <2000,1,0)) as b1000t2000, sum(if(t.tdiff>= 2000 && t.tdiff <3000,1,0)) as b2000t3000,
		sum(if(t.tdiff>= 3000 && t.tdiff <4000,1,0)) as b3000t4000,sum(if(t.tdiff>= 4000 && t.tdiff <10000,1,0)) as b4000t10000,
		sum(if(t.tdiff>= 10000,1,0)) as gt10000
		from itvrawdata.' . "$tablename t
		group by date(t.ti), t.vlm_node";
		$sth = PMP->query_data($sql);		

         }elsif($table=~/Jmx/){
                $logger->debug_message("... Insert data into agregated table tb_jmx_stats");
        $sql = 'insert into itvpmp.tb_jmx_stats(id_country,method,statsval,ts,ams_node) 
        select   ' . $id_country . ' , method,statsval,date_format(t.ts,"%Y-%m-%d %H:%i:00") as datets,
         ams_node from itvrawdata.' . "$tablename  t order by hour(t.ts),minute(t.ts)";
                $sth = PMP->query_data($sql);
	}else{
		$logger->debug_message("ERROR: do not know which table to maintain, (table,tablenale) = ($table,$tablename)");

	}	
	$logger->debug_message("DEBUG : TABLE $table, SQL $sql") if($VERBOSE);

#		$logger->debug_message("... Update lookup table api_names_cmdc");
#		my $sql = "insert into api_names_cmdc (name) (SELECT distinct `cmdc_api` FROM `$tablename` where  `cmdc_api` not in (select name from api_names_cmdc))";
#		$sth = PMP->query_data($sql);
#		$logger->debug_message("... Update API id's on $tablename");
#		$sql = "update $tablename inner join api_names_cmdc on ($tablename.cmdc_api = api_names_cmdc.name) set $tablename.cmdc_api_id = api_names_cmdc.id_api";
#		$sth = PMP->query_data($sql);
#		$logger->debug_message("... Drop cmdc_api column on $tablename");
#		$sth = PMP->query_data("alter table $tablename drop column cmdc_api");			
	
}

sub drop_old_raw_tables{
	#drop table older than today - n days
	my ($table) = @_;
	my ($table_ts,$now_ts, $sql, $aux, @tables);

	$table=~/(\w+)_(\w{2})/;
	$aux = $1;
	$logger->debug_message("Drop old tables type $aux");	
	$sql = "show tables like '$aux" . '%' . "'";
	$sth = PMP->query_data($sql);
	while ((@row) = $sth->fetchrow_array) {		
		push @tables, $row[0]; 
	}
	
	foreach my $tb (@tables){		
		$tb=~/_(\d{8})\z/;
		$table_ts = &get_ts($1);
		$now_ts = time;
		if(($now_ts - $table_ts) > (($RAWDATARETENTION)* 3600 * 24)){
			$logger->debug_message("... Table $tb is older than $RAWDATARETENTION and must be DROPPED ");
			$sql = "drop table $tb";
			$sth = PMP->query_data($sql);			
			$logger->debug_message("DEBUG : TABLE $table, SQL $sql") if($VERBOSE);	
		}
	}			
}

sub parse_and_insert{
	my ($dir,$file,$table,$finaltablename, $id_country) = @_;
	
	my ($insert_table, $node, $sql, $module);
	
	if($table=~/cmdc/){
		$file =~ /\d{8}-CMDC(\d+)/;
		$node = $1;	
		$insert_table = "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY \'"\' LINES TERMINATED BY "\n" (@ts, @api, @cmdc_rt, @twc_rt, @reng_rt, @traxis_rt, @int_rt, @ct, @http, @url, @cb) SET ts = @ts, cmdc_api = @api, cmdc_resp_time = if(length(@cmdc_rt)=0,NULL,@cmdc_rt), twc_resp_time = if(length(@twc_rt)=0,NULL,@twc_rt),reng_resp_time = if(length(@reng_rt)=0,NULL,@reng_rt),traxis_resp_time =if(length(@traxis_rt)=0,NULL,@traxis_rt), int_resp_time = if(length(@int_rt)=0,NULL,@int_rt), client_type = @ct, http_resp_code = @http, url = @url, control_bit = @cb, cmdc_node = ' . $node;
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		

		
	}elsif($table=~/sgw_requests/){
		$file =~ /(\d{4})(\d{2})(\d{2})-SGW(\d+)/;
		my $aux = "$1-$2-$3";
		$node = $4;
		$insert_table = "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY \'"\' LINES TERMINATED BY "\n" (@id, @h, @m, @s, @rcount, @avg_rt, @component) SET  ts = concat("' . $aux . ' ",@h,":",@m,":",@s), request_count = @rcount, avg_rt=if(length(@avg_rt)=0,NULL,@avg_rt), component=@component, sgwNode = '. $node;
		$logger->debug_message("... Insert data into $finaltablename");
                $sth = PMP->query_data($insert_table);
			
	}elsif($table=~/sgw_errors/){
		$file =~ /(\d{4})-(\d{2})-(\d{2})-SGWerrors-.+(\d+)/;
		my $aux = "$1-$2-$3";
		$node = $4;
		$insert_table = "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY ";" OPTIONALLY ENCLOSED BY \'"\' LINES TERMINATED BY "\n" (@time, @cat, @message) SET  ts = concat("' . $aux . ' ",@time), category = @cat, message=@message, sgwNode = '. $node;
		$logger->debug_message("... Insert data into $finaltablename");
                $sth = PMP->query_data($insert_table);

				
    }elsif($table=~/reng_/){
		$file =~ /\d{8}-RENGExportNode(\d+)/;
		$node = $1;	
		$insert_table = "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n" (@ip, @ts, @httpm, @httprc, @api, @dflag, @oflag,@ctype, @rt, @tid, @subid) SET source_ip = @ip, ts = str_to_date(@ts,' . '"%d/%M/%Y:%H:%i:%s"), http_method = @httpm, http_response_code = @httprc, api_method = @api, d4a_customer_flag = @dflag, orion_customer_flag = @oflag, client_type = @ctype,resp_time = @rt,thread_id = @tid, subid = nullif(@subid," "), reng_node = ' . $node;
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		
    	# source IP from request, date, HTTP method, http resp code, api method, 1 is D4A customer, 1 if Orion customer, client type
		
	}elsif($table=~/rengingest/){
		# 20130903-RENGIngest.csv
		$file =~ /(\d{4})(\d{2})(\d{2})-RENGIngest.csv/;
		my $aux = "$3,$2,$1"; 
		$insert_table = "LOAD DATA INFILE '$dir/$file' INTO TABLE itvpmp.$finaltablename FIELDS TERMINATED BY " .  '";" LINES TERMINATED BY "\n" (@1,@2,@3,@4,@5,@6,@7,@8,@9,@10) SET id_country = ' . $id_country . ', req_date = str_to_date("' . $aux . '","%d,%m,%Y"),item_ingested=REPLACE(@1,",",""),item_rejected=REPLACE(@2,",",""),preview_noingested=REPLACE(@3,",",""), rejected_percentile=REPLACE(@4,"%"," "), scheduleventoDVtripletnopresenithtopologfile=REPLACE(@5,",",""), prograinformationwitnlanguagwittitlansynopsis=REPLACE(@6,",",""), prograinformationwitainvaliparentarating=REPLACE(@7,",",""), prograinformationwitnUPevengenre=REPLACE(@8,",",""), itemreferencinnonexistenprograinformations=REPLACE(@9,",",""), invaliclassificatioscheme=REPLACE(@10,",","")';
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		
    	
	}elsif($table=~/^ps_/){
		$file =~ /\d{8}-PS(\d)-(\w+)\.csv/;
		$node = $1;		
		$module = $2;
		$insert_table =  "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n"  (@ts, @api, @sucess, @failure, @node) SET ts = @ts, ps_api = @api, sucess_count = @sucess, failed_count = @failure,  node = ' . $node . ' , ps_module = "' . $module . '"';
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		

		
	}elsif($table=~/^pshh/){
		$insert_table =  "LOAD DATA INFILE '$dir/$file' INTO TABLE itvpmp.$finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n"  (@ts, @variable, @value) SET ts = str_to_date(@ts,' . '"%d-%M-%Y:%H:%i:%s"), variable = @variable, value = @value, id_country =' . $id_country;
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		

		
	}elsif($table=~/^psrequest/){
#24 April 2014 - Maximo		
		$file =~ /\d{8}-ps-(\w+)-replay-(\d).csv/;
		$module = $1;
		$node = $2;
		$insert_table = "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename FIELDS TERMINATED BY ';' ENCLOSED BY '\"' LINES TERMINATED BY " . '"\n"  (@startTime, @endTime, @api, @status)
	SET ts=@startTime, rt=timestampdiff(microsecond,@startTime,@endTime)/1000, module="' . $module . '", api=@api, node=' . $node . ',status=@status';
		$logger->debug_message("PS request sql: $insert_table");
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);


	}elsif($table=~/^errorstat/){
		$file =~ /\d{8}-cmdcStats(\d)/;
		$node = $1;
         $insert_table =  "LOAD DATA INFILE '$dir/$file' INTO TABLE itvpmp.$finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n"  (@ts, @variable, @value) SET date = @ts, matrixName = @variable, matrixValue = @value, id_country =' . $id_country . ", node = " . $node;
                $logger->debug_message("... Insert data into $finaltablename");
                $sth = PMP->query_data($insert_table);


        }elsif($table=~/tmsondem/){
		$file =~ /\d{8}-\w{2}tmsappOndemand(\d)\.csv/;
		$node = $1;				
		$insert_table =  "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n"  (@ts, @module, @api, @rtime) SET ts = @ts,module_name = @module,api_method=@api,response_time=@rtime,tms_node = ' . $node;
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		
		
	}elsif($table=~/tmstmm/){
		$file =~ /\d{8}-\w{2}tmsapp(\d)\.csv/;
		$node = $1;		
		$insert_table =  "LOAD DATA INFILE '$dir/$file' INTO TABLE itvpmp.$finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n"  (@ts, @source, @api, @rtime) SET ts = @ts,source_component = @source,api_method=@api,response_time=@rtime,tms_node =' . $node . ", id_country = " . $id_country;
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		
		
	}elsif($table=~/mdsstbregist/){

		if($file=~/MDSCPERegistration.csv/){			
			$insert_table =  "LOAD DATA INFILE '$dir/$file' INTO TABLE itvpmp.tb_mds_stbregistrationcountgroups " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n"  (@ts, @count_group, @value) SET ts = str_to_date(@ts,' . '"%Y-%M-%d"), count_group=@count_group, value = @value, id_country = ' . $id_country;
		}else{
			$file =~ /\d{8}-MDSCPERegistrationRaw(\d)\.csv/;
			$node = $1;		
			$insert_table =  "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n"  (@ts) SET ts = str_to_date(@ts,' . '"%d/%M/%Y:%H:%i:%s"), mds_node = ' . $node;
		}
		
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		
		
	}elsif($table=~/ams/){
		$file =~ /\d{8}-amsExport(\d)\.csv/;
		$node = $1;		
		$insert_table =  "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n"  (@ts, @rtime, @tid) SET ts = str_to_date(@ts,' . '"%d/%M/%Y:%H:%i:%s"),response_time=@rtime,thread_id = @tid, ams_node = ' . $node;
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		
		
	}elsif($table=~/wsp/){
		$file =~ /\d{8}-wspExport(\d)\.csv/;
                $node = $1;
                $insert_table =  "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n"  (@ts, @rtime, @tid) SET ts = str_to_date(@ts,' . '"%d/%M/%Y:%H:%i:%s"),response_time=@rtime,thread_id = @tid, ams_node = ' . $node;
                $logger->debug_message("... Insert data into $finaltablename");
                $sth = PMP->query_data($insert_table);

        }elsif($table=~/vlm/){
		$file =~ /\d{8}-vlm(\d+)/;
		$node = $1;	
		$insert_table = "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY ";" LINES TERMINATED BY "\n" (@ti, @tf,@http_method, @subscriber_id, @status_code, @url) SET ti = @ti,tf = @tf, tdiff=timestampdiff(microsecond,@ti,@tf)/1000,http_method = @http_method, subscriber_id = @subscriber_id, status_code = @status_code, url = @url, vlm_node = ' . $node;
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		

        }elsif($table=~/Jmx/){
		$file =~ /\d{8}-Jmx(\d+)/;
		$node = $1;	
		$insert_table = "LOAD DATA INFILE '$dir/$file' INTO TABLE $finaltablename " . 'FIELDS TERMINATED BY "," LINES TERMINATED BY "\n" (@method, @statsval,@ts) SET method = @method,statsval= @statsval, ts = @ts, ams_node = ' . $node;
		$logger->debug_message("... Insert data into $finaltablename");
		$sth = PMP->query_data($insert_table);		
	}else{
		$logger->debug_message("ERROR: do not know which table to insert table = $table");

	}	
	$logger->debug_message("DEBUG : TABLE $table, SQL $insert_table") if($VERBOSE);	
	
}

sub prepare_table{
	my ($table, $file, $country_code) = @_;
	my ($create_table, $finaltablename, $ts);	
	
	if($table=~/sgw_errors/){

		$file =~ /(\d{4})-(\d{2})-(\d{2})-.+\.csv/;
		$ts = $1 . $2 . $3; 		
	}else{
		$file =~ /(\d{8})-.+\.csv/;
		$ts = $1;	
	}
	if($ts){		
		$finaltablename = $table  . '_' . $ts;	
	}
	return($finaltablename) if $newtables{$finaltablename};
	
	if($table =~/cmdc/){
	   $create_table = "CREATE TABLE IF NOT EXISTS TABLENAME (
       id int(10) unsigned NOT NULL AUTO_INCREMENT,
       ts timestamp NOT NULL ,
       cmdc_api_id tinyint(3) unsigned NOT NULL,
       cmdc_resp_time smallint(5) unsigned,
       twc_resp_time smallint(5) unsigned,
       reng_resp_time smallint(5) unsigned,
       traxis_resp_time smallint(5) unsigned,
       int_resp_time smallint(5) unsigned,
       client_type smallint(5) unsigned,
       http_resp_code smallint(5) unsigned,
       url varchar(400) NOT NULL,
       control_bit tinyint(1) NOT NULL,
       cmdc_api varchar(60) NOT NULL,
       cmdc_node tinyint(3) unsigned NOT NULL,
       PRIMARY KEY (id)
       ) ENGINE=MyISAM DEFAULT CHARSET=utf8";
		$create_table=~ s/TABLENAME/$finaltablename/;
		$sth = PMP->query_data($create_table);	
		$logger->debug_message("Creating table $finaltablename");
	   
	}elsif($table =~/sgw_requests/){
		$create_table = "CREATE TABLE TABLENAME (
		`id` INT(10) NOT NULL AUTO_INCREMENT,
		`ts` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		`request_count` INT(11) NOT NULL COMMENT 'response times',
		`avg_rt` INT(11) NOT NULL COMMENT 'response times',
		`component` VARCHAR(50) NOT NULL,
		`sgwNode` SMALLINT(6) NOT NULL,
		PRIMARY KEY (`id`)
		)COLLATE='utf8_general_ci' ENGINE=MyISAM;";
		$create_table=~ s/TABLENAME/$finaltablename/;
		$sth = PMP->query_data($create_table);
		$logger->debug_message("Creating table $finaltablename");

	}elsif($table =~/sgw_errors/){
		$create_table = "CREATE TABLE TABLENAME (
		`id` INT(10) NOT NULL AUTO_INCREMENT,
		`ts` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		`category` VARCHAR(50) NOT NULL,
		`message` VARCHAR(50) NOT NULL,
		`sgwNode` SMALLINT(6) NOT NULL,
		PRIMARY KEY (`id`)
		)COLLATE='utf8_general_ci' ENGINE=MyISAM;";
		$create_table=~ s/TABLENAME/$finaltablename/;
		$sth = PMP->query_data($create_table);
		$logger->debug_message("Creating table $finaltablename");
	
	}elsif($table =~/reng_/){
	# source IP from request, date, HTTP method, http resp code, api method, 1 is D4A customer, 1 if Orion customer, client type	
	   $create_table = "CREATE TABLE IF NOT EXISTS TABLENAME (
       id int(10) unsigned NOT NULL AUTO_INCREMENT,
	   source_ip varchar(15) NOT NULL,
       ts timestamp NOT NULL ,
       http_method varchar(60) NOT NULL,
       http_response_code smallint(5) unsigned NOT NULL,
       api_method varchar(60) NOT NULL,
       d4a_customer_flag tinyint(1) unsigned NOT NULL,
       orion_customer_flag tinyint(1) unsigned NOT NULL,
       client_type smallint(5) unsigned NOT NULL,
	   reng_node tinyint(3) unsigned NOT NULL,
	   resp_time smallint(5) unsigned,
	   thread_id smallint(5) unsigned,
       subid varchar(12) NULL,
       PRIMARY KEY (id)
       ) ENGINE=MyISAM DEFAULT CHARSET=utf8";
		$create_table=~ s/TABLENAME/$finaltablename/;
		$sth = PMP->query_data($create_table);	
		$logger->debug_message("Creating table $finaltablename");
	
	}elsif($table =~/rengingest_/){
		$finaltablename = 'tb_reng_ingest';	
	
	}elsif($table=~/^ps_/){
		$finaltablename = 'tb_raw_ps_requests';
		
	}elsif($table=~/^pshh_/){
		$finaltablename = 'tb_ps_households';	
		
	}elsif($table=~/^psrequest_/){
#24 April 2014 - Maximo	
		$create_table="CREATE TABLE IF NOT EXISTS TABLENAME (
	id INT(10) NOT NULL AUTO_INCREMENT,
	ts TIMESTAMP NULL NOT NULL,
	rt MEDIUMINT(9) NULL DEFAULT NULL,
	module VARCHAR(50) NULL DEFAULT 0,
	api VARCHAR(50) NULL DEFAULT 0,
	node TINYINT(4) NULL DEFAULT 0,
	status VARCHAR(1) NULL DEFAULT 0,
	PRIMARY KEY (id)
	)
	ENGINE=MyISAM
	DEFAULT CHARSET=utf8";
		$create_table=~ s/TABLENAME/$finaltablename/;
		$sth = PMP->query_data($create_table);
                $logger->debug_message("Creating table $finaltablename");
	}elsif($table=~/^errorstat_/){
		$finaltablename = 'tb_cmdc_stats';

        }elsif($table=~/tmsondem/){ 
	   $create_table = "CREATE TABLE IF NOT EXISTS TABLENAME (
       id int(10) unsigned NOT NULL AUTO_INCREMENT,
       ts timestamp NOT NULL ,
       module_name varchar(60) NOT NULL,
	   api_method varchar(60) NOT NULL,
       response_time smallint(5) unsigned NOT NULL,       
	   tms_node tinyint(3) unsigned NOT NULL,
       PRIMARY KEY (id)
       ) ENGINE=MyISAM DEFAULT CHARSET=utf8";
		$create_table=~ s/TABLENAME/$finaltablename/;
		$sth = PMP->query_data($create_table);	
		$logger->debug_message("Creating table $finaltablename");

		
	}elsif($table=~/tmstmm/){
		$finaltablename = 'tb_tms_tmm';	
		
	}elsif($table=~/mdsstbregist/){
		if($file=~/MDSCPERegistration.csv/){
			$finaltablename = 'tb_mds_stbregistrationcountgroups';	
		}else{
	        $create_table = "CREATE TABLE IF NOT EXISTS TABLENAME (
            id int(10) unsigned NOT NULL AUTO_INCREMENT,
            ts timestamp NOT NULL, 
			mds_node tinyint(3) unsigned NOT NULL,
            PRIMARY KEY (id)
            ) ENGINE=MyISAM DEFAULT CHARSET=utf8";
		    $create_table=~ s/TABLENAME/$finaltablename/;
		    $sth = PMP->query_data($create_table);	
		    $logger->debug_message("Creating table $finaltablename");
		}		

		
	}elsif($table=~/ams/){ 
	   $create_table = "CREATE TABLE IF NOT EXISTS TABLENAME (
       id int(10) unsigned NOT NULL AUTO_INCREMENT,
       ts timestamp NOT NULL ,
       response_time smallint(5) unsigned NOT NULL,       
	   thread_id varchar(60) NOT NULL,
	   ams_node tinyint(3) unsigned NOT NULL,
       PRIMARY KEY (id)
       ) ENGINE=MyISAM DEFAULT CHARSET=utf8";
		$create_table=~ s/TABLENAME/$finaltablename/;
		$sth = PMP->query_data($create_table);	
		$logger->debug_message("Creating table $finaltablename");

		
	}elsif($table=~/wsp/){
		$create_table = "CREATE TABLE IF NOT EXISTS TABLENAME (
       id int(10) unsigned NOT NULL AUTO_INCREMENT,
       ts timestamp NOT NULL ,
       response_time smallint(5) unsigned NOT NULL,
           thread_id varchar(60) NOT NULL,
           ams_node tinyint(3) unsigned NOT NULL,
       PRIMARY KEY (id)
       ) ENGINE=MyISAM DEFAULT CHARSET=utf8";
                $create_table=~ s/TABLENAME/$finaltablename/;
                $sth = PMP->query_data($create_table);
                $logger->debug_message("Creating table $finaltablename");

	}elsif($table =~/vlm/){
		$create_table = "CREATE TABLE IF NOT EXISTS TABLENAME (
       id int(10) unsigned NOT NULL AUTO_INCREMENT,
       ti timestamp NOT NULL ,
       tf timestamp NOT NULL ,
       tdiff smallint(5) NOT NULL ,
       http_method varchar(10) NOT NULL,
       subscriber_id varchar(10) NOT NULL,
       status_code smallint(5) unsigned NOT NULL,
       url varchar(400) NOT NULL,
       vlm_node tinyint(3) unsigned NOT NULL,
       PRIMARY KEY (id)
       ) ENGINE=MyISAM DEFAULT CHARSET=utf8";
	$create_table=~ s/TABLENAME/$finaltablename/;
	$sth = PMP->query_data($create_table);
	$logger->debug_message("Creating table $finaltablename");

	}elsif($table =~/Jmx/){
		$create_table = "CREATE TABLE IF NOT EXISTS TABLENAME (
       id int(10) unsigned NOT NULL AUTO_INCREMENT,
       method varchar(20) NOT NULL,
       statsval int NOT NULL,
       ts timestamp NOT NULL ,
       ams_node tinyint(3) unsigned NOT NULL,
       PRIMARY KEY (id)
       ) ENGINE=MyISAM DEFAULT CHARSET=utf8";
	$create_table=~ s/TABLENAME/$finaltablename/;
	$sth = PMP->query_data($create_table);
	$logger->debug_message("Creating table $finaltablename");
	}else{
		$logger->debug_message("ERROR: do not know which table to create table = $table");
	}		
	
	$newtables{$finaltablename} = 1;
	
	return $finaltablename;
}

sub get_ts {
	
	my ($htime) = @_;
	my ($ts);

	$htime=~/(\d{4})(\d{2})(\d{2})/;
	my ($year,$mon,$mday) = ($1,$2,$3);
	$year = $year - 1900;
    $mon = $mon - 1;
	$ts = timelocal(0,0,0,$mday,$mon,$year);

 return ($ts);
}
sub read_config {

	my (@aux, $line, $aux );
	open(FP, "< $configfile") || die("cant open $configfile: $!");
	while(<FP>){
		#Root table name;path to raw files
		$line = $_;
		next if($line =~/^#/);
		@aux = split(/;/,$line);
		$aux[1] =~/\/logs\/(\w{2})\/[a-zA-Z]+/;
		$aux = $aux[0] . '_' . $1;
        $rawfile{$aux} = $aux[1];		
	}
}


sub parse_command_line {
                                                                                                                            
    my $parameter = "";
    my $paranumber = 0;
                                                                                                                            
    $parameter = shift(@ARGV);
    if($parameter){
        do{
            if($parameter eq "-v"){
                $VERBOSE = 1;
            }elsif($parameter eq "-h"){
                &usage;
                exit;
            }elsif($parameter eq "-c"){
                $configfile = shift(@ARGV);
            }elsif($parameter eq "-n"){
                $NOSQLACTION = 1;
            }
									                                                                                                                           
            $parameter = shift(@ARGV);
        }while $parameter;
    }
                                                                                                                            
}# Parse_Command_Line ends here !!!

sub usage {

	print " perl InsertRawBulkData.pl [-v] [-h] [-c configuration file] [-n] \n";
	print " -c : if not specidfied ./InsertRawBulkData.cfg is used\n";
	print " -n : disable all SQL commands\n";
	print " \n";

}





#select date(t.ts) as datets,
#sec_to_time(time_to_sec(t.ts)- time_to_sec(t.ts)%(5*60)) AS timekey,
#api_method,
#(SUM(IF(t.http_method='POST',1,0)) / count(t.api_method)*100) as httpPOSTPercentage,
#(SUM(IF(t.http_method='GET',1,0)) / count(t.api_method)*100) as httpGETPercentage,
#(SUM(IF(t.http_response_code=200,1,0)) / count(t.api_method)*100) as http200Percentage,
#(SUM(IF(t.http_response_code=400,1,0)) / count(t.api_method)*100) as http400Percentage,
#client_type,
#reng_node,
#d4a_customer_flag,
#orion_customer_flag,
#count(api_method) 
#from reng_20121122 t 
#group by timekey, api_method, http_method, http_response_code, client_type,reng_node, d4a_customer_flag, orion_customer_flag



#CREATE TABLE IF NOT EXISTS tb_reng_requests (
#       id int(10) unsigned NOT NULL AUTO_INCREMENT,#
#	   req_date date NOT NULL ,
#	   req_time time NOT NULL ,
#       api_method varchar(60) NOT NULL,#
#	   source_ip varchar(15) NOT NULL,	   
#       http_method varchar(60) NOT NULL,
#       http_response_code smallint(5) unsigned NOT NULL,
#       client_type tinyint(3) unsigned NOT NULL,#
#	   reng_node tinyint(3) unsigned NOT NULL,
#       d4a_customer_flag tinyint(1) unsigned NOT NULL,
#       orion_customer_flag tinyint(1) unsigned NOT NULL,
#	   total_request smallint(5) unsigned NOT NULL,
#       PRIMARY KEY (id)
#       ) ENGINE=MyISAM DEFAULT CHARSET=utf8


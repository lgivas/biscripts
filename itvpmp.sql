-- MySQL dump 10.13  Distrib 5.1.73, for redhat-linux-gnu (x86_64)
--
-- Host: localhost    Database: itvpmp
-- ------------------------------------------------------
-- Server version	5.1.73

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `RengTraxis`
--

DROP TABLE IF EXISTS `RengTraxis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RengTraxis` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `subscriberId` varchar(20) DEFAULT NULL,
  `ts` varchar(30) DEFAULT NULL,
  `ts_load_customer` varchar(30) DEFAULT NULL,
  `api` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=7493806 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cmdc_agg`
--

DROP TABLE IF EXISTS `cmdc_agg`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cmdc_agg` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` varchar(5) DEFAULT NULL,
  `req_date` varchar(50) DEFAULT NULL,
  `api_method` varchar(20) DEFAULT NULL,
  `cmdc_node` int(11) DEFAULT NULL,
  `count_req` float DEFAULT NULL,
  `KPI` float DEFAULT NULL,
  `int_resp_time` float DEFAULT NULL,
  `twc_resp_time` float DEFAULT NULL,
  `traxis_resp_time` float DEFAULT NULL,
  `reng_resp_time` float DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=252886 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mehdi_agg`
--

DROP TABLE IF EXISTS `mehdi_agg`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mehdi_agg` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` varchar(5) DEFAULT NULL,
  `req_date` varchar(50) DEFAULT NULL,
  `type` varchar(100) DEFAULT NULL,
  `component` varchar(20) DEFAULT NULL,
  `api_method` varchar(30) DEFAULT NULL,
  `node` int(11) DEFAULT NULL,
  `count_req` float DEFAULT NULL,
  `lt500` float DEFAULT NULL,
  `b500t1000` float DEFAULT NULL,
  `b1000t2000` float DEFAULT NULL,
  `b2000t3000` float DEFAULT NULL,
  `b3000t4000` float DEFAULT NULL,
  `b4000t10000` float DEFAULT NULL,
  `gt10000` float DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1026555 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_ams_requests`
--

DROP TABLE IF EXISTS `tb_ams_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_ams_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `ts` datetime DEFAULT NULL,
  `thread_id` varchar(60) DEFAULT NULL,
  `ams_node` tinyint(3) DEFAULT NULL,
  `avg_response_time` int(11) DEFAULT NULL,
  `total_request` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=24020865 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_cmdc_requests`
--

DROP TABLE IF EXISTS `tb_cmdc_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_cmdc_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `ts` datetime DEFAULT NULL,
  `req_method` tinytext,
  `req_count` int(11) DEFAULT NULL,
  `avg_cmdc` int(11) DEFAULT NULL,
  `avg_TWC` int(11) DEFAULT NULL,
  `avg_RENG` int(11) DEFAULT NULL,
  `avg_Traxis` int(11) DEFAULT NULL,
  `http_OKPerc` int(11) DEFAULT NULL,
  `http_404Perc` int(11) DEFAULT NULL,
  `http_500Perc` int(11) DEFAULT NULL,
  `reng_client_type` int(11) DEFAULT NULL,
  `cmdc_node` tinyint(3) DEFAULT NULL,
  `twc_count` int(11) DEFAULT NULL,
  `reng_count` int(11) DEFAULT NULL,
  `traxis_count` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `id_country_idx` (`id_country`),
  KEY `ts_idx` (`ts`),
  KEY `top5index` (`ts`,`cmdc_node`)
) ENGINE=MyISAM AUTO_INCREMENT=109825715 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_cmdc_stats`
--

DROP TABLE IF EXISTS `tb_cmdc_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_cmdc_stats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date` datetime DEFAULT NULL,
  `matrixName` varchar(25) DEFAULT NULL,
  `matrixValue` smallint(12) DEFAULT NULL,
  `id_country` tinyint(3) DEFAULT NULL,
  `node` tinyint(3) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=76609 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_country`
--

DROP TABLE IF EXISTS `tb_country`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_country` (
  `id_country` int(2) NOT NULL,
  `name` varchar(5) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_jmx_stats`
--

DROP TABLE IF EXISTS `tb_jmx_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_jmx_stats` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `method` varchar(20) NOT NULL,
  `statsval` int(11) NOT NULL,
  `ts` datetime NOT NULL,
  `ams_node` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1939377 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_mds_stbregistrations`
--

DROP TABLE IF EXISTS `tb_mds_stbregistrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_mds_stbregistrations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `req_date` datetime DEFAULT NULL,
  `req_time` datetime DEFAULT NULL,
  `mds_node` tinyint(3) DEFAULT NULL,
  `count` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_ps_households`
--

DROP TABLE IF EXISTS `tb_ps_households`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_ps_households` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `variable` varchar(20) DEFAULT NULL,
  `value` int(11) DEFAULT NULL,
  `id_country` tinyint(3) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=13388 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_ps_replay`
--

DROP TABLE IF EXISTS `tb_ps_replay`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_ps_replay` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `ts` datetime DEFAULT NULL,
  `module_name` varchar(50) DEFAULT NULL,
  `api_method` varchar(50) DEFAULT NULL,
  `ps_node` tinyint(3) DEFAULT NULL,
  `avg_response_time` mediumint(9) DEFAULT NULL,
  `total_request` int(11) DEFAULT NULL,
  `total_failure` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=17357499 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_ps_requests`
--

DROP TABLE IF EXISTS `tb_ps_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_ps_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ps_api` varchar(50) DEFAULT NULL,
  `node` tinyint(3) DEFAULT NULL,
  `ps_module` varchar(20) DEFAULT NULL,
  `sucess_count` int(11) DEFAULT NULL,
  `failed_count` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=2170867 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_rengTraxis`
--

DROP TABLE IF EXISTS `tb_rengTraxis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_rengTraxis` (
  `id` int(10) unsigned NOT NULL DEFAULT '0',
  `id_country` smallint(5) unsigned DEFAULT NULL,
  `source_ip` varchar(15) NOT NULL,
  `ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `http_response_code` smallint(5) unsigned NOT NULL,
  `api_method` varchar(60) NOT NULL,
  `reng_node` tinyint(3) unsigned NOT NULL,
  `resp_time` smallint(5) unsigned DEFAULT NULL,
  `traxis_resp_time` smallint(5) unsigned DEFAULT NULL,
  `traxis_node` tinyint(3) unsigned NOT NULL,
  `reng_resp_time` smallint(5) unsigned DEFAULT NULL,
  `traxis_cust_load` int(4) DEFAULT NULL,
  `traxis_custPvr_load` int(4) DEFAULT NULL,
  `req_count` int(10) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_reng_ingest`
--

DROP TABLE IF EXISTS `tb_reng_ingest`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_reng_ingest` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `req_date` datetime DEFAULT NULL,
  `item_ingested` smallint(6) DEFAULT NULL,
  `item_rejected` smallint(6) DEFAULT NULL,
  `preview_noingested` smallint(6) DEFAULT NULL,
  `rejected_percentile` smallint(6) DEFAULT NULL,
  `scheduleventoDVtripletnopresenithtopologfile` smallint(6) DEFAULT NULL,
  `prograinformationwitnlanguagwittitlansynopsis` smallint(6) DEFAULT NULL,
  `prograinformationwitainvaliparentarating` smallint(6) DEFAULT NULL,
  `prograinformationwitnUPevengenre` smallint(6) DEFAULT NULL,
  `itemreferencinnonexistenprograinformations` smallint(6) DEFAULT NULL,
  `invaliclassificatioscheme` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=318110393 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_reng_requests`
--

DROP TABLE IF EXISTS `tb_reng_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_reng_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `ts` datetime DEFAULT NULL,
  `api_method` varchar(60) DEFAULT NULL,
  `source_ip` varchar(15) DEFAULT NULL,
  `http_method` varchar(60) DEFAULT NULL,
  `http_response_code` int(11) DEFAULT NULL,
  `client_type` int(11) DEFAULT NULL,
  `reng_node` tinyint(3) DEFAULT NULL,
  `d4a_customer_flag` tinyint(1) DEFAULT NULL,
  `orion_customer_flag` tinyint(1) DEFAULT NULL,
  `total_request` int(11) DEFAULT NULL,
  `resp_time` int(11) DEFAULT NULL,
  `thread_id` int(11) DEFAULT NULL,
  `subid` varchar(12) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=281765625 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_resptimes_agg`
--

DROP TABLE IF EXISTS `tb_resptimes_agg`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_resptimes_agg` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `req_date` datetime DEFAULT NULL,
  `type` varchar(25) DEFAULT NULL,
  `component` varchar(5) DEFAULT NULL,
  `api` varchar(60) DEFAULT NULL,
  `compo` varchar(20) DEFAULT NULL,
  `node` int(11) DEFAULT NULL,
  `count_req` int(11) DEFAULT NULL,
  `lt500` int(11) DEFAULT NULL,
  `b500t1000` int(11) DEFAULT NULL,
  `b1000t2000` int(11) DEFAULT NULL,
  `b2000t3000` int(11) DEFAULT NULL,
  `b3000t4000` int(11) DEFAULT NULL,
  `b4000t10000` int(11) DEFAULT NULL,
  `gt10000` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1806018 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_resptimes_agg_copy`
--

DROP TABLE IF EXISTS `tb_resptimes_agg_copy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_resptimes_agg_copy` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `req_date` datetime DEFAULT NULL,
  `type` varchar(25) DEFAULT NULL,
  `component` varchar(5) DEFAULT NULL,
  `api` varchar(60) DEFAULT NULL,
  `compo` varchar(50) DEFAULT NULL,
  `node` int(11) DEFAULT NULL,
  `count_req` int(11) DEFAULT NULL,
  `lt500` int(11) DEFAULT NULL,
  `b500t1000` int(11) DEFAULT NULL,
  `b1000t2000` int(11) DEFAULT NULL,
  `b2000t3000` int(11) DEFAULT NULL,
  `b3000t4000` int(11) DEFAULT NULL,
  `b4000t10000` int(11) DEFAULT NULL,
  `gt10000` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=48 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_sgw_errors`
--

DROP TABLE IF EXISTS `tb_sgw_errors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_sgw_errors` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `node` tinyint(3) DEFAULT NULL,
  `category` varchar(50) DEFAULT NULL,
  `message` varchar(50) DEFAULT NULL,
  `total_count` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=2545510 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_sgw_requests`
--

DROP TABLE IF EXISTS `tb_sgw_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_sgw_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `ts` datetime DEFAULT NULL,
  `component` varchar(5) DEFAULT NULL,
  `method` varchar(20) DEFAULT NULL,
  `node` int(11) DEFAULT NULL,
  `total_count` int(11) DEFAULT NULL,
  `avg_rt` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=29837658 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_tms_ondem`
--

DROP TABLE IF EXISTS `tb_tms_ondem`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_tms_ondem` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `ts` datetime DEFAULT NULL,
  `module_name` varchar(60) DEFAULT NULL,
  `api_method` varchar(60) DEFAULT NULL,
  `tms_node` tinyint(3) DEFAULT NULL,
  `avg_response_time` int(11) DEFAULT NULL,
  `total_request` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=637370601 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_tms_ondem_save`
--

DROP TABLE IF EXISTS `tb_tms_ondem_save`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_tms_ondem_save` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `req_date` datetime DEFAULT NULL,
  `req_time` datetime DEFAULT NULL,
  `module_name` varchar(60) DEFAULT NULL,
  `api_method` varchar(60) DEFAULT NULL,
  `tms_node` tinyint(3) DEFAULT NULL,
  `avg_response_time` int(11) DEFAULT NULL,
  `total_request` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=59471243 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_tms_tmm`
--

DROP TABLE IF EXISTS `tb_tms_tmm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_tms_tmm` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ts` datetime DEFAULT NULL,
  `source_component` varchar(20) DEFAULT NULL,
  `api_method` varchar(60) DEFAULT NULL,
  `response_time` int(11) DEFAULT NULL,
  `tms_node` tinyint(3) DEFAULT NULL,
  `id_country` tinyint(3) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=27332818 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_vlm_requests`
--

DROP TABLE IF EXISTS `tb_vlm_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_vlm_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `ts` datetime DEFAULT NULL,
  `status_code` int(11) DEFAULT NULL,
  `http_method` varchar(10) DEFAULT NULL,
  `avg_resp_time` int(11) DEFAULT NULL,
  `total_request` int(11) DEFAULT NULL,
  `vlm_node` tinyint(3) DEFAULT NULL,
  `mode` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=2634977 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tb_wsp_requests`
--

DROP TABLE IF EXISTS `tb_wsp_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_wsp_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_country` tinyint(3) DEFAULT NULL,
  `req_date` datetime DEFAULT NULL,
  `req_time` datetime DEFAULT NULL,
  `thread_id` varchar(60) DEFAULT NULL,
  `ams_node` tinyint(3) DEFAULT NULL,
  `avg_response_time` int(11) DEFAULT NULL,
  `total_request` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=78262 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2016-02-18 11:18:10

#!/opt/nimbus/bin/perl
#################################################################
# CodeWizard:  perl 
# This code was generated with the NimBUS CodeWizard version 1.2.0
# Date: 18. mars 2003

use strict;
use Getopt::Std;
use Nimbus::API;
use Nimbus::Session;
use Nimbus::CFG;

my $prgname = "iostat";
my $sess;
my $version = "1.01";
my $config;
my %options;
my $loglevel = 0;
my $logfile  = "$prgname.log";
my $next_run = time();
my $interval = 300;
my $qosDefinition=0;
my $iostats = {};

###########################################################
# DoWork - function called by dispatcher on timeout
#
sub doWork {
    my $now = time();
    nimLog (2,"(doWork): $now < $next_run");
    return if ($now < $next_run);
    $next_run = $next_run + $interval;
    nimLog (1,"(doWork) - interval has passed");

	# Run for $interval - 5 seconds to get a good sample, but have 
	# enough time to send QoS etc before next run is expected.
	my $runtime = $interval - 5;
    open (IOS,"/usr/5bin/iostat -x $runtime 2 |") || die "Can't execute /usr/5bin/iostat";
    while (<IOS>) {
    	next if ($_ =~ /extended disk statistics/);   # Solaris 2.5++
    	next if ($_ =~ /extended device statistics/); # Solaris 2.8++
	next if ($_ =~ /disk .*/);                    # Solaris 2.5++
	next if ($_ =~ /device .*/);                  # Solaris 2.8++
	my ($d,$rs,$ws,$krs,$kws,$w,$act,$svc_t,$pw,$pb) = split(/\s+/,$_);
	nimLog (1,"Got: $d,$rs,$ws,$krs,$kws,$w,$act,$svc_t,$pw,$pb");
	if ($config->{setup}->{ignore} =~ /(^|\s)$d(\s|$)/) {
		nimLog(1,"Skipping disk $d");
		next;
	}
	$iostats->{$d}->{rs} 	= $rs;	
	$iostats->{$d}->{ws} 	= $ws;	
	$iostats->{$d}->{krs} 	= $krs;	
	$iostats->{$d}->{kws} 	= $kws;	
	$iostats->{$d}->{w} 	= $w;	
	$iostats->{$d}->{act} 	= $act;	
	$iostats->{$d}->{svc_t} = $svc_t;	
	$iostats->{$d}->{pw} 	= $pw;	
	$iostats->{$d}->{pb} 	= $pb;	
    }
    close(IOS);
    publishQoS($now);
}

###########################################################
# defineQoS - send the QoS definitions
#
sub defineQoS {
	if ($config->{setup}->{qos_rs} =~ /yes/i) {
		nimQoSDefinition("QOS_IOSTAT_RS",  "QOS_MACHINE", "Iostat Disk Reads Per Second", 
			"Reads/Sec","r/s",0,0);  
	}
	if ($config->{setup}->{qos_ws} =~ /yes/i) {
		nimQoSDefinition ("QOS_IOSTAT_WS", "QOS_MACHINE", "Iostat Disk Writes Per Second",
			"Writes/Sec","w/s",0,0); 
	}
	if ($config->{setup}->{qos_krs} =~ /yes/i) {
		nimQoSDefinition ( "QOS_IOSTAT_KRS", "QOS_MACHINE", "Iostat Kilobytes Read Per Second", 
			"Kilobytes/Sec","KB/s",0,0); 
	}
	if ($config->{setup}->{qos_kws} =~ /yes/i) {
		nimQoSDefinition ("QOS_IOSTAT_KWS", "QOS_MACHINE", "Iostat Kilobytes Written Per Second",
			"Kilobytes/Sec","KB/s",0,0); 
	}
	if ($config->{setup}->{qos_w} =~ /yes/i) {
		nimQoSDefinition ("QOS_IOSTAT_QLEN", "QOS_MACHINE", "Iostat Queue Length",
			"QueueLength","qlen",0,0); 
	}
	if ($config->{setup}->{qos_act} =~ /yes/i) {
		nimQoSDefinition ("QOS_IOSTAT_ACT", "QOS_MACHINE", "Iostat Active Transactions",
			"Transactions","trans",0,0);
	}
	if ($config->{setup}->{qos_svc_t} =~ /yes/i) {
		nimQoSDefinition ("QOS_IOSTAT_SVCT", "QOS_MACHINE", "Iostat Average Service Time",
			"Milliseconds","ms",0,0);
	}
	if ($config->{setup}->{qos_pw} =~ /yes/i) {
		nimQoSDefinition ("QOS_IOSTAT_PCTW", "QOS_MACHINE",
			"Iostat Percentage Of Time Waiting For Service", "Percent","%",1,0);
	}
	if ($config->{setup}->{qos_pb} =~ /yes/i) {
		nimQoSDefinition ("QOS_IOSTAT_PCTB", "QOS_MACHINE", "Iostat Percentage Of Time Busy", 
			"Percent","%",1,0);
	}
}

###########################################################
# publishQoS (target, value) - Create and publish QoS message
#
sub publishQoS {
	my $now 		= shift || time();
	my $source      = nimGetVarStr(NIMV_ROBOTNAME);
	my $ival        = $interval;                 # Seconds
	my $null 		= 987654321;

	if (!$qosDefinition) {
		#We only want to send the definition ONCE!
		defineQoS();
		$qosDefinition = 1;
	}
	foreach my $target (keys %$iostats) {
		nimLog(1,"Sending QoS for $target");
		if ($config->{setup}->{qos_rs} =~ /yes/i) {
   	    	if (not defined $iostats->{$target}->{rs}) {
				nimQoSMessage("QOS_IOSTAT_RS",$source,$target,$now,$null,0,$ival,-1);
   	    	}else {
				nimQoSMessage("QOS_IOSTAT_RS",$source,$target,$now,$iostats->{$target}->{rs},0,$ival,-1);
   	    	}
		}
		if ($config->{setup}->{qos_ws} =~ /yes/i) {
   	    	if (not defined $iostats->{$target}->{ws}) {
				nimQoSMessage("QOS_IOSTAT_WS",$source,$target,$now,$null,0,$ival,-1);
   	    	}else {
				nimQoSMessage("QOS_IOSTAT_WS",$source,$target,$now,$iostats->{$target}->{ws},0,$ival,-1);
   	    	}
		}
		if ($config->{setup}->{qos_krs} =~ /yes/i) {
   	    	if (not defined $iostats->{$target}->{krs}) {
				nimQoSMessage("QOS_IOSTAT_KRS",$source,$target,$now,$null,0,$ival,-1);
   	    	}else {
				nimQoSMessage("QOS_IOSTAT_KRS",$source,$target,$now,$iostats->{$target}->{krs},0,$ival,-1);
			}
		}
		if ($config->{setup}->{qos_kws} =~ /yes/i) {
   	    	if (not defined $iostats->{$target}->{kws}) {
				nimQoSMessage("QOS_IOSTAT_KWS",$source,$target,$now,$null,0,$ival,-1);
   	    	}else {
				nimQoSMessage("QOS_IOSTAT_KWS",$source,$target,$now,$iostats->{$target}->{kws},0,$ival,-1);
   	    	}
		}
		if ($config->{setup}->{qos_w} =~ /yes/i) {
   	    	if (not defined $iostats->{$target}->{w}) {
				nimQoSMessage("QOS_IOSTAT_QLEN",$source,$target,$now,$null,0,$ival,-1);
   	    	}else {
				nimQoSMessage("QOS_IOSTAT_QLEN",$source,$target,$now,$iostats->{$target}->{w},0,$ival,-1);
   	    	}
		}
		if ($config->{setup}->{qos_act} =~ /yes/i) {
   	    	if (not defined $iostats->{$target}->{act}) {
				nimQoSMessage("QOS_IOSTAT_ACT",$source,$target,$now,$null,0,$ival,-1);
   	    	}else {
				nimQoSMessage("QOS_IOSTAT_ACT",$source,$target,$now,$iostats->{$target}->{act},0,$ival,-1);
   	    	}
		}
		if ($config->{setup}->{qos_svc_t} =~ /yes/i) {
   	    	if (not defined $iostats->{$target}->{svc_t}) {
				nimQoSMessage("QOS_IOSTAT_SVCT",$source,$target,$now,$null,0,$ival,-1);
   	    	}else {
				nimQoSMessage("QOS_IOSTAT_SVCT",$source,$target,$now,$iostats->{$target}->{svc_t},0,$ival,-1);
   	    	}
		}
		if ($config->{setup}->{qos_pw} =~ /yes/i) {
			if (not defined $iostats->{$target}->{pw}) {
				nimQoSMessage("QOS_IOSTAT_PCTW",$source,$target,$now,$null,0,$ival,100);
			}else {
				nimQoSMessage("QOS_IOSTAT_PCTW",$source,$target,$now,$iostats->{$target}->{pw},0,$ival,100);
			}
		}
		if ($config->{setup}->{qos_pb} =~ /yes/i) {
			if (not defined $iostats->{$target}->{pb}) {
				nimQoSMessage("QOS_IOSTAT_PCTB",$source,$target,$now,$null,0,$ival,100);
			}else {
				nimQoSMessage("QOS_IOSTAT_PCTB",$source,$target,$now,$iostats->{$target}->{pb},0,$ival,100);
			}
		}
   	}
}

#######################################################################
# Service functions
#
sub restart {
    nimLog(1,"(restart) - got restarted");
    $config = Nimbus::CFG->new("$prgname.cfg");
    $loglevel = $options{d} || $config->{setup}->{loglevel}|| 0;
    $logfile  = $options{l} || $config->{setup}->{logfile} || "$prgname.log";
}

sub timeout {
    nimLog(2,"(timeout) - got kicked ");
    doWork();
}

###########################################################
# Signal handler - Ctrl-Break
#
sub ctrlc {
    exit;
}

###########################################################
# MAIN ENTRY
#
getopts("d:l:i:",\%options);
$SIG{INT} = \&ctrlc;
$config   = Nimbus::CFG->new("$prgname.cfg");
$loglevel = $options{d} || $config->{setup}->{loglevel}|| 0;
$logfile  = $options{l} || $config->{setup}->{logfile} || "$prgname.log";
$interval  = $options{i} || $config->{setup}->{interval}|| 300;

nimLogSet($logfile,$prgname,$loglevel,0);
nimLog(0,"----------------- Starting  (pid: $$) ------------------");

if ($interval < 10) {
	nimLog(0,"Error - minimum interval is 10 seconds!");
	exit(1);
}

$sess = Nimbus::Session->new("$prgname");
$sess->setInfo($version,"Nimbus Software AS");


if ($sess->server (NIMPORT_ANY,\&timeout,\&restart)==0) {
    nimLog(1,"server session is created");
}else {
    nimLog(0,"unable to create server session");
    exit(1);
}
$sess->dispatch(1000);

nimLog(0,"Received STOP, terminating program");
nimLog(0,"Exiting program");
exit;

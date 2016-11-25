#!/usr/bin/perl

use DBI;

sub getconf {
        %conf = ();
        open(F,"/usr/share/ocsinventory-reports/ocsreports/dbconfig.inc.php");
        while(<F>){
        	if($_ =~ /\(\"([A-Z\_]+)\",\s{0,}\"([a-zA-Z0-9]+)\"\)/){
			$conf{$1} = $2;
        	}
        }
        close(F);

        return %conf;
}


sub connectdb {
        my $c = shift;
        my %conf = %{$c};
        return DBI->connect("DBI:mysql:database=".$conf{DB_NAME}.";host=".$conf{SERVER_WRITE}, $conf{COMPTE_BASE}, $conf{PSWD_BASE}, {'RaiseError' => 0});
}


sub getanddelete {
        my $dbh = shift;

        my $sth = $dbh->prepare("SELECT ID,NAME FROM hardware WHERE LASTCOME < (NOW() - INTERVAL 5 DAY) ORDER BY LASTDATE");
        $sth->execute();
	$total = 0;
        while (my $ref = $sth->fetchrow_hashref()) {
                print "Deleting $ref->{'ID'} --> $ref->{'NAME'}\n";
		$total++;
		deleteDid($ref->{'ID'})
        }
	print "TOTAL: $total\n";
        $sth->finish();
        $dbh->disconnect();
}

sub deleteDid {
	my $id = shift;
	$traceDel = true;

	my $sth = $dbh->prepare("SELECT deviceid FROM hardware WHERE ID = ? ");
	$sth->execute($id);
	my $ref = $sth->fetchrow_hashref();
	my $device_id = $ref->{'deviceid'};

	if( $device_id ) {
		if ($device_id !~ /NETWORK_DEVICE-/){
			my $sth = $dbh->prepare("SELECT macaddr FROM networks WHERE hardware_id = ? ");
			$sth->execute($id);
			while (my $ref = $sth->fetchrow_hashref()) {
				$dbh->do("DELETE FROM netmap WHERE mac = ? ", undef, $ref->{'macaddr'});
			}
		}
		if( $device_id !~ /_SYSTEMGROUP_/ and $device_id !~ /_DOWNLOADGROUP_/) {
			@tables = ("accesslog", "batteries", "bios", "controllers", "cpus", "download", "drives", "groups", "inputs", "itmgmt", "javainfo", "journallog", "locks", "memories", "modems", "monitors", "networks", "ports", "printers", "registry", "sim", "slots", "softwares", "sounds", "storages", "videos", "virtualmachines");
		} elsif ($device_id =~ /_SYSTEMGROUP_/ or $device_id =~ /_DOWNLOADGROUP_/){
			@tables = ("devices");
			$dbh->do("DELETE FROM config WHERE name like ? and ivalue = ? ", undef, "GUI_REPORT_MSG%", $id);
			$dbh->do("DELETE FROM groups WHERE hardware_id = ? ", undef, $id);
			$dbh->do("DELETE FROM groups_cache WHERE group_id = ? ", undef, $id);
			$dbh->do("DELETE FROM download_servers WHERE group_id = ? ", undef, $id);
		}
		foreach my $table (@tables) {
			$dbh->do("DELETE FROM $table WHERE hardware_id = ? ", undef, $id);
		}
		$dbh->do("DELETE FROM download_enable where SERVER_ID = ? ", undef, $id);
		$dbh->do("DELETE FROM hardware WHERE id = ? ", undef, $id);
		$dbh->do("INSERT INTO deleted_equiv(DELETED,EQUIVALENT) values( ?, ?)", undef, $device_id, 'NULL');
	}
}
open my $log_fh, '>>', '/dev/null';
*STDOUT = $log_fh;
*STDERR = $log_fh;

%conf = getconf();
$dbh = connectdb(\%conf);
getanddelete($dbh);

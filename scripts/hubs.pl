#!/usr/bin/env perl

use 5.10.0;
use strict;
use warnings;
use Readonly;
use Carp;
use autodie qw(:all);
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use JSON;
use Perl6::Slurp;
use List::Util qw( first );
use File::Spec qw(cat_file);
use File::Path qw(make_path);
use File::Copy;
use Data::Dumper;

use aliased 'Bio::EnsEMBL::TrackHub::Hub';
use aliased 'Bio::EnsEMBL::TrackHub::Hub::Genome';
use aliased 'Bio::EnsEMBL::TrackHub::Hub::Track';
use aliased 'Bio::EnsEMBL::TrackHub::Hub::SuperTrack';
use aliased 'Bio::EnsEMBL::TrackHub::Registry';

use Bio::EnsEMBL::RNAseqDB;
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

# Connect to the database schema
my $db = Bio::EnsEMBL::RNAseqDB->connect(
  "dbi:mysql:host=$opt{host}:port=$opt{port}:database=$opt{db}",
  $opt{user},
  $opt{password}
);

# Retrieve the data (but only if we need it)
my ($groups, $hubs);

my $antispecies = $opt{antispecies} ? [split /,/, $opt{antispecies}] : [];

if (
       $opt{create}
    or $opt{register}
    or $opt{update}
    or $opt{delete}
    or $opt{public_hubs}
    or $opt{private_hubs}
    or $opt{list_db}
    or $opt{list_diff}
) {
  $logger->info("Retrieving the track bundles...");
  $groups = $db->get_bundles({
      species     => $opt{species},
      antispecies => $antispecies,
      files_url   => $opt{files_url},
    });

  # Create trackhub objects
  $hubs = prepare_hubs($groups, \%opt);
}

my $registry;
if ($opt{reg_user} and $opt{reg_pass}) {
  $registry = Registry->new(
    user     => $opt{reg_user},
    password => $opt{reg_pass},
  );
}

# Perform actions
create_hubs($hubs)  if $opt{create};
list_db_hubs($hubs) if $opt{list_db};
if ($registry) {
    $registry->is_public(1) if $opt{public_hubs};
    $registry->is_public(0) if $opt{private_hubs};
  if ($opt{register}) {
    # Only register new hubs
    my @reg_hubs_ids = $registry->get_registered_ids();
    my %reg_hubs     = map { $_ => 1 } @reg_hubs_ids;
    my @new_hubs     = grep { not $reg_hubs{$_->id} } @$hubs;
    if (@new_hubs > 0) {
        $logger->info((@new_hubs+0)." new hubs to register");
        $registry->register_track_hubs(@new_hubs);
    } else {
        $logger->info("No new hubs to register");
    }
  }
  if ($opt{update}) {
      # Register all
      $registry->register_track_hubs(@$hubs);
  }
  delete_hubs($registry, $hubs, \%opt) if $opt{delete};
  
  list_reg_hubs($registry, $opt{species}) if $opt{list_registry};
  diff_hubs($registry, $hubs, $opt{species})   if $opt{list_diff};
}

###############################################################################
# SUB
# Trackhubs creation
sub prepare_hubs {
  my ($groups, $opt) = @_;
  my $dir    = $opt->{hub_root};
  
  if ($opt{create}) {
    croak "Need directory where the hubs would be placed" if not defined $dir;
    croak "Email needed" if not $opt->{email};
  } else {
    # Don't care about these options if we don't create the files
    $dir //= '.';
    $opt->{email} //= 'dummy@dummy.com';
  }
  
  my @hubs;
  GROUP: for my $group (@$groups) {
    if (not $group->{assemblies}) {
      print STDERR "No Assembly information for hub $group->{trackhub_id}\n";
      next GROUP;
    }
    
    # Create the TrackHub
    my $hub = Hub->new(
      id          => $group->{trackhub_id},
      shortLabel  => $group->{label} // $group->{id},
      longLabel   => $group->{description} // $group->{label} // $group->{id},
      email       => $opt{email},
    );
    
    # Set the server for this hub to create a valid path to the hub.txt
    my $server = $opt->{hub_server};
    if ($server) {
      $server .= '/' . $group->{production_name};
      $hub->server_dir($server);
    }
    
    my $species_dir = $dir . '/' . $group->{production_name};
    make_path $species_dir if $opt{create};
    $hub->root_dir( $species_dir );
    
    # Add each assembly
    for my $assembly_id (keys %{ $group->{assemblies} }) {
      my $assembly = $group->{assemblies}->{$assembly_id};
      
      # Create the associated genome
      my $genome = Genome->new(
        id    => $assembly_id,
        insdc => $assembly->{accession},
      );
      
      # Add all tracks to the genome
      my @big_tracks;
      my @bam_tracks;
      my $num = 0;
      TRACK: for my $track (sort by_numbered_title @{ $group->{tracks} }) {
          #TRACK: for my $track (@{ $group->{tracks} }) {
        $num++;
        
        # Get the bigwig file
        my $bigwig = get_file($track, 'bigwig', $assembly_id);
        if (not $bigwig) {
          warn "No bigwig file for this track $track->{id}";
          next TRACK;
        }

        my $big_track = Track->new(
          track       => sprintf("%03d_%s.%s", $num, $track->{id}, 'bigwig'),
          shortLabel  => ($track->{title} // $track->{id}),
          longLabel   => ($track->{description} // $track->{id}),
          bigDataUrl  => $bigwig->{url},
          type        => 'bigWig',
          visibility  => 'full',
        );

        push @big_tracks, $big_track;

        # Get the bam file
        my $bam = get_file($track, 'bam', $assembly_id);
        if (not $bam) {
          warn "No bam file for this track $track->{id}";
          next TRACK;
        }

        my $bam_track = Track->new(
          track       => sprintf("%03d_%s.%s", $num, $track->{id}, 'bam'),
          shortLabel  => ($track->{title} // $track->{id}),
          longLabel   => ($track->{description} // $track->{id}),
          bigDataUrl  => $bam->{url},
          type        => 'bam',
          visibility  => 'hide',
        );

        push @bam_tracks, $bam_track;
      }

      if (@big_tracks == 0) {
        $logger->warn("No track can be used for this group $group->{id}: skip");
        next GROUP;
        #} elsif (@big_tracks == 1) {
        #$genome->add_track($big_tracks[0]);
        #$genome->add_track($bam_tracks[0]);
      } else {
        my $superbig = SuperTrack->new(
          track      => $hub->{id} . '_bigwig',
          shortLabel => 'Signal density (bigwig)',
          longLabel  => 'Signal density (bigwig)',
          type       => 'bigWig',
          show       => 1,
        );
        my $superbam = SuperTrack->new(
          track      => $hub->{id} . '_bam',
          shortLabel => 'Reads (bam)',
          longLabel  => 'Reads (bam)',
          type       => 'bam',
          show       => 0,
        );
        # Put all that in a supertrack
        my $n = 0;
        for my $big (@big_tracks) {
          $big->visibility('hide') if $n >= 10;
          $superbig->add_sub_track($big);
          $n++;
        }
        for my $bam (@bam_tracks) {
          $superbam->add_sub_track($bam);
        }
        $genome->add_track($superbig);
        $genome->add_track($superbam);
      }

      # Add the genome...
      if (keys %{$genome->tracks} > 0) {
        $hub->add_genome($genome);
      } else {
        $logger->warn("Genome ".$genome->id." has no track. Don't add it to the hub.");
      }
    }
    
    # And create the trackhub files
    if (keys %{$hub->genomes} > 0) {
      push @hubs, $hub;
      } else {
        $logger->warn("Hub ".$hub->id." has no genomes. Don't create it.");
    }
  }
  return \@hubs;
}

sub by_numbered_title {
    my $atitle = $a->{title} // $a->{id};
    my $btitle = $b->{title} // $b->{id};
    $atitle =~ s/(\d+?)(th|rd|st)/$1/g;
    my ($apref, $anum, $asuf ) = $atitle =~ /^(\D*)(\d+)(?:-\d+)?(.*$)/;
    my ($bpref, $bnum, $bsuf ) = $btitle =~ /^(\D*)(\d+)(?:-\d+)?(.*$)/;
    $apref = '' if not $apref;
    $bpref = '' if not $bpref;
    $asuf  = '' if not $asuf;
    $bsuf  = '' if not $bsuf;
    
    if ($anum and $bnum) {
        if ($apref eq $bpref and
            $asuf  eq $bsuf) {
            $anum <=> $bnum;
        } else {
            "$apref $asuf" cmp "$bpref $bsuf";
        }
    } else {
        $atitle cmp $btitle;
    }
}

sub get_file {
  my ($track, $type, $assembly_id) = @_;
  
  croak("No type of file given for this track") if not defined $type;
  croak("No assembly_id to get file from for this track") if not defined $assembly_id;
  
  my $files = $track->{assemblies}->{$assembly_id}->{files};
  for my $file (@$files) {
    if ($file->{type} eq $type) {
      return $file;
    }
  }
  return;
}

sub create_hubs {
  my ($hubs) = @_;
  
  my $num_hubs = @$hubs;
  $logger->info("Creating files for $num_hubs track hubs");
  for my $hub (@$hubs) {
    $hub->create_files;
  }
}

sub delete_hubs {
  my ($registry, $hubs, $opt) = @_;
  
  if ($opt->{species}) {
    my $n = @$hubs;
    $logger->info("Deleting $n track hubs for species $opt->{species}");
    $registry->delete_track_hubs(@$hubs);
  } else {
    $logger->info("Deleting all track hubs in the registry");
    $registry->delete_all_track_hubs;
  }
}

sub toggle_hubs {
  my ($hubs, $opt) = @_;
  
  my $public = $opt{public_hubs} ? 1 : 1;
  for my $hub (@$hubs) {
    $hub->public($public);
    $hub->update($opt{user}, $opt{password});
  }
}

sub get_list_db_hubs {
  my ($hubs) = @_;
  
  my @hub_ids;
  foreach my $hub (@$hubs) {
    push @hub_ids, $hub->id;
  }
  return @hub_ids;
}

sub list_db_hubs {
  my ($hubs) = @_;
  
  my @db_hubs = get_list_db_hubs($hubs);
  my $num_hubs = @db_hubs;
  print "$num_hubs track hubs in the RNAseqDB\n";
  for my $hub_id (@db_hubs) {
    print "$hub_id\n";
  }
}

sub list_reg_hubs {
  my ($registry, $species) = @_;
  
  my @reg_hubs = $registry->get_registered();
  @reg_hubs = grep { $_->{url} =~ /$species\// } @reg_hubs if $species;
  my $num_hubs = @reg_hubs;
  print "$num_hubs track hubs registered\n";
  for my $hub (@reg_hubs) {
    print "$hub->{name} = $hub->{shortLabel}\n";
  }
}

sub diff_hubs {
  my ($registry, $hubs, $species) = @_;
  
  my @db_hubs  = get_list_db_hubs($hubs);
  my @reg_hubs = $registry->get_registered();
  @reg_hubs = grep { $_->{url} =~ /$species\// } @reg_hubs if $species;
  
  my %db_hub_hash  = map { $_ => 1 } @db_hubs;
  my %reg_hub_hash = map { $_->{name} => 1 } @reg_hubs;
  my @common;
  for my $reg_hub_id (keys %reg_hub_hash) {
    if (exists $db_hub_hash{$reg_hub_id}) {
      push @common, $reg_hub_id;
      delete $reg_hub_hash{$reg_hub_id};
      delete $db_hub_hash{$reg_hub_id};
    }
  }
  
  # Print summary
  my @db_only  = sort keys %db_hub_hash;
  my @reg_only = sort keys %reg_hub_hash;
  print sprintf "%d trackhubs from the RNAseq DB are registered\n", ''.@common;
  print sprintf "%d trackhubs are only in the RNAseq DB\n", ''.@db_only if @db_only > 0;
  print sprintf "%d trackhubs are only in the Registry\n", ''.@reg_only if @reg_only > 0;
  
  for my $hub_id (@db_only) {
    print "Only in the RNAseqDB: $hub_id\n";
  }
  for my $hub_id (@reg_only) {
    print "Only in the Registry: $hub_id\n";
  }
}

###############################################################################
# Parameters and usage
# Print a simple usage note
sub usage {
  my $error = shift;
  my $help = '';
  if ($error) {
    $help = "[ $error ]\n";
  }
  $help .= <<'EOF';
    This script creates and registers track hubs from an RNAseqDB.

    RNASEQDB CONNECTION
    --host    <str>   : host name
    --port    <int>   : port
    --user    <str>   : user name
    --password <str>  : password
    --db <str>        : database name
    
    
    TRACK HUBS
    -files_url        : root dir to use for the files paths
                        (used in the Trackdb.txt files)
    --hub_root <path> : root where the trackhubs should be stored
    
    
    ACTIONS (at least one of them is needed)
    
    Create:
    --create          : create the hub files
    --email           : email for the track hubs [mandatory]
    
    Register:
    --register        : register any new track hub
                        (the hub files must exist)
    --update          : register or update all track hubs
    --hub_server <str>: http/ftp address to the root of the hub files
    --reg_user <str>  : Track Hub Registry user name
    --reg_pass <str>  : Track Hub Registry password
    
    Delete:
    --delete          : delete all trackhubs from the registry
                        (not the files themselves)
    
    Show/hide:
    --public_hubs     : set all tracks as public
                        (can be searched in the Registry)
    --private_hubs    : set all tracks as private
                        (can't be searched in the Registry)
    
    NB: by default all track hubs are registered as private
    
    List:
    --list_db         : list the trackhubs from the RNAseqDB
    --list_registry   : list the trackhubs from the Registry
    --list_diff       : compare the trackhubs from the RNAseqDB
                        and from the Registry
    
    OTHER
    --species <str>   : only outputs tracks for a given species
                        (production_name)
    --help            : show this help message
    --verbose         : show detailed progress
    --debug           : show even more information
                        (for debugging purposes)
EOF
  print STDERR "$help\n";
  exit(1);
}

# Get the command-line arguments and check for the mandatory ones
sub opt_check {
  my %opt = ();
  GetOptions(\%opt,
    "host=s",
    "port=i",
    "user=s",
    "password=s",
    "db=s",
    "registry=s",
    "species=s",
    "antispecies=s",
    "files_url=s",
    "hub_root=s",
    "email=s",
    "create",
    "register",
    "update",
    "reg_user=s",
    "reg_pass=s",
    "hub_server=s",
    "delete",
    "public_hubs",
    "private_hubs",
    "list_db",
    "list_registry",
    "list_diff",
    "help",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Need --host")   if not $opt{host};
  usage("Need --port")   if not $opt{port};
  usage("Need --user")   if not $opt{user};
  usage("Need --db")     if not $opt{db};
  usage("Need --hub_root") if $opt{create} and not $opt{hub_root};
  $opt{password} //= '';
  usage("Need registry user and password") if ($opt{register} or $opt{update} or $opt{delete} or $opt{public_hubs} or $opt{private_hubs} or $opt{list_registry} or $opt{list_diff}) and not ($opt{reg_user} and $opt{reg_pass});
  usage("Need hub server") if ($opt{register} or $opt{update}) and not $opt{hub_server};
  usage("Select public XOR private") if ($opt{public_hubs} and $opt{private_hubs});
  usage("Select --register with public/private") if ($opt{public_hubs} or $opt{private_hubs}) and not ($opt{register} xor $opt{update});
  usage("Select an action") if not ($opt{create} or $opt{register} or $opt{update} or $opt{delete} or $opt{list_db} or $opt{list_registry} or $opt{list_diff});
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__


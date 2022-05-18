#!/usr/bin/perl

# read in output of lepto simulation, recast it in a form
# suitable for GEMC input (LUND format)
# DISCLAIMER: This script does not properly process the case when a string is produced. This does not affect the measurable particles.

# Author        : William K. Brooks
# Maintained by : Andrés Bórquez (August 2021)
# Mod by        : Esteban Molina (May 2022)

$skip = 1;
$num = 0;

@event_array;

($z_shift) = @ARGV;

store_pdg();

my $nargs = @ARGV;
if($nargs == 0){
    printf "No args passed!\n";
    printf "Usage (Prints directly to screen):\n";
    printf "perl leptoLund.pl z_shift < original_lepto.out \n";    
    
    exit;
}
    

while (<STDIN>) { # read in a line from stdin
    chomp;
    @field = split(/ +/); # split line on spaces

    # skip top part of file completely; until finding "Event listing"
    # we are only using the particle kinematic information, event-by-event
    if ($field[1] eq "Event" && $field[2] eq "listing") { # We are 3 lines above the particle data for an event, get ready to analyze it.
	$skip = 0;
    }

    if ($skip == 0) {
	# still on same event, but past the first line
	if ($field[1] ne "I" && $field[1] ne "sum:" && $field[1] > 0) {
	    # create array with info of particle[index, KS, pid, orig, energy, p_x, p_y, p_z]
	    if ($field[3] eq "A" || $field[3] eq "V") { # these letters move all fields in one index
		$new_particle = [$field[1], $field[4], $field[5], $field[6], $field[10], $field[7], $field[8], $field[9]];
	    } else {
		$new_particle = [$field[1], $field[3], $field[4], $field[5], $field[9], $field[6], $field[7], $field[8]];
	    }
	    # count only final-state particles
	    if ($field[3] == 1) {
		$num++;
	    }
	    # fill particle info in event array
	    push(@event_array, $new_particle);
	}
	# finished the event, print and reset array
	if ($field[1] eq "sum:") {
	    $skip = 1;
	    $index = 0;
	    # Print LUND header
	    # Used by gemc : Number of particles -> 1st arg
	    #                Beam Polarization   -> 5th arg    
	    printf "$num 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0\n";
	    for $particle (@event_array) {
		# select only final-state particles
		if ($particle->[1] == 1) {
		    # determine pid of parent particle from orig
		    $parent_id = 0;
		    find_parent_id($particle->[3]);
		    # set vertex positions
		    $x = 0.;
		    $y = 0.;
		    $z = 0. - $z_shift;

		    # Print LUND particles
		    #                     Name              Position
		    # Used by gemc : index                     1st
		    #                type(1 is active)         3rd
		    #                particle ID (pdg)         4th
		    #                px                        7th
		    #                py                        8th
		    #                pz                        9th
		    #                x                         12th
		    #                y                         13th
		    #                z                         14th
		    #________________________________________________
		    # Optionals    : Lifetime                  2nd
		    #                Index of parent           5th
		    #                Index of first daughter   6th
		    #                Energy of particle Gev    10th
		    #                Mass of the particle GeV  11th

		    printf "%4d "   , $index;           # index  
		    printf "0.0 "   ;                   # lifetime
		    printf "1 "     ;                   # type
		    printf "%4d "   , $particle->[1];   # PDG
		    printf "%4d "   , $parent_id;       # parent index
		    printf "%4d "   , 0;                # 1st daughter index
		    printf "%9.7f " , $particle->[5];   # px
		    printf "%9.7f " , $particle->[6];   # py
		    printf "%9.7f " , $particle->[7];   # pz
		    printf "%9.7f " , $particle->[4];   # E
		    printf "0.0 "   ;                   # m
		    printf "%9.7f " , $x;               # x
		    printf "%9.7f " , $y;               # y
		    printf "%9.7f\n", $z;               # z

		    ++$index;
		}
	    }
	    @event_array = (); # empty array
	    $num = 0; # reset counter of final-state particles
	}
    }
} # end of main loop

sub find_parent_id() {
    # find parent id up to 2 consecutive decays
    # last decay
    $orig = $_[0]; # index of parent particle
    # (reminder) particle[index, KS, pid, orig, energy, p_x, p_y, p_z]
    $parent_KS = $event_array[$orig - 1][1]; # stability (KS) of parent particle
    $parent_id = $event_array[$orig - 1][2]; # pid of parent particle
    # exclude strings, clusters or particles with KS different than 11
    if ($parent_KS != 11 || $parent_id == 91 || $gparent_id == 92) {
	$parent_id = 0;
    }
    # second to last decay
    $gparent_index = $event_array[$orig - 1][3]; # orig of parent particle ("grand-parent particle")
    $gparent_KS = $event_array[$gparent_index - 1][1]; # stability (KS) of grand-parent particle
    $gparent_id = $event_array[$gparent_index - 1][2]; # pid of grand-parent particle
    # exclude strings, clusters or particles with KS different than 11
    if ($gparent_KS != 11 || $gparent_id == 91 || $gparent_id == 92) {
	$gparent_id = 0;
    }
    # if there was a "valid" grand-parent id, return that one instead
    if ($gparent_id != 0) {
	$parent_id = $gparent_id;
    }
}

sub get_geant() {
    $pid = $_[0]; # pid of particle, according to pdg
    for ($j = 1; j <= 45; $j++) {
	if ($pid == $pdg[$j]) {
	    $geant_id = $j;
	    last; # break loop
	}
    }
}

sub store_pdg() {
    # adapted from eliott's code in clas_utils, which he stole from cernlib
    $pdg[1]  = 22;
    $pdg[2]  = -11;
    $pdg[3]  = 11;
    $pdg[4]  = 12;
    $pdg[5]  = -13;
    $pdg[6]  = 13;
    $pdg[7]  = 111;
    $pdg[8]  = 211;
    $pdg[9]  = -211;
    $pdg[10] = 130;
    $pdg[11] = 321;
    $pdg[12] = -321;
    $pdg[13] = 2112;
    $pdg[14] = 2212;
    $pdg[15] = -2212;
    $pdg[16] = 310;
    $pdg[17] = 221;
    $pdg[18] = 3122;
    $pdg[19] = 3222;
    $pdg[20] = 3212;
    $pdg[21] = 3112;
    $pdg[22] = 3322;
    $pdg[23] = 3312;
    $pdg[24] = 3334;
    $pdg[25] = -2112;
    $pdg[26] = -3122;
    $pdg[27] = -3112;
    $pdg[28] = -3212;
    $pdg[29] = -3222;
    $pdg[30] = -3322;
    $pdg[31] = -3312;
    $pdg[32] = -3334;
    $pdg[33] = -15;
    $pdg[34] = 15;
    $pdg[35] = 411;
    $pdg[36] = -411;
    $pdg[37] = 421;
    $pdg[38] = -421;
    $pdg[39] = 431;
    $pdg[40] = -431;
    $pdg[41] = 4122;
    $pdg[42] = 24;
    $pdg[43] = -24;
    $pdg[44] = 23;
    $pdg[45] = 223;
}

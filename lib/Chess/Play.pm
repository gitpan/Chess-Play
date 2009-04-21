package Chess::Play;

use strict;
use warnings;

our $VERSION = '0.01';

use constant IL => 99;
use constant EM => 0;
use constant WP => 1;
use constant WN => 2;
use constant WB => 3;
use constant WR => 4;
use constant WQ => 5;
use constant WK => 6;
use constant BP => -1;
use constant BN => -2;
use constant BB => -3;
use constant BR => -4;
use constant BQ => -5;
use constant BK => -6;

use constant P_VAL => 1;
use constant N_VAL => 3;
use constant B_VAL => 3;
use constant R_VAL => 5;
use constant Q_VAL => 9;

use constant WHITE => 1;
use constant BLACK => -1;

use constant MOVES_50_THR => 99;
use constant CHECKMATE => 99;
use constant AB_CNST => 200;
use constant MAX_PIECE_VALUE => 15;

use constant INVALID_MOVE => -1;
use constant ILLEGAL_MOVE => -2;
use constant LEGAL_MOVE => 1;

# ------------------------- METHODS -------------------------
# Basic methods
sub new {
	my $class = shift;
	my $self = {};

	$self->{BOARD} = [];
	$self->{LAST_DOUBLE_MOVE} = [];
	$self->{MOVED} = {};
	$self->{UNDER_CHECK} = {};
	$self->{RULE_50_MOVES} = undef;
	$self->{PIECE_VAL} = {};
	$self->{DEPTH} = undef;
	$self->{COLOR_TO_MOVE} = undef;

	bless ($self, $class);
	return $self;
}

sub reset {
	my $self = shift;

	$self->{BOARD} = [ IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, 
		   	   IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, 
		   	   IL, IL, WR, WN, WB, WQ, WK, WB, WN, WR, IL, IL,
	           	   IL, IL, WP, WP, WP, WP, WP, WP, WP, WP, IL, IL,
		   	   IL, IL, EM, EM, EM, EM, EM, EM, EM, EM, IL, IL,
		   	   IL, IL, EM, EM, EM, EM, EM, EM, EM, EM, IL, IL,
		   	   IL, IL, EM, EM, EM, EM, EM, EM, EM, EM, IL, IL,
		   	   IL, IL, EM, EM, EM, EM, EM, EM, EM, EM, IL, IL,
		   	   IL, IL, BP, BP, BP, BP, BP, BP, BP, BP, IL, IL,
		   	   IL, IL, BR, BN, BB, BQ, BK, BB, BN, BR, IL, IL,
		   	   IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, 
		   	   IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, IL, IL ];

	$self->{LAST_DOUBLE_MOVE} = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];

	$self->{MOVED} = {
		W_LR => 0,	# white left rook
		W_RR => 0,	# white right rook
		W_K => 0,	# white king
		B_LR => 0,	# black left rook
		B_RR => 0,	# black right rook
		B_K => 0,	# black king
	};

	$self->{UNDER_CHECK} = {
		W_K => 0,
		B_K => 0,
	};

	$self->{RULE_50_MOVES} = 0;

	$self->{PIECE_VAL}{+WP} = $self->{PIECE_VAL}{+BP} = P_VAL;
	$self->{PIECE_VAL}{+WN} = $self->{PIECE_VAL}{+BN} = N_VAL;
	$self->{PIECE_VAL}{+WB} = $self->{PIECE_VAL}{+BB} = B_VAL;
	$self->{PIECE_VAL}{+WR} = $self->{PIECE_VAL}{+BR} = R_VAL;
	$self->{PIECE_VAL}{+WQ} = $self->{PIECE_VAL}{+BQ} = Q_VAL;

	$self->{COLOR_TO_MOVE} = WHITE;
}

sub set_piece_val {
	die "set_piece_val: wrong number of parameters" if (@_ != 6);

	my ($self, $p_val, $n_val, $b_val, $r_val, $q_val) = @_;

	if ( (($p_val <= 0) or ($p_val > MAX_PIECE_VALUE)) or
		(($n_val <= 0) or ($n_val > MAX_PIECE_VALUE)) or
		(($b_val <= 0) or ($b_val > MAX_PIECE_VALUE)) or
		(($r_val <= 0) or ($r_val > MAX_PIECE_VALUE)) or
		(($q_val <= 0) or ($q_val > MAX_PIECE_VALUE)) ) {
		die ("set_piece_val: Values must be between 0 and " . MAX_PIECE_VALUE);
	}

	$self->{PIECE_VAL}{+WP} = $self->{PIECE_VAL}{+BP} = $p_val;
	$self->{PIECE_VAL}{+WN} = $self->{PIECE_VAL}{+BN} = $n_val;
	$self->{PIECE_VAL}{+WB} = $self->{PIECE_VAL}{+BB} = $b_val;
	$self->{PIECE_VAL}{+WR} = $self->{PIECE_VAL}{+BR} = $r_val;
	$self->{PIECE_VAL}{+WQ} = $self->{PIECE_VAL}{+BQ} = $q_val;
}

sub set_depth {
	my ($self, $depth) = @_;

	$self->{DEPTH} = $depth;
}

sub legal_moves {
	my $self = shift;

	my @legal_moves = $self->generate_legal_moves($self->{COLOR_TO_MOVE});
	foreach my $lm(@legal_moves) {
		$lm = move_to_coord($lm);
	}
	sort @legal_moves;
}

sub do_move {
	my ($self, $move) = @_;

	if (not ($move =~ /^[a-h][1-8][a-h][1-8](n|b|r|q)?$/)) {
		return INVALID_MOVE;
	}

	my @legal_moves = $self->legal_moves();
	my $is_legal = 0;
	foreach my $lm(@legal_moves) {
		if ($move eq $lm) {
			$is_legal = 1;
			last;
		}
	}
	return ILLEGAL_MOVE if (not $is_legal);

	$self->execute_move(coord_to_move($move));
	return LEGAL_MOVE;
}

sub game_over {
	my $self = shift;

	if ( $self->insuff_material() ) {
		return "1/2-1/2 {insufficient material}";
	}
	if ( $self->rule50moves() ) {
		return "1/2-1/2 {50 moves rule}";
	}

	my @legal_moves = $self->legal_moves();
	if (@legal_moves) {
		return "";
	}
	elsif ($self->{UNDER_CHECK}{W_K}) {
		return "0-1";
	}
	elsif ($self->{UNDER_CHECK}{B_K}) {
		return "1-0";
	}
	else {
		return "1/2-1/2 {Stalemate}";
	}
}

sub best_move {
	my $self = shift;

	my ($evaluation, $bestmove);

	if ($self->{DEPTH} == 0) {					#RANDOM MOVE
		my @legal_moves = $self->legal_moves();
		my $nb_legal_moves = @legal_moves;
		$bestmove = $legal_moves[int(rand($nb_legal_moves))];
		$bestmove = coord_to_move($bestmove);
	}
	else {
		$evaluation = $self->alphabeta_search($self->{DEPTH}, -(AB_CNST), AB_CNST, -$self->{COLOR_TO_MOVE}, \$bestmove);
	}

	return move_to_coord($bestmove);
}

sub play {
	my $self = shift;

	my $answer = "";
	while ($answer ne "N") {
		$answer = $self->play_one_game();
	}
}

sub xboard_play {
	my $self = shift;
	my $engine_name = shift || "My Chess::Play Engine";

	my ($first_move_done, $white_to_move, $force, $cont);

	while (my $line = <STDIN>) {
		chomp($line);
		if ($line eq "xboard") {
			print STDERR "\n";
		}
		elsif ($line eq "protover 2") {
			print STDERR "Chess\n";
			print STDERR "feature setboard=1 sigint=0 variants=\"normal\" draw=1 reuse=1 myname=\"${engine_name}\" done=1\n"
		}
		elsif ($line eq "new") {
			$first_move_done = 0;
			$white_to_move = 1;
			$force = 0;	#not in force mode
			$self->reset();
			$cont = 0;
		}
		elsif ($line eq "force") {
			$force = 1;
		}
		elsif ($line eq "quit") {
			exit;
		}
		elsif ($line eq "white") {
			$white_to_move = 1;
		}
		elsif ($line eq "black") {
			$white_to_move = 0;
		}
		elsif ($line eq "go") {
			$force = 0;
			$cont++;
			if ($white_to_move) {
				$self->white_move();
			}
			else {
				$self->black_move();
			}
			$first_move_done = 1;
		}
		elsif ($line =~ /[a-h][1-8][a-h][1-8]/) {
			$self->execute_move(coord_to_move($line));

			if (not $first_move_done) {
				$white_to_move = 0;
				$first_move_done = 1;
			}
			if (not $force) {
				$cont++;
				if ($white_to_move) {
					$self->white_move();
				}
				else {
					$self->black_move();
				}
			}
		}
	}
}

# Other methods
sub count_material {
	my $self = shift;

	my ($r, $c, $sq);
	my %count_material;

	$count_material{+WR} = 0;
	$count_material{+WN} = 0;
	$count_material{+WB} = 0;
	$count_material{+WP} = 0;
	$count_material{+WQ} = 0;
	$count_material{+WK} = 0;
	$count_material{+BR} = 0;
	$count_material{+BN} = 0;
	$count_material{+BB} = 0;
	$count_material{+BP} = 0;
	$count_material{+BQ} = 0;
	$count_material{+BK} = 0;

	for ($r = 7; $r >= 0; $r--) {
		for ($c = 0; $c <= 7; $c++) {
			$sq = 12 * ($r + 2) + 2 + $c;
			$count_material{$self->{BOARD}[$sq]}++ if ($self->{BOARD}[$sq] != EM);
		}
	}

	\%count_material;
}

sub insuff_material {					# to improve
	my $self = shift;

	my $ref_count_material = $self->count_material();
	my %count_material = %{$ref_count_material};

	my $w_insuff = 0;
	my $b_insuff = 0;

	#foreach my $cle(keys %count_material) {
	#	print "$cle	$count_material{$cle}\n";
	#}

	if ( ($count_material{+WP} + $count_material{+WR} + $count_material{+WQ}) == 0 ) {
		$w_insuff = 1 if ( ($count_material{+WB} + $count_material{+WN}) <= 1 );
	}
	if ( ($count_material{+BP} + $count_material{+BR} + $count_material{+BQ}) == 0 ) {
		$b_insuff = 1 if ( ($count_material{+BB} + $count_material{+BN}) <= 1 );
	}

	return ($w_insuff and $b_insuff);
}


sub rule50moves {
	my $self = shift;

	if ($self->{RULE_50_MOVES} == MOVES_50_THR) {
		return 1;
	}
	return 0;
}

sub print_board {
	my $self = shift;

	my ($r, $c, $sq);
	for ($r = 7; $r >= 0; $r--) {
		for ($c = 0; $c <= 7; $c++) {
			$sq = 12 * ($r + 2) + 2 + $c;
			my $str = value_to_string($self->{BOARD}[$sq]);
			print "$str ";
		}
		print "\n";
	}
}

sub knight_mvs {
	my $self = shift;

	my $val = shift;
	my $orig_square = shift;
	my $dest_square;

	my @knight_mv = ();

	my @diffs = ( -25, -23, -14, -10, 10, 14, 23, 25 );
	foreach my $diff(@diffs) {
		$dest_square = $orig_square + $diff;
		next if ($self->{BOARD}[$dest_square] == IL);
		if (($val * $self->{BOARD}[$dest_square]) <= 0) {		#enemy piece or empty square
			push @knight_mv, "$orig_square $dest_square";
		}
	}
	@knight_mv;
}

sub bishop_mvs {
	my $self = shift;

	my $val = shift;
	my $orig_square = shift;
	my $dest_square;
	my $control;

	my @bishop_mv = ();

	#NE
	for ($dest_square = $orig_square+13; $dest_square <= 143; $dest_square += 13) {
		last if ($self->{BOARD}[$dest_square] == IL);
		$control = $val * $self->{BOARD}[$dest_square];
		last if ($control > 0);
		if ($control <= 0) {
			push @bishop_mv, "$orig_square $dest_square";
		}
		last if ($control < 0);
	}
	#SW
	for ($dest_square = $orig_square-13; $dest_square >= 0; $dest_square -= 13) {
		last if ($self->{BOARD}[$dest_square] == IL);
		$control = $val * $self->{BOARD}[$dest_square];
		last if ($control > 0);
		if ($control <= 0) {
			push @bishop_mv, "$orig_square $dest_square";
		}
		last if ($control < 0);
	}
	#NW
	for ($dest_square = $orig_square+11; $dest_square <= 143; $dest_square += 11) {
		last if ($self->{BOARD}[$dest_square] == IL);
		$control = $val * $self->{BOARD}[$dest_square];
		last if ($control > 0);
		if ($control <= 0) {
			push @bishop_mv, "$orig_square $dest_square";
		}
		last if ($control < 0);
	}
	#SE
	for ($dest_square = $orig_square-11; $dest_square >= 0; $dest_square -= 11) {
		last if ($self->{BOARD}[$dest_square] == IL);
		$control = $val * $self->{BOARD}[$dest_square];
		last if ($control > 0);
		if ($control <= 0) {
			push @bishop_mv, "$orig_square $dest_square";
		}
		last if ($control < 0);
	}
	@bishop_mv;
}

sub rook_mvs {
	my $self = shift;

	my $val = shift;
	my $orig_square = shift;
	my $dest_square;
	my $control;

	my @rook_mv = ();

	#N
	for ($dest_square = $orig_square+12; $dest_square <= 143; $dest_square += 12) {
		last if ($self->{BOARD}[$dest_square] == IL);
		$control = $val * $self->{BOARD}[$dest_square];
		last if ($control > 0);
		if ($control <= 0) {
			push @rook_mv, "$orig_square $dest_square";
		}
		last if ($control < 0);
	}
	#S
	for ($dest_square = $orig_square-12; $dest_square >= 0; $dest_square -= 12) {
		last if ($self->{BOARD}[$dest_square] == IL);
		$control = $val * $self->{BOARD}[$dest_square];
		last if ($control > 0);
		if ($control <= 0) {
			push @rook_mv, "$orig_square $dest_square";
		}
		last if ($control < 0);
	}
	#E
	for ($dest_square = $orig_square+1; $dest_square <= 143; $dest_square += 1) {
		last if ($self->{BOARD}[$dest_square] == IL);
		$control = $val * $self->{BOARD}[$dest_square];
		last if ($control > 0);
		if ($control <= 0) {
			push @rook_mv, "$orig_square $dest_square";
		}
		last if ($control < 0);
	}
	#W
	for ($dest_square = $orig_square-1; $dest_square >= 0; $dest_square -= 1) {
		last if ($self->{BOARD}[$dest_square] == IL);
		$control = $val * $self->{BOARD}[$dest_square];
		last if ($control > 0);
		if ($control <= 0) {
			push @rook_mv, "$orig_square $dest_square";
		}
		last if ($control < 0);
	}
	@rook_mv;
}

sub queen_mvs {
	my $self = shift;

	my $val = shift;
	my $orig_square = shift;

	my @queen_mv = ();
	push @queen_mv, $self->bishop_mvs($val, $orig_square);
	push @queen_mv, $self->rook_mvs($val, $orig_square);

	@queen_mv;
}

sub pawn_mvs {
	my $self = shift;

	my $val = shift;
	my $orig_square = shift;
	my $dest_square;
	
	my @pawn_mv = ();

	if ($val > 0) {			# white pawn
		# advance
		$dest_square = $orig_square + 12;
		if ($self->{BOARD}[$dest_square] == EM) {
			if ($dest_square < 110) {				# no promotion
				push @pawn_mv, "$orig_square $dest_square";
			}
			else {
				push @pawn_mv, "$orig_square $dest_square n";
				push @pawn_mv, "$orig_square $dest_square b";
				push @pawn_mv, "$orig_square $dest_square r";
				push @pawn_mv, "$orig_square $dest_square q";
			}
		}

		# double move
		if ( ($orig_square >= 38) && ($orig_square <= 45) ) {		# second rank
			$dest_square = $orig_square + 24;
			if ( ($self->{BOARD}[$dest_square] == EM) and ($self->{BOARD}[$dest_square-12] == EM) ) {
				push @pawn_mv, "$orig_square $dest_square";
			}
		}

		# left capture
		$dest_square = $orig_square + 11;
		if ( ($self->{BOARD}[$dest_square] != IL) && ($self->{BOARD}[$dest_square] < 0) ) {
			if ($dest_square < 110) {				# no promotion
				push @pawn_mv, "$orig_square $dest_square";
			}
			else {
				push @pawn_mv, "$orig_square $dest_square n";
				push @pawn_mv, "$orig_square $dest_square b";
				push @pawn_mv, "$orig_square $dest_square r";
				push @pawn_mv, "$orig_square $dest_square q";
			}
		}

		# right capture
		$dest_square = $orig_square + 13;
		if ( ($self->{BOARD}[$dest_square] != IL) && ($self->{BOARD}[$dest_square] < 0) ) {
			if ($dest_square < 110) {				# no promotion
				push @pawn_mv, "$orig_square $dest_square";
			}
			else {
				push @pawn_mv, "$orig_square $dest_square n";
				push @pawn_mv, "$orig_square $dest_square b";
				push @pawn_mv, "$orig_square $dest_square r";
				push @pawn_mv, "$orig_square $dest_square q";
			}
		}

		# en passant
		if ( ($orig_square >= 74) && ($orig_square <= 81) ) {		# fith rank
			my $column = ($orig_square - 2) % 12;
			if ($column < 7) {					# right capture possible
				if ($self->{LAST_DOUBLE_MOVE}[8+$column+1]) {
					$dest_square = $orig_square + 13;
					push @pawn_mv, "$orig_square $dest_square";
				}
			}
			if ($column > 0) {					# left capture possible
				if ($self->{LAST_DOUBLE_MOVE}[8+$column-1]) {
					$dest_square = $orig_square + 11;
					push @pawn_mv, "$orig_square $dest_square";
				}
			}
		}		
	}
	else {		# black pawn
		# advance
		$dest_square = $orig_square - 12;
		if ($self->{BOARD}[$dest_square] == EM) {
			if ($dest_square > 33) {				# no promotion
				push @pawn_mv, "$orig_square $dest_square";
			}
			else {
				push @pawn_mv, "$orig_square $dest_square n";
				push @pawn_mv, "$orig_square $dest_square b";
				push @pawn_mv, "$orig_square $dest_square r";
				push @pawn_mv, "$orig_square $dest_square q";
			}
		}

		# double move
		if ( ($orig_square >= 98) && ($orig_square <= 105) ) {		# seventh rank
			$dest_square = $orig_square - 24;
			if ( ($self->{BOARD}[$dest_square] == EM) and ($self->{BOARD}[$dest_square+12] == EM) ) {
				push @pawn_mv, "$orig_square $dest_square";
			}
		}

		# left capture
		$dest_square = $orig_square - 13;
		if ( ($self->{BOARD}[$dest_square] != IL) && ($self->{BOARD}[$dest_square] > 0) ) {
			if ($dest_square > 33) {				# no promotion
				push @pawn_mv, "$orig_square $dest_square";
			}
			else {
				push @pawn_mv, "$orig_square $dest_square n";
				push @pawn_mv, "$orig_square $dest_square b";
				push @pawn_mv, "$orig_square $dest_square r";
				push @pawn_mv, "$orig_square $dest_square q";
			}
		}

		# right capture
		$dest_square = $orig_square - 11;
		if ( ($self->{BOARD}[$dest_square] != IL) && ($self->{BOARD}[$dest_square] > 0) ) {
			if ($dest_square > 33) {				# no promotion
				push @pawn_mv, "$orig_square $dest_square";
			}
			else {
				push @pawn_mv, "$orig_square $dest_square n";
				push @pawn_mv, "$orig_square $dest_square b";
				push @pawn_mv, "$orig_square $dest_square r";
				push @pawn_mv, "$orig_square $dest_square q";
			}
		}

		# en passant
		if ( ($orig_square >= 62) && ($orig_square <= 69) ) {		# fith rank
			my $column = ($orig_square - 2) % 12;
			if ($column < 7) {					# right capture possible
				if ($self->{LAST_DOUBLE_MOVE}[$column+1]) {
					$dest_square = $orig_square - 11;
					push @pawn_mv, "$orig_square $dest_square";
				}
			}
			if ($column > 0) {					# left capture possible
				if ($self->{LAST_DOUBLE_MOVE}[$column-1]) {
					$dest_square = $orig_square - 13;
					push @pawn_mv, "$orig_square $dest_square";
				}
			}
		}
	}
	
	@pawn_mv;
}

sub king_mvs {
	my $self = shift;

	my $val = shift;
	my $orig_square = shift;
	my $dest_square;

	my @king_mv = ();

	my @diffs = ( -13, -12, -11, -1, 1, 11, 12, 13 );
	foreach my $diff(@diffs) {
		$dest_square = $orig_square + $diff;
		next if ($self->{BOARD}[$dest_square] == IL);
		if (($val * $self->{BOARD}[$dest_square]) <= 0) {		#enemy piece or empty square
			push @king_mv, "$orig_square $dest_square";
		}
	}

	# castle_code
	if ($val > 0) {					# white king
		return @king_mv if ($self->{MOVED}{W_K});	# white king moved
		return @king_mv if ($self->{UNDER_CHECK}{W_K});	# white king under chack

		# short castle
		if ( (not $self->{MOVED}{W_RR}) and			# white right rook NOT moved
		     ($self->{BOARD}[33] == WR) and			# white right rook NOT captured
		     ($self->{BOARD}[31] == EM) and			# f1 empty
		     ($self->{BOARD}[32] == EM) ) {			# g1 empty
			$dest_square = $orig_square + 2;
			push @king_mv, "$orig_square $dest_square";
		}
		# long castle
		if ( (not $self->{MOVED}{W_LR}) and			# white left rook NOT moved
		     ($self->{BOARD}[26] == WR) and			# white left rook NOT captured
		     ($self->{BOARD}[29] == EM) and			# d1 empty
		     ($self->{BOARD}[28] == EM) and			# c1 empty
		     ($self->{BOARD}[27] == EM) ) {			# b1 empty
			$dest_square = $orig_square - 2;
			push @king_mv, "$orig_square $dest_square";
		}
	}
	else {							# black king
		return @king_mv if ($self->{MOVED}{B_K});		# black king moved
		return @king_mv if ($self->{UNDER_CHECK}{B_K});		# black king under chack
		# short castle
		if ( (not $self->{MOVED}{B_RR}) and			# black right rook NOT moved
		     ($self->{BOARD}[117] == BR) and			# black right rook NOT captured
		     ($self->{BOARD}[115] == EM) and			# f8 empty
		     ($self->{BOARD}[116] == EM) ) {			# g8 empty
			$dest_square = $orig_square + 2;
			push @king_mv, "$orig_square $dest_square";
		}

		# long castle
		if ( (not $self->{MOVED}{B_LR}) and			# black left rook NOT moved
		     ($self->{BOARD}[110] == BR) and			# black left rook NOT captured
		     ($self->{BOARD}[113] == EM) and			# d8 empty
		     ($self->{BOARD}[112] == EM) and			# c8 empty
		     ($self->{BOARD}[111] == EM) ) {			# b8 empty
			$dest_square = $orig_square - 2;
			push @king_mv, "$orig_square $dest_square";
		}
	}

	@king_mv;
}

sub generate_candidate_legal_moves {
	my $self = shift;

	my $color = shift;
	my @candidate_legal_moves = ();
	my ($square, $control);
	my $i;
	
	for ($i = 26; $i <= 117; $i++) {
		$square = $self->{BOARD}[$i];
		$control = $square * $color;

		next if ($square == IL);		# bogus square
		next if ($square == EM);		# empty square
		next if ( $control < 0 );		# enemy piece

		push @candidate_legal_moves, $self->pawn_mvs($square, $i) if ($control == WP);
		push @candidate_legal_moves, $self->knight_mvs($square, $i) if ($control == WN);
		push @candidate_legal_moves, $self->bishop_mvs($square, $i) if ($control == WB);
		push @candidate_legal_moves, $self->rook_mvs($square, $i) if ($control == WR);
		push @candidate_legal_moves, $self->queen_mvs($square, $i) if ($control == WQ);
		push @candidate_legal_moves, $self->king_mvs($square, $i) if ($control == WK);
	}

	@candidate_legal_moves;
}

sub generate_legal_moves {
	my $self = shift;

	my $color = shift;

	# castle legality control
	my (%flag, %forbidden);
	$flag{WK_e1f1} = 0;
	$flag{WK_e1g1} = 0;
	$flag{WK_e1d1} = 0;
	$flag{WK_e1c1} = 0;
	$flag{BK_e8f8} = 0;
	$flag{BK_e8g8} = 0;
	$flag{BK_e8d8} = 0;
	$flag{BK_e8c8} = 0;
	
	my %tmp_legal_moves = ();
	my @legal_moves = ();

	my @candidate_legal_moves = $self->generate_candidate_legal_moves($color);

	foreach my $cm(@candidate_legal_moves) {
		my @squares = split(/ /, $cm);

		my $orig_square = $squares[0];
		
		if ($self->test_legality($cm)) {
			$tmp_legal_moves{$cm} = 1;
			if ($self->{BOARD}[$orig_square] == WK) {
				if ($cm eq "30 31") {
					$flag{WK_e1f1} = 1;
				}
				elsif ($cm eq "30 32") {
					$flag{WK_e1g1} = 1;
				}
				elsif ($cm eq "30 29") {
					$flag{WK_e1d1} = 1;
				}
				elsif ($cm eq "30 28") {
					$flag{WK_e1c1} = 1;
				}
			}
			elsif ($self->{BOARD}[$orig_square] == BK) {
				if ($cm eq "114 115") {
					$flag{BK_e8f8} = 1;
				}
				elsif ($cm eq "114 116") {
					$flag{BK_e8g8} = 1;
				}
				elsif ($cm eq "114 113") {
					$flag{BK_e8d8} = 1;
				}
				elsif ($cm eq "114 112") {
					$flag{BK_e8c8} = 1;
				}
			}
		}
	}

	# Control for castle
	$tmp_legal_moves{"30 32"} = 0 if ( (not $flag{WK_e1f1}) and $flag{WK_e1g1} );
	$tmp_legal_moves{"30 28"} = 0 if ( (not $flag{WK_e1d1}) and $flag{WK_e1c1} );
	$tmp_legal_moves{"114 116"} = 0 if ( (not $flag{BK_e8f8}) and $flag{BK_e8g8} );
	$tmp_legal_moves{"114 112"} = 0 if ( (not $flag{BK_e8d8}) and $flag{BK_e8c8} );

	foreach my $tmp_move(keys %tmp_legal_moves) {
		push @legal_moves, $tmp_move if ($tmp_legal_moves{$tmp_move});
	}

	@legal_moves;
}

sub execute_move {
	my $self = shift;

	my $move = shift;
	my @squares = split(/ /, $move);

	my $orig_square = $squares[0];
	my $dest_square = $squares[1];
	my $promotion = "";
	$promotion = $squares[2] if defined($squares[2]);
	my $moving_piece = $self->{BOARD}[$orig_square];
	my $moving_color = sign($moving_piece);

	# capture or pawn move
	if ( ($self->{BOARD}[$dest_square] != EM) or ($moving_piece == WP) or ($moving_piece == BP) ) {
		$self->{RULE_50_MOVES} = 0;
	}
	else {
		$self->{RULE_50_MOVES}++;
	}

	$self->{LAST_DOUBLE_MOVE} = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];

	#castle
	if ($moving_piece == WK) {
		$self->{MOVED}{W_K} = 1;
		if ( ($dest_square - $orig_square) == 2 ) {
			$self->{BOARD}[33] = EM;
			$self->{BOARD}[31] = WR;
		}
		elsif ( ($dest_square - $orig_square) == -2 ) {
			$self->{BOARD}[26] = EM;
			$self->{BOARD}[29] = WR;
		}
	}
	elsif ($moving_piece == BK) {
		$self->{MOVED}{B_K} = 1;
		if ( ($dest_square - $orig_square) == 2 ) {
			$self->{BOARD}[117] = EM;
			$self->{BOARD}[115] = BR;
		}
		elsif ( ($dest_square - $orig_square) == -2 ) {
			$self->{BOARD}[110] = EM;
			$self->{BOARD}[113] = BR;
		}
	}

	# Pawn's special moves
	my $column;
	if ($moving_piece == WP) {
		if ( ($dest_square - $orig_square) == 24 ) {		# double move
			$column = ($orig_square - 2) % 12;
			$self->{LAST_DOUBLE_MOVE}[$column] = 1;
		}
		elsif ( ( ($dest_square - $orig_square) == 13 ) and	# en passant R
			($self->{BOARD}[$dest_square] == EM) ) {
			$self->{BOARD}[$orig_square+1] = EM;
		}
		elsif ( ( ($dest_square - $orig_square) == 11 ) and	# en passant L
			($self->{BOARD}[$dest_square] == EM) ) {
			$self->{BOARD}[$orig_square-1] = EM;
		}
		if ($promotion eq "n") {
			$self->{BOARD}[$dest_square] = WN;
		}
		elsif ($promotion eq "b") {
			$self->{BOARD}[$dest_square] = WB;
		}
		elsif ($promotion eq "r") {
			$self->{BOARD}[$dest_square] = WR;
		}
		elsif ($promotion eq "q") {
			$self->{BOARD}[$dest_square] = WQ;
		}
	}
	elsif ($moving_piece == BP) {
		if ( ($dest_square - $orig_square) == -24 ) {		# double move
			$column = ($orig_square - 2) % 12;
			$self->{LAST_DOUBLE_MOVE}[8+$column] = 1;
		}
		elsif ( ( ($dest_square - $orig_square) == -11 ) and	# en passant R
			($self->{BOARD}[$dest_square] == EM) ) {
			$self->{BOARD}[$orig_square+1] = EM;
		}
		elsif ( ( ($dest_square - $orig_square) == -13 ) and	# en passant L
			($self->{BOARD}[$dest_square] == EM) ) {
			$self->{BOARD}[$orig_square-1] = EM;
		}

		if ($promotion eq "n") {
			$self->{BOARD}[$dest_square] = BN;
		}
		elsif ($promotion eq "b") {
			$self->{BOARD}[$dest_square] = BB;
		}
		elsif ($promotion eq "r") {
			$self->{BOARD}[$dest_square] = BR;
		}
		elsif ($promotion eq "q") {
			$self->{BOARD}[$dest_square] = BQ;
		}
	}

	# Rooks' flags
	$self->{MOVED}{W_RR} = 1 if ( ($moving_piece == WR) and ($orig_square == 33) );
	$self->{MOVED}{W_LR} = 1 if ( ($moving_piece == WR) and ($orig_square == 26) );
	$self->{MOVED}{B_RR} = 1 if ( ($moving_piece == WR) and ($orig_square == 117) );
	$self->{MOVED}{B_LR} = 1 if ( ($moving_piece == WR) and ($orig_square == 110) );

	$self->{BOARD}[$orig_square] = EM;
	$self->{BOARD}[$dest_square] = $moving_piece if (not $promotion);

	if ($self->can_capture_king($moving_color)) {
		if ($moving_color == 1) {
			$self->{UNDER_CHECK}{B_K} = 1;
			$self->{UNDER_CHECK}{W_K} = 0;
		}
		else {
			$self->{UNDER_CHECK}{B_K} = 0;
			$self->{UNDER_CHECK}{W_K} = 1;
		}
	}
	else {
		$self->{UNDER_CHECK}{B_K} = 0;
		$self->{UNDER_CHECK}{W_K} = 0;
	}

	$self->{COLOR_TO_MOVE} = -$moving_color;
}

sub can_capture_king {
	my $self = shift;

	my $color_to_move = shift;

	my $dest_square;

	my @moves = $self->generate_candidate_legal_moves($color_to_move);
	foreach my $move(@moves) {
		my @move_arr = split(/ /, $move);

		$dest_square = $move_arr[1];
		if ( ($color_to_move * $self->{BOARD}[$dest_square]) == BK ) {
			return 1;
		}
	}
	return 0;
}

sub test_legality {
	my $self = shift;

	my $move = shift;
	my $is_legal = 1;	

	my @squares = split(/ /, $move);
	my $orig_square = $squares[0];
	my $moving_val = $self->{BOARD}[$orig_square];
	my $moving_color = sign($moving_val);

	# save context
	my @saved_board = @{ $self->{BOARD} };
	my @saved_last_double_move = @{ $self->{LAST_DOUBLE_MOVE} };
	my %saved_moved = %{ $self->{MOVED} };
	my %saved_under_check = %{ $self->{UNDER_CHECK} };
	my $saved_rule_50_moves = $self->{RULE_50_MOVES};
	my $saved_color_to_move = $self->{COLOR_TO_MOVE};

	# execute move
	$self->execute_move($move);

	# see if an enemy piece can eat the king
	if ($self->can_capture_king(-$moving_color)) {
		$is_legal = 0;
	}

	# restore context
	@{ $self->{BOARD} } = @saved_board;
	@{ $self->{LAST_DOUBLE_MOVE} } = @saved_last_double_move;
	%{ $self->{MOVED} } = %saved_moved;
	%{ $self->{UNDER_CHECK} } = %saved_under_check;
	$self->{RULE_50_MOVES} = $saved_rule_50_moves;
	$self->{COLOR_TO_MOVE} = $saved_color_to_move;

	return $is_legal;
}

# POSITION EVALUATION
sub static_eval {
	my $self = shift;

	my ($r, $c, $sq, $piece, $delta);

	$delta = 0;
	for ($r = 7; $r >= 0; $r--) {
		for ($c = 0; $c <= 7; $c++) {
			$sq = 12 * ($r + 2) + 2 + $c;
			$piece = $self->{BOARD}[$sq];
			next if ( ($piece == EM) or ($piece == WK) or ($piece == BK) );
			$delta += ( $self->{PIECE_VAL}{$piece} * sign($piece) );
		}
	}
	return $delta+rand();
}

sub evaluate {
	my ($self, $color) = @_;	# Color which made the last move

	if ($color == WHITE) {
		my @legal_moves = $self->generate_legal_moves(BLACK);
		if (not @legal_moves) {
			if ($self->{UNDER_CHECK}{B_K}) {
				return -(CHECKMATE);
			}
			else {
				return 0;
			}
		}
		elsif ($self->rule50moves()) {
			return 0;
		}
		else {
			return -$self->static_eval();
		}
	}
	else {
		my @legal_moves = $self->generate_legal_moves(WHITE);
		if (not @legal_moves) {
			if ($self->{UNDER_CHECK}{W_K}) {
				return -(CHECKMATE);
			}
			else {
				return 0;
			}
		}
		elsif ($self->rule50moves()) {
			return 0;
		}
		else {
			return $self->static_eval();
		}
	}
}


sub alphabeta_search {
	my ($self, $depth, $alpha, $beta, $color, $ref_bestmove) = @_;	# Color which made the last move
	my ($alphaL, $evaluation);
	if ($depth == 0) {
		return $self->evaluate($color);
	}

	$alphaL = $alpha;
	if ($color == WHITE) {
		my @legal_moves = $self->generate_legal_moves(BLACK);
		if (not @legal_moves) {
			if ($self->{UNDER_CHECK}{B_K}) {
				return -(CHECKMATE+$depth);
			}
			else {
				return 0;
			}
		}
		else {
			#BACKUP STATE
			my @saved_board = @{ $self->{BOARD} };
			my @saved_last_double_move = @{ $self->{LAST_DOUBLE_MOVE} };
			my %saved_moved = %{ $self->{MOVED} };
			my %saved_under_check = %{ $self->{UNDER_CHECK} };
			my $saved_rule_50_moves = $self->{RULE_50_MOVES};
			my $saved_color_to_move = $self->{COLOR_TO_MOVE};

			foreach my $move(@legal_moves) {
				$self->execute_move($move);

				$evaluation = -$self->alphabeta_search($depth-1, -$beta, -$alphaL, -$color, $ref_bestmove);

				#RESTORE STATE
				@{ $self->{BOARD} } = @saved_board;
				@{ $self->{LAST_DOUBLE_MOVE} } = @saved_last_double_move;
				%{ $self->{MOVED} } = %saved_moved;
				%{ $self->{UNDER_CHECK} } = %saved_under_check;
				$self->{RULE_50_MOVES} = $saved_rule_50_moves;
				$self->{COLOR_TO_MOVE} = $saved_color_to_move;

				if ($evaluation >= $beta) {
					return $beta;
				}

				if ($evaluation > $alphaL) {
					$alphaL = $evaluation;
					if ($depth == $self->{DEPTH}) {
						${ $ref_bestmove } = $move;
					}
				}
			}
			return $alphaL;
		}
	}
	else {
		my @legal_moves = $self->generate_legal_moves(WHITE);
		if (not @legal_moves) {
			if ($self->{UNDER_CHECK}{W_K}) {
				return -(CHECKMATE+$depth);
			}
			else {
				return 0;
			}
		}
		else {
			#BACKUP STATE
			my @saved_board = @{ $self->{BOARD} };
			my @saved_last_double_move = @{ $self->{LAST_DOUBLE_MOVE} };
			my %saved_moved = %{ $self->{MOVED} };
			my %saved_under_check = %{ $self->{UNDER_CHECK} };
			my $saved_rule_50_moves = $self->{RULE_50_MOVES};
			my $saved_color_to_move = $self->{COLOR_TO_MOVE};

			foreach my $move(@legal_moves) {
				$self->execute_move($move);
				$evaluation = -$self->alphabeta_search($depth-1, -$beta, -$alphaL, -$color, $ref_bestmove);

				#RESTORE STATE
				@{ $self->{BOARD} } = @saved_board;
				@{ $self->{LAST_DOUBLE_MOVE} } = @saved_last_double_move;
				%{ $self->{MOVED} } = %saved_moved;
				%{ $self->{UNDER_CHECK} } = %saved_under_check;
				$self->{RULE_50_MOVES} = $saved_rule_50_moves;
				$self->{COLOR_TO_MOVE} = $saved_color_to_move;

				if ($evaluation >= $beta) {
					return $beta;
				}

				if ($evaluation > $alphaL) {
					$alphaL = $evaluation;
					if ($depth == $self->{DEPTH}) {
						${ $ref_bestmove } = $move;
					}
				}
			}
			return $alphaL;
		}
	}
}

# ENGINE METHODS
sub white_move {
	my $self = shift;

	my ($evaluation, $bestmove);

	if ( $self->insuff_material() ) {
		print STDERR "1/2-1/2 {insufficient material}\n";
		return;
	}
	if ( $self->rule50moves() ) {
		print STDERR "1/2-1/2 {50 moves rule}\n";
		return;
	}

	my @legal_moves = $self->generate_legal_moves(WHITE);

	if (@legal_moves) {
		if ($self->{DEPTH} == 0) {					#RANDOM MOVE
			my $nb_legal_moves = @legal_moves;
			$bestmove = $legal_moves[int(rand($nb_legal_moves))];
		}
		else {
			$evaluation = $self->alphabeta_search($self->{DEPTH}, -(AB_CNST), AB_CNST, BLACK, \$bestmove);
		}
		my $s_move = move_to_coord($bestmove);
		$self->execute_move($bestmove);
		print STDERR "move $s_move\n";
	}
	else {
		if ($self->{UNDER_CHECK}{W_K}) {
			print STDERR "0-1\n";
		}
		else {
			print STDERR "1/2-1/2 {Stalemate}\n";
		}
	}
}
	
sub black_move {
	my $self = shift;

	my ($evaluation, $bestmove);

	if ( $self->insuff_material() ) {
		print STDERR "1/2-1/2 {insufficient material}\n";
		return;
	}
	if ( $self->rule50moves() ) {
		print STDERR "1/2-1/2 {50 moves rule}\n";
		return;
	}

	my @legal_moves = $self->generate_legal_moves(BLACK);

	if (@legal_moves) {
		if ($self->{DEPTH} == 0) {					#RANDOM MOVE
			my $nb_legal_moves = @legal_moves;
			$bestmove = $legal_moves[int(rand($nb_legal_moves))];
		}
		else {
			$evaluation = $self->alphabeta_search($self->{DEPTH}, -(AB_CNST), AB_CNST, WHITE, \$bestmove);
		}

		my $s_move = move_to_coord($bestmove);
		$self->execute_move($bestmove);
		print STDERR "move $s_move\n";
	}
	else {
		if ($self->{UNDER_CHECK}{B_K}) {
			print STDERR "1-0\n";
		}
		else {
			print STDERR "1/2-1/2 {Stalemate}\n";
		}
	}
}

sub play_one_game {
	my $self = shift;

	my ($input_move, $ok_move, $game_over, $bestmove);

	print "Please choose my color (W or B)\n";
	my $engine_color = <STDIN>;
	chomp($engine_color);

	while (($engine_color ne "W") and ($engine_color ne "B")) {
		print "Wrong answer: Please choose my color (W or B)\n";
		$engine_color = <STDIN>;
		chomp($engine_color);
	}

	$self->reset();

	while (1) {
		if ($engine_color eq "W") {
			# play a move
			$game_over = $self->game_over();
			if ($game_over) {
				print "$game_over\n";
				last;
			}
			else {
				$bestmove = $self->best_move();
				$self->execute_move(coord_to_move($bestmove));

				print "$bestmove\n";
			}

			# read user's move
			$ok_move = INVALID_MOVE;
			while ($ok_move != LEGAL_MOVE) {
				$input_move = <STDIN>;
				chomp($input_move);

				$ok_move = $self->do_move($input_move);
				print "Invalid move\n" if ($ok_move == INVALID_MOVE);
				print "Illegal move\n" if ($ok_move == ILLEGAL_MOVE);
			}
		}
		else {
			# read user's move
			$ok_move = INVALID_MOVE;
			while ($ok_move != LEGAL_MOVE) {
				$input_move = <STDIN>;
				chomp($input_move);

				$ok_move = $self->do_move($input_move);
				print "Invalid move\n" if ($ok_move == INVALID_MOVE);
				print "Illegal move\n" if ($ok_move == ILLEGAL_MOVE);
			}

			# play a move
			$game_over = $self->game_over();
			if ($game_over) {
				print "$game_over\n";
				last;
			}
			else {
				$bestmove = $self->best_move();
				$self->execute_move(coord_to_move($bestmove));

				print "$bestmove\n";
			}
		}
	}

	my $answer = "";
	while (($answer ne "Y") and ($answer ne "N")) {
		print "Another game? [Y/N]\n";
		$answer = <STDIN>;
		chomp($answer);
	}
	return $answer;
}

# ------------------------- FUNCTIONS -------------------------
sub sign {
	my $val = shift;

	return ($val / abs($val));
}

sub print_arr {
	my @arr = @_;

	foreach my $el(@arr) {
		print "$el\n";
	}
}

sub print_moves_arr {
	my @arr = @_;

	foreach my $el(@arr) {
		print move_to_coord($el) . "\n";
	}
}

sub value_to_string {
	my $value = shift;

	return " " if ($value == EM);
	return "R" if ($value == WR);
	return "r" if ($value == BR);
	return "N" if ($value == WN);
	return "n" if ($value == BN);
	return "B" if ($value == WB);
	return "b" if ($value == BB);
	return "P" if ($value == WP);
	return "p" if ($value == BP);
	return "Q" if ($value == WQ);
	return "q" if ($value == BQ);
	return "K" if ($value == WK);
	return "k" if ($value == BK);
}

sub move_to_coord {
	my $move = shift;
	
	my @squares = split(/ /, $move);

	my $orig_square = $squares[0];
	my $dest_square = $squares[1];
	my $promotion = "";
	$promotion = $squares[2] if defined($squares[2]);

	my $orig_column = ($orig_square-1) % 12;
	my $orig_raw = int (($orig_square-12) / 12);
	my $dest_column = ($dest_square-1) % 12;
	my $dest_raw = int (($dest_square-12) / 12);

	$orig_column = chr(96 + $orig_column);
	$dest_column = chr(96 + $dest_column);
	
	return "$orig_column$orig_raw$dest_column$dest_raw$promotion";
}

sub coord_to_move {
	my $coord = shift;

	my $orig_column = substr($coord, 0, 1);
	my $orig_raw = substr($coord, 1, 1);
	my $dest_column = substr($coord, 2, 1);
	my $dest_raw = substr($coord, 3, 1);
	my $promotion = "";
	$promotion = substr($coord, 4, 1) if (length($coord) == 5);

	$orig_column = ord($orig_column) - 96;
	$dest_column = ord($dest_column) - 96;

	my $orig_square = ($orig_raw + 1) * 12 + $orig_column + 1;
	my $dest_square = ($dest_raw + 1) * 12 + $dest_column + 1;

	return "$orig_square $dest_square $promotion" if ($promotion);
	return "$orig_square $dest_square";
}

sub print_board_debug {
	my @board = @_;

	my ($r, $c, $sq);
	for ($r = 7; $r >= 0; $r--) {
		for ($c = 0; $c <= 7; $c++) {
			$sq = 12 * ($r + 2) + 2 + $c;
			my $str = value_to_string($board[$sq]);
			print "$str ";
		}
		print "\n";
	}
}

1;

__END__

=head1 NAME

Chess::Play - Play chess games, calculate legal moves, use a search algorithm

=head1 SYNOPSIS

  use Chess::Play;

  my $cp = Chess::Play->new();
  $cp->reset();
  $cp->set_piece_val($p_val, $n_val, $b_val, $r_val, $q_val);
  $cp->set_depth($depth)
  $cp->legal_moves()
  $cp->do_move($move)
  $cp->game_over()
  $cp->best_move()
  $cp->play()
  $cp->xboard_play([$custom_name])

=head1 DESCRIPTION

This module allows to play a chess game using STDIN or the xboard graphical interface.
Il also can calculate legal moves and uses the Alpha-Beta search algorithm to find the best move.

=head1 METHODS

=over 4

=item * $cp = Chess::Play->new()

Create a new object to play chess.

=item * $cp->reset()

Reset to the start position.

=item * $cp->set_piece_val($p_val, $n_val, $b_val, $r_val, $q_val)

Change default values for pieces (the defaults are : 1, 3, 3, 5, 9)

=item * $cp->set_depth($depth)

Set the depth of the search algorithm (Alpha-Beta search).

=item * $cp->legal_moves()

Calculate the list of legal moves

=item * $cp->do_move($move)

execute a move (for instance "e2e4" or "a7a8q")

=item * $cp->game_over()

Tell if the game is over (Sheckmate, Stalemate, Insufficient Material, 50 moves rule). Threeway repetition is not supported in this version.

=item * $cp->best_move()

Return the best move according to the search algorithm

=item * $cp->play()

Play a chess game using STDIN

=item * $cp->xboard_play()

=item * $cp->xboard_play($custom_name)

Play a chess game using xboard (only the basic xboad directives are supported). You can choose a name for your engine.

 Examples:
  my $cp = Chess::Play->new();

  Execute some moves
  $cp->do_move("e2e4");
  $cp->do_move("e7e5");

  Calculating legal moves
  my @legal_moves = $cp->legal_moves()

  Play a chess game using stdin
  $cp->reset();
  $ce->set_depth(2);
  $ce->play();

  Play a chess game using xboard
  $cp->reset();
  $ce->set_depth(2);
  $cp->xboard_play("My_Chess_Engine")

  xboard -fcp /path/to/my_engine.pl or xboard -fcp /path/to/my_engine.pl -scp /path/to/my_engine2.pl

=back

=head1 AUTHOR

Giuliano Ippoliti, g1ul14n0 AT gmail

=head1 COPYRIGHT

This is free software in the colloquial nice-guy sense of the word.
Copyright (c) 2009, Giuliano Ippoliti.  You may redistribute and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=cut

############################################################
#
# Module: XML::Lite
#
# Created: 25 August 2001 by Jeremy Wadsack for Wadsack-Allen Digital Group
# Copyright (C) 2001 Wadsack-Allen. All rights reserved.
#
#	TODO
#		* Need to support <!...> for doctypes, and doctype delarations
#		* Could add a method 'element' that accepts path-like syntax
#		* Could add write_to_file, to_string, etc. methods (requires that the orig doc be preserved!)
#		* Could improve support for comments, CDATA, PI's etc as objects?
#		* Expose handler interface
#		* Expose a method to provide better error handling
#
############################################################
# Date        Modification                            Author
# ----------------------------------------------------------
# 04.Sep.2001 Fixed lots of bugs and built tests          JW
# 08.Sep.2001 Added linked list & handlers to parser      JW
# 04.Nov.2001 Fixed bug in parameter handling             JW
############################################################
package XML::Lite;
use strict;
#$^W=1;		# 'use warnings;' in perl 5.005_62 and later

=head1 NAME

XML::Lite - A lightweight XML parser for simple files

=head1 SYNOPSIS

use XML::Lite;
my $xml = new XML::Lite( xml => 'a_file.xml' );

=head1 DESCRIPTION

XML::Lite is a lightweight XML parser, with basic element traversing 
methods. It is entirely self-contained, pure Perl (i.e. I<not> based on 
expat). It provides useful methods for reading most XML files, including 
traversing and finding elements, reading attributes and such. It is 
designed to take advantage of Perl-isms (Attribute lists are returned as 
hashes, rather than, say, lists of objects). It provides only methods 
for reading a file, currently.

=head1 METHODS

The following methods are available:

=over 4

=cut
 
use XML::Lite::Element;
BEGIN {
	use vars       qw( $VERSION @ISA );
	$VERSION = '0.14';
	@ISA         = qw();
} # end BEGIN

# non-exported package globals go here
use vars      qw( %ERRORS );

# Predefined error messages in English
%ERRORS = (
	NO_START        => "A closing tag (\%1) was found with no corresponding start tag at position \%0 in your XML file.\n",
	NO_ROOT         => "Your XML document must begin with a root element.\n",
	ROOT_NOT_CLOSED => "The root element of your XML document (starting at position \%0) is incomplete.\n",
	ELM_NOT_CLOSED  => "The XML-like element starting at position \%0 is incomplete. (Did you forget to escape a '<'?)\n",
);
############################
## The object constructor ##
############################

=item my $xml = new XML::Lite( xml => $source[, ...] );

Creates a new XML::Lite object. The XML::Lite object acts as the document
object for the $source that is sent to it to parse. This means that you 
create a new object for each document (or document sub-section). As the 
objects are lightweight this should not be a performance consideration.

The object constructor can take several named parameters. Parameter names
may begin with a '-' (as in the example above) but are not required to. The 
following parameters are recognized.

  xml      The source XML to parse. This can be a filename, a scalar that 
           contains the document (or document fragment), or an IO handle.
  

As a convenince, if only on parameter is given, it is assumed to be the source.
So you can use this, if you wish:

	my $xml = new XML::Lite( 'file.xml' );

=cut

sub new {
	my $self = {};
	my $proto = shift;
	my %parms;
	my $class = ref($proto) || $proto;
	
	# Parse parameters
	$self->{settings} = {};
	if( @_ > 1 ) {
		my($k, $v);
		local $_;
		%parms = @_;
		while( ($k, $v) = each %parms ) {
			$k =~ s/^-//;		# Removed leading '-' if it exists. (Why do Perl programmers use this?)
			$self->{settings}{$k} = $v;
		} # end while 
	} else {
		$self->{settings}{xml} = $_[0];
	} # end if;

	bless ($self, $class);

	# Some defaults
	$self->{doc_offset} = 0;
	$self->{doc} = '';
	$self->{_CDATA} = [];
	$self->{handlers} = {};
	
	# Refer to global error messages
	$self->{ERRORS} = $self->{settings}{error_messages} || \%ERRORS;
	
	# Now parse the XML document and build look-up tables
	return undef unless $self->_parse_it();

	return $self;
} # end new

##########################
##                      ##
##   Public Methods     ##
##                      ##
##########################

=item my $elm = $xml->root_element()

Returns a reference to an XML::Lite::Element object that represents
the root element of the document.

Returns C<undef> on errors.

=cut

# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 04Sep2001 Added root alias                              JW
# 08Sep2001 Modified to use tree instead of element list  JW
# 05Nov2001 Added additional aliases                      JW
# ----------------------------------------------------------
sub root;
*root = \&root_element;
sub get_root;
*get_root = \&root_element;
sub get_root_element;
*get_root_element = \&root_element;
sub root_element {
	my $self = shift;
	return undef unless defined $self->{doc};

	# Find the first thing in the root of tree that's an element
	my $root;
	foreach( @{$self->{tree}} ) {
		if( @$_ == 4 ) {
			$root = $_;
			last;
		} # end if
	} # end foreach
	return undef unless defined $root;
	return XML::Lite::Element->new( $self, $root );
} # end root_element


=item @list = $xml->elements_by_name( $name )

Returns a list of all elements that match C<$name>.
C<@list> is a list of L<XML::Lite::Element> objects
If called in a scalar context, this will return the
first element found that matches (it's more efficient 
to call in a scalar context than assign the results 
to a list of one scalar).

If no matching elements are found then returns C<undef>
in scalar context or an empty list in array context.

=cut

# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 27Aug2001 Added method.                                 JW
# 04Sep2001 Added element_by_name alias                   JW
# ----------------------------------------------------------
sub element_by_name;
*element_by_name = \&elements_by_name;
sub elements_by_name {
	my $self = shift;
	my( $name ) = @_;
	
	if( wantarray ) {
		my @list = ();
		foreach( @{$self->{elements}{$name}} ) {
			my $elm = new XML::Lite::Element( $self, $_,  );
			push @list, $elm if defined $elm;
		} # end foreach
		return @list;
	} else {
		return new XML::Lite::Element( $self, $self->{elements}{$name}[0] );
	} # end if
} # end elements_by_name


##########################
##                      ##
##   Private Methods    ##
##                      ##
##########################
# ----------------------------------------------------------
# Sub: _parse_it
#
# Args: (None)
#
# Returns: True value on success, false on failure
#
# Description: Parses the XML file in $self->{settings}{xml}
# If this is an IO reference or filename, then reads from that,
# else if it starts with '<' assumes it's an XML document.
# During parsing, stores an internal database of named elements
# for lookups ($self->{elements}) and an internal linked list
# of elements and text nodes ($self->{tree}) for traversal.
# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 08Sep2001 Added linked list tree to internal objects    JW
# 30Jan2003 Fixed bug in child tree with EMTPY elements   JW
# ----------------------------------------------------------
sub _parse_it {
	my $self = shift;
	
	# Get the xml content
	if( $self->{settings}{xml} =~ /^\s*</ ) {
		$self->{doc} = $self->{settings}{xml};
	} else {
		$self->{doc} = $self->_get_a_file( $self->{settings}{xml} );
	} # end if
	return 0 unless defined $self->{doc};
	delete $self->{settings}{xml};		# Just save some memory

	# -- Normalize the document to make things easier to find
	# Remove comments (but replace with spaces to maintain positioning for messages
	$self->{doc} =~ s/(<!--.+?-->)/' ' x length($1)/sge;

	# Move CDATA to hash and insert a reference to it (so it doesn't mess up regexp parsing)
	$self->{doc} =~ s/<!\[CDATA\[(.+?)\]\]>/'<![CDATA['.$self->_store_cdata($1).']]\/>'/sge;

	# Remove processing instructions (but replace with spaces to maintain positioning for messages
	# (Perhaps we could do something with these -- they are instructions for processors...)
	$self->{doc} =~ s/(<\?.+?\?>)/' ' x length($1)/sge;

	# NOTE: This makes it not possible to save the same formatting
	# -- will also remove the space from the <?xml ...?> processing instruction!
	if( $self->{doc} =~ s/^(\s+)// ) {
		$self->{doc_offset} = length $1;		# Store the number of removed chars for messages
	} # end if
	$self->{doc} =~ s/\s+$//;
	
	
	# Build lookup tables
	$self->{elements} = {};
	$self->{tree} = [];
	# - These are used in the building process
	my $element_list = [];
	my $current_element = $self->{tree};
	
	# Call init handler if defined
	&{$self->{handlers}{init}}($self) if defined $self->{handlers}{init};
	
	# Make a table of offsets to each element start and end point
	# Table is a hash of element names to lists of offsets:
	# [start_tag_start, start_tag_end, end_tag_start, end_tag_end]
	# where tags include the '<' and '>'
	
	# Also make a tree of linked lists. List contains root element 
	# and other nodes. Each node consits of a list ref (the position list)
	# and a following list containing the child element. Text nodes are 
	# a list ref (with just two positions).

	# Find the opening and closing of the XML, giving errors if not well-formed
	my $start_pos = index( $self->{doc}, '<' );
	$self->_error( 'NO_ROOT' ) if $start_pos == -1;
	my $end_pos = index( $self->{doc}, '>', $start_pos + 1 );
	$self->_error( 'ROOT_NOT_CLOSED', $start_pos + $self->{doc_offset} ) if $end_pos == -1;
	my $doc_end = rindex( $self->{doc}, '>' );
	$self->_error( 'ROOT_NOT_CLOSED' ) if $doc_end == -1;
	
	# Now walk through the document, one tag at a time, building up our
	# lookup tables
	while( $end_pos <= $doc_end ) {
		
		# Get a tag
		my $tag = substr( $self->{doc}, $start_pos, $end_pos - $start_pos + 1 );

		# Get the tag name and see if it's an end tag (starts with </)
		my( $end, $name ) = $tag =~ m{^<\s*(/?)\s*([^/>\s]+)};
		
		if( $end ) {
			# If there is no start tag for this end tag then throw an error
			$self->_error( 'NO_START', $start_pos + $self->{doc_offset}, $tag ) unless defined $self->{elements}{$name};
			
			# Otherwise, add the end point to the array for the last element in 
			# the by-name lookup hash
			my( $x, $found ) = (@{$self->{elements}{$name}} - 1, 0);
			while( $x >= 0 ) {

				# Close the last open element (ignore elements already closed)
				if( @{$self->{elements}{$name}[$x]} < 4 ) {
					$self->{elements}{$name}[$x][2] = $start_pos;
					$self->{elements}{$name}[$x][3] = $end_pos;
					$found = 1;
					last;
				} # end if
				$x--;
			} # end while

			# If we didn't find an open element then throw an error
			$self->_error( 'NO_START', $start_pos + $self->{doc_offset}, $tag ) unless $found;
			
			# Call an end-tag handler if defined (not yet exposed)
			&{$self->{handlers}{end}}($self, $name) if defined $self->{handlers}{end};
			
			# Close element in linked list (tree)
			$current_element = pop @$element_list;
			
		} else {
			# Make a new list in the by-name lookup hash if none found by this name yet 
			$self->{elements}{$name} = [] unless defined $self->{elements}{$name};
			
			# Add start points to the array of positions and push it on the hash
			my $pos_list = [$start_pos, $end_pos];
			push @{$self->{elements}{$name}}, $pos_list;
			
			# Call start-tag handler if defined (not yet exposed)
			&{$self->{handlers}{start}}($self, $name) if defined $self->{handlers}{start};
			
			# If this is a single-tag element (e.g. <.../>) then close it immediately
			if( $tag =~ m{/\s*>$} ) {
				push @$current_element, $pos_list;
				$pos_list->[2] = undef;
				$pos_list->[3] = undef;
				# Call an end-tag handler now too
				&{$self->{handlers}{end}}($self, $name) if defined $self->{handlers}{end};
			} else {
				# Now add the element to the linked list (tree)
				push @$element_list, $current_element;
				# Otherwise, put this on the list and start a sublist for children
				my $new_element = [];
				push @$current_element, $pos_list, $new_element;
				$current_element = $new_element;
			} # end if

		} # end if
		
		# Move the start pointer to beginning of next element
		$start_pos = index( $self->{doc}, '<', $start_pos + 1 );
		last if $start_pos == -1 || $end_pos == $doc_end;

		# Now $end_pos is end of old tag and $start_pos is start of new
		# So do things on the data between the tags as needed
		if( $start_pos - $end_pos > 1 ) {
			# Call any character data handler 
			&{$self->{handlers}{char}}($self, substr($self->{doc}, $end_pos + 1, $start_pos - $end_pos - 1)) if defined $self->{handlers}{char};

			# Inserting the text into the linked list as well
#			push @$current_element, [$end_pos + 1, $start_pos - 1];
		} # end if
		
		# Now finish by incrementing the parser to the next element
		$end_pos = index( $self->{doc}, '>', $start_pos + 1 );
		
		# If there is no next element, and we're not at the end of the document,
		# then throw an error
		$self->_error( 'ELM_NOT_CLOSED', $start_pos + $self->{doc_offset} ) if $end_pos == -1;
	} # end while

	# Call finalization handler if defined and return it's value
	return &{$self->{handlers}{final}}($self) if defined $self->{handlers}{final};

	# Else return the tree pointer
	return $self->{tree};
} # end _parse_it

# ----------------------------------------------------------
# Sub: _get_a_file
#
# Args: $file
#
# Returns: Scalar content of $file, undef on error
#
# Description: Reads from $file and returns the content. 
# $file may be either a filename or an IO handle
# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 28Aug2001 Added scalar and IO handling                  JW
# ----------------------------------------------------------
sub _get_a_file {
	my $self = shift;
	my $file = shift;
	my $content = undef;
	
	# If it's a ref and a handle, then read that
	if( ref($file) ) {
		$content = join '', <$file>;
	}
	# If it's a scalar and the file exits then open it
	elsif( -e $file ) {
		open( XML, $file ) || return undef;
		$content = join '', <XML>;
		close XML || return undef;
	} 
	# Don't know how to handle this type of parameter
	else {
		return undef;
	} # end if
	
	return $content;
} # end _get_a_file

# ----------------------------------------------------------
# Sub: _error
#
# Args: $code [, @args]
#	$code  A code representing the message to send
#
# Returns: Does not. Dies.
#
# Description: Outputs an error message and dies
# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# ----------------------------------------------------------
sub _error {
	my $self = shift;
	my( $code, @args ) = @_;
	my $msg = $self->{ERRORS}{$code};
	
	# Handle replacement codes
	$msg =~ s/\%(\d+)/$args[$1]/g;
	
	# Throw exception
	die ref($self) . ":$msg\n";
} # end _error


# ----------------------------------------------------------
# Sub: _store_cdata
#
# Args: $content
#
# Returns: A reference to the CDATA element, padded to 
# original size.
#
# Description: Stores the CDATA element in the internal
# hash, and returns a reference plus padding to replace it
# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 28Aug2001 Added to support CDATA                        JW
# ----------------------------------------------------------
sub _store_cdata {
	my $self = shift;
	my( $content ) = @_;
	my $ref = @{$self->{_CDATA}};
	$self->{_CDATA}[$ref] = $content;
	return $ref . ' ' x (length($content)	- length($ref));
} # end _store_cdata


# ----------------------------------------------------------
# Sub: _dump_tree
#
# Args: $node
#	$node	A starting node, or the root, if not given
#
# Returns: The string to print
#
# Description: Builds a printable tree in a debugging format
# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 06Nov2001 Added for debugging tree                      JW
# ----------------------------------------------------------
sub _dump_tree {
	my $self = shift;
	my $node = shift || $self->{tree};
	
	my $tree = '';
	for( my $i = 0; $i < scalar(@$node) && defined $node->[$i]; $i++ ) {
		if( (scalar(@{$node->[$i]}) == 4) && (defined $node->[$i][2]) ) {
			$tree .= '[' . join( ',', @{$node->[$i]} ) . "] "
					. substr($self->{doc}, $node->[$i][0], $node->[$i][1] - $node->[$i][0] + 1) 
					. "..." 
					. substr($self->{doc}, $node->[$i][2], $node->[$i][3] - $node->[$i][2] + 1) . " (child $i)\n";
			# Do child list
			$i++;
			$tree .= join( '', map( "  $_\n", split( "\n", $self->_dump_tree( $node->[$i] ) ) ) );
		} elsif( (scalar(@{$node->[$i]}) == 4) ) {
			$tree .= '[' . join( ',', $node->[$i][0], $node->[$i][1] ) . "] "
			      . substr($self->{doc}, $node->[$i][0], $node->[$i][1] - $node->[$i][0] + 1) . "\n";
		} else {
			$tree .= "ERROR! Invalid node: [" . join( ',', @{$node->[$i]} ) . "]\n";
		} # end for
	} # end for

	return $tree;
} # end _dump_tree

# module clean-up code here (global destructor)
END { }

1;  # so the require or use succeeds

=back

=head1 BUGS

Lots. This 'parser' (Matt Sergeant takes umbrance to my us of that word) will handle some XML
documents, but not all. 

=head1 VERSION

0.14

=head1 AUTHOR

Jeremy Wadsack for Wadsack-Allen Digital Group (dgsupport@wadsack-allen.com)

=head1 COPYRIGHT

Copyright 2001-2003 Wadsack-Allen. All rights reserved.
This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


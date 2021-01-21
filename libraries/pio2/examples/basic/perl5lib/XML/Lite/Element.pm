############################################################
#
# Module: XML::Lite::Element
#
# Created: 27 August 2001 by Jeremy Wadsack for Wadsack-Allen Digital Group
# Copyright (C) 2001 Wadsack-Allen. All rights reserved.
#
#	TODO
#		* firstChild, lastChild, previousSibling, nextSibling?
#		* Equivalent 'parent' method to return enclosing element.
#		* Could add to_string methods to reproduce original XML content (incl. tags) (requires that original doc be preserved!)
#		* Could add open_tag, close_tag methods to get those parts of content
#
############################################################
# Date        Modification                            Author
# ----------------------------------------------------------
# 08Sep2001 Changed ->{parent} to ->{doc}                 JW
#           Changed ->{_positions} to ->{node}            JW
############################################################
package XML::Lite::Element;

=head1 NAME

XML::Lite::Element - A class representing an XML element in an XML::Lite
document

=head1 SYNOPSIS

use XML::Lite;
my $xml = new XML::Lite( -xml => 'a_file.xml' );
my $elm = $xml->elements_by_name( 'element_name' );
print $elm->get_attribute( 'attribute_name' );

=head1 DESCRIPTION

C<XML::Lite::Element> objects contain rudimentary methods for querying XML 
elements in an XML document as parsed by XML::Lite. Usually these objects 
are returned by method calls in XML::Lite.

=head1 METHODS

The following methods are available. All methods like 'get_name' can be 
abbeviated as 'name.'

=over 4

=cut 

use strict;
BEGIN {
	use vars       qw( $VERSION @ISA );
	$VERSION = '0.14';
	@ISA         = qw();
} # end BEGIN
# non-exported package globals go here
use vars      qw();

############################
## The object constructor ##
############################

=item my $element = new XML::Lite::Element( $owner_document, \@pointers );

Creates a new XML::Lite::Element object from the XML::Lite object, C<$owner_document>.

Currently, you must not call this manually. You can create an object with one of 
the 'factory' methods in XML::Lite, such as C<element_by_name> or C<root_element> 
or with one of the XML::Lite::Element 'factory' methods below, like C<get_children>.

=cut

sub new {
	my $self = {};
	my $proto = shift;
	my $class = ref($proto) || $proto;

	# The arguments are as follows:
	#   $owner_document   is an XML::Lite object within which this element lives
	#   \@pointers        is a two or four element array ref containing the offsets
	#                     into the original document of the start and end points of 
	#                     the opening and closing (when it exists) tags for the element
	
	# Validate arguments
	return undef unless @_ >= 2;
	return undef unless ref($_[0]) && (ref($_[1]) eq 'ARRAY');
	
	# Load 'em up
	
	# The data structure for the ::Element object has these properties
	#   doc               A reference to the containing XML::Lite object
	#   node              A reference to an array of pointers to our element in the document
	#   self              A pointer to our own entry in the owner doc's tree
	#   parent            A pointer to our parent elemenet's entry in the owner doc's tree
	#   name              The name on our tag
	#   _attrs            A string of the attibutes in our tag (unparsed)
	#  attrs              A hash ref of attributes in our tag
	
	$self->{doc} = $_[0];
	$self->{node} = $_[1];
	
	# Using the pointers, find out tag name, and attribute list from the 
	# opening tag (if there are any attributes).
	my $tag = substr( $self->{doc}{doc}, $self->{node}[0], $self->{node}[1] - $self->{node}[0] + 1 );
	if( $tag =~ m{^<\s*([^/>\s]+)\s+([^>]+)\s*/?\s*>$} ) {
		$self->{name} = $1;
		$self->{_attrs} = $2;		# Store the attributes as a scalar. Parse when asked
	} elsif( $tag =~ m{^<\s*([^/>\s]+)\s*/?\s*>$} ) {
		$self->{name} = $1;
		$self->{_attrs} = '';
	} else {
		# Should have been caught in the parsing! maybe an assert?
		$self->{doc}->_error( 'ELM_NOT_CLOSED', $self->{node}[0] + $self->{doc}->{doc_offset} );
	} # end if
	
	# Good. Now returns it.
	bless ($self, $class);
	return $self;
} # end new


##########################
##                      ##
##   Public Methods     ##
##                      ##
##########################

=item my $content = $element->get_content()

Returns the content of the XML element. This may include other XML tags. The
entire content is returned as a scalar.

=cut

# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 28Aug2001 Added CDATA retoration                        JW
# 06Nov2001 Added <.../> optimization                     JW
# ----------------------------------------------------------
sub content;
*content = \&get_content;
sub get_content {
	my $self = shift;

	# If we don't have any content, then we should return 
	# '' right away.
	return '' unless defined $self->{node}[2];
	
	# Using our pointers, find everything between our tags
	my $content = substr( $self->{doc}{doc}, $self->{node}[1] + 1, $self->{node}[2] - $self->{node}[1] - 1 );
	
	# Now, restore any CDATA chunks that may have been pulled out
	$content =~ s/<!\[CDATA\[(\S+)\s*\]\]\/>/<![CDATA[$self->{doc}{_CDATA}[$1]]]>/g;
	
	# And return the content
	return $content;
} # end get_content


=item my %attributes = $element->get_attributes()

Returns a hash of name - value pairs for the attributes in this element.

=cut

# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 13Mar2002 Return empty hash if no attributes           EBK
# 31Jan2003 Fixed docs - return hash, not ref             JW
# ----------------------------------------------------------
sub attributes;
*attributes = \&get_attributes;
sub get_attributes {
	my $self = shift;
	
	# Parse the attribute string into a hash of name-value pairs
	# unless we've already done that.
	$self->_parse_attrs() unless defined $self->{attrs};
	
	# Just return a *copy* of the hash (this is read-only after all!)
       if ( defined($self->{attrs}) ) {
                return %{$self->{attrs}};
       } else {
                my %empty;
                return %empty;
       }
} # end get_attributes

=item my $value = $element->get_attribute( $name )

Returns the value of the named attribute for this element.

=cut

# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# ----------------------------------------------------------
sub attribute;
*attribute = \&get_attribute;
sub get_attribute {
	my $self = shift;
	my( $name ) = @_;
	
	# If we haven't parsed the attribute string into a hash, then do that.
	$self->_parse_attrs() unless defined $self->{attrs};
	
	# Now return the requested attribute. If it's not there
	# then 'undef' is returned
	return $self->{attrs}{$name};
} # end get_attribute


=item my $name = $element->get_name()

Returns the name of the element tag

=cut

# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# ----------------------------------------------------------
sub name;
*name = \&get_name;
sub get_name {
	my $self = shift;
	# Just look it up. We got this in the contructor
	return $self->{name};
} # end get_name


=item my @children = $element->get_children()

Returns a list of XML::Lite::Element objects for each element contained 
within the current element. This does not return any text or CDATA in 
the content of this element. You can parse that through the L<get_content> 
method.

If no child elements exist then an empty list is returned.

=cut

# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 06Sep2001 Added to support tree-like iteration          JW
# 04Nov2001 Changed to get_children (with alias)          JW
# 05Nov2001 Fixed so that it actually works               JW
# 06Nov2001 Added comments, optimizations and bug fixes   JW
# ----------------------------------------------------------
sub children;
*children = \&get_children;
sub get_children {
	my $self = shift;
	my @children = ();

	# If we don't have any content, then we should return an emtpty 
	# list right away -- we have no children.
	return @children unless defined $self->{node}[2];

	# We need to traverse the document tree and find our own node
	# This will also load {children} and {parent} as well
	$self->_find_self() unless defined $self->{self};

	# Now that we know who we are (if this didn't fail) we can 
	# iterate through the sub nodes (our child list) and make 
	# XML::Lite::Elements objects for each child
	if( defined $self->{children} ) {
		my $i = 0;
		my $node = $self->{children}[$i];
		while( defined $node ) {
			push @children, XML::Lite::Element->new( $self->{doc}, $node );
			$i++ if (@$node == 4) && (defined $node->[2]); # Skip element's child list if it exists
			$node = $self->{children}[++$i];
		} # end while
	} # end if
	
	return @children;
} # end get_children


=item my $text = $element->get_text()

Returns a scalar of the text within an element sans children elements.
This effectively takes the content of the element and strips all XML
elements. All text is concatenated into a single string. White space
is preserved. CDATA elements are included without the <![CDATA[ tags.
Other entities are preserved.

=cut

# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 04Nov2001 Added function to get text                   JW
# 06Nov2001 Added <.../> optimization                    JW
# 06Nov2001 Included CDATA text recovery                 JW
# ----------------------------------------------------------
sub text;
*text = \&get_text;
sub get_text {
	my $self = shift;
	my $content = '';

	# If we don't have any content, then we should return  
	# $content right away -- we have no text
	return $content unless defined $self->{node}[2];

	# Otherwise get out content and children
	my @children = $self->get_children;
	my $orig_content = $self->get_content;
	
	# Then remove the child elements from our content
	my $start = 0;
	foreach( @children ) {
		my $end = $_->{node}[0] - $self->{node}[1] - 1;
		$content .= substr( $orig_content, $start, $end - $start);
		$start = ($_->{node}[3] || $_->{node}[1]) - $self->{node}[1];
	} # end foreach
	$content .= substr( $orig_content, $start ) if $start < length($orig_content);
	
	# Remove the CDATA wrapper, preserving the content
	$content =~ s/<!\[CDATA\[(.+?)]\]>/$1/g;
	
	# Return the left-over text
	return $content;
} # end get_text

##########################
##                      ##
##   Private Methods    ##
##                      ##
##########################
# ----------------------------------------------------------
# Sub: _parse_attrs
#
# Args: (None)
#
# Returns: True value on success, false on failure
#
# Description: Pares the attributes in the element into a hash
# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 18Nov2006 Allow whitespace between = and attribute     BEE
#           value.  Allow values to use either single
#           or double quotes.
# 08Apr2002 Allow null strings as valid values           BEE
# 13Mar2002 Don't do anything if not defined             EBK
# ----------------------------------------------------------
sub _parse_attrs {
	my $self = shift;
	
	my $attrs = $self->{_attrs};
	if ( defined($attrs) ) {
		$attrs =~ s/^\s+//;
		$attrs =~ s/\s+$//;
		$self->{attrs} = {};
		while( $attrs =~ s/^(\S+)\s*=\s*["']([^"]*)["']// )    #" For syntax highlighter
		{
			$self->{attrs}{$1} = $2;
			$attrs =~ s/^\s+//;
		} # end while
	}
	
	return 1;
} # end _parse_atttrs

# ----------------------------------------------------------
# Sub: _find_self
#
# Args: (None)
#
# Returns: A reference to our node or undef on error
#
# Description: Traverses the owner document's tree to find
# the node that references the current element. Sets 
# $self-{self} as a side-effect. Even if this is already set,
# _find_self will traverse again, so don't call unless needed.
# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 06Nov2001 Added to support children() method            JW
# 13Mar2002 Check that nodes are defined                  EBK
# ----------------------------------------------------------
sub _find_self {
	my $self = shift;
	
	# We actually just call this recusively, so the first 
	# argument can be a starting point to descend from
	# but we don't doc that above
	my $node = shift || $self->{doc}{tree};
	return undef unless defined $node;

	# Our owner XML::Lite document has a tree (list of lists) that
	# tracks all elements in the document. Starting at the root
	# of the tree, walk through each node until we find one with
	# the same offsets as our $self->{node} has.

	# Walk through the nodes in this node and compare to our selves
	for( my $i = 0; $i < scalar(@$node) && defined $node->[$i]; $i++ ) {

		# If this is our self, then we're done!
		# 	NOTE: Since the list references are the same in the by-name hash
		# 	and tree objects, we can just do a reference compare here.
		# 	If objects are ever created with non-factory methods then we need to 
		# 	use a _compare_lists call.
# 		if( _compare_lists( $node->[$i], $self->{node} ) ) { 
 		if( $node->[$i] eq $self->{node} ) { 
			$self->{parent} = $node;
			$self->{self} = $node->[$i];
			# If this list has children, then add a pointer to that list
			$self->{children} = $node->[$i + 1] if (scalar(@{$node->[$i]}) == 4) && (defined $node->[$i][2]);
 			last;
 		} # end if

		# For efficiency, we only need look at nodes that start before
		# our node does
		if ( defined($node->[$i][0]) && defined($self->{node}->[3]) ) {
			last if $node->[$i][0] > ($self->{node}->[3] || $self->{node}->[1]);
		}

		# If this is a node with content (start and end tag) then check children
		if( (scalar(@{$node->[$i]}) == 4) && (defined $node->[$i][2]) ) {
			# This is a node with content (start and end tag)
			# So look at the child node list that follows and see what it's got
 			$i++;
			last if defined $self->_find_self( $node->[$i] );
		} # end for

	} # end for

	# And return it
	return $self->{self};
} # end _find_self

# ----------------------------------------------------------
# Sub: _compare_lists
#
# Args: $list_ref_1, $list_ref_2
#
# Returns: True if the same elements, false otherwise
#
# Description: Compare the contents of two lists and returns
# whether they are the same
# NOTE: This is a CLASS METHOD (or sub)
# ----------------------------------------------------------
# Date      Modification                              Author
# ----------------------------------------------------------
# 06Nov2001 Added to support node lookups                 JW
# ----------------------------------------------------------
sub _compare_lists {
	my( $rA, $rB ) = @_;
	
	# Lists are not equal unless same size
	return 0 unless scalar(@$rA) == scalar(@$rB);
	
	# Now compare item by item.
	my $i;
	for( $i = 0; $i < scalar(@$rA); $i++ ) {
		return 0 unless $rA->[$i] eq $rB->[$i];
	} # end for
	
	return 1;
} # end _compare_lists

# module clean-up code here (global destructor)
END { }

1;  # so the require or use succeeds

=back

=head1 VERSION

0.14

=head1 AUTHOR

Jeremy Wadsack for Wadsack-Allen Digital Group (dgsupport@wadsack-allen.com)

=head1 COPYRIGHT

Copyright 2001 Wadsack-Allen. All rights reserved.
This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


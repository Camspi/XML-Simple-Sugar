use 5.18.2;
use Modern::Perl;
use Moops;

class XML::Simple::Sugar 1.0.3 {
    our $AUTOLOAD;
    use XML::Simple;
    use UNIVERSAL::isa;
    use Data::Dumper;

    has 'xml_index' => ( 'is' => 'ro', 'isa' => 'Int', default => 0 );
    has 'xml_node'  => ( 'is' => 'ro', 'isa' => Maybe[Str] );
    has 'xml_xs'    => (
        'is'      => 'rw',
        'isa'     => 'XML::Simple',
        'default' => sub { XML::Simple->new( XMLDecl => '<?xml version="1.0"?>' ); }
    );
    has 'xml_data' => (
        'is'      => 'rw',
        'isa'     => Maybe[HashRef|ArrayRef],
        'default' => method { $self->xml_data ? $self->xml_data : {}; }
    );
    has 'xml_parent' => ( 'is' => 'ro', 'isa' => InstanceOf['XML::Simple::Sugar'] );
    has 'xml_autovivify' => ( 'is' => 'rw', 'isa' => Bool, default => 1 );
    has 'xml' => (
        'is'      => 'rw',
        'isa'     => Str,
        'trigger' => method {
            $self->xml_data(
                XMLin(
                    $self->xml,
                    ForceContent => 1,
                    KeepRoot     => 1,
                    ForceArray   => 1,
                    ContentKey   => 'xml_content',
                )
            );
        }
    );

    method xml_write {
        return $self->xml_xs->XMLout(
            $self->xml_root->xml_data,
            KeepRoot   => 1,
            ContentKey => 'xml_content',
        );
    }

    method xml_read (Str $xml) {
        $self->xml_data(
            $self->xml_xs->XMLin(
                $xml,
                ForceContent => 1,
                KeepRoot     => 1,
                ForceArray   => 1,
                ContentKey   => 'xml_content',
            )
        );
        return $self;
    }

    method xml_root {
        if ( defined( $self->xml_parent ) ) {
            return $self->xml_parent->xml_root;
        }
        else {
            return $self;
        }
    }

    multi method xml_attr (HashRef $attr) {
        foreach my $attribute (keys %$attr) {
            if (
                $self->xml_autovivify
                || grep( /^$attribute$/,
                    keys %{
                        $self->xml_parent->xml_data->{ $self->xml_node }
                          ->[ $self->xml_index ]
                    } )
              )
            {
                $self->xml_parent->xml_data->{ $self->xml_node }
                  ->[ $self->xml_index ]->{$attribute} =
                  $attr->{$attribute};
            }
            else {
                die qq|$attribute is not an attribute of | . $self->xml_node;
            }
        }
        return $self;
    }

    multi method xml_attr () {
        my %attr;
        foreach ( keys %{ $self->xml_data } ) {
            $attr{$_} = $self->xml_data->{$_}
              if ( !( UNIVERSAL::isa( $self->xml_data->{$_}, 'ARRAY' ) ) );
        }
        return \%attr;
    }

    method xml_rmattr (Str $attr) {
        delete $self->xml_parent->xml_data->{ $self->xml_node }
          ->[ $self->xml_index ]->{$attr};
        return $self;
    }

    method xml_content (Str $content?) {
        if ($content) {
            $self->xml_data->{xml_content} = $content;
            return $self;
        }
        else {
            $self->xml_data->{xml_content};
        }
    }

    method xml_nest (InstanceOf['XML::Simple::Sugar'] $xs) {
        $self->xml_parent->xml_data->{ $self->xml_node }->[ $self->xml_index ]
          = $xs->xml_data;
        return $self;
    }

    multi method xml_subnode (Str $node, InstanceOf['XML::Simple::Sugar'] $content) {
        $self->xml_data->{$node}->[ $self->xml_index ] = $content->xml_data;
    }

    multi method xml_subnode (Str $node, HashRef $content) {
        foreach my $attribute (keys %$content) {
            if ( UNIVERSAL::isa( $self->xml_data->{$node}, 'ARRAY' ) ) {
                if (
                    $self->xml_autovivify
                    || grep( /^$attribute$/,
                        keys %{
                            $self->xml_data->{$node}->[ $self->xml_index ]
                        } )
                  )
                {
                    $self->xml_data->{$node}->[ $self->xml_index ]
                      ->{$attribute} = $content->{$attribute};
                }
                else {
                    die qq|$attribute is not an attribute of $node|;
                }
            }
            else {
                if (
                    $self->xml_autovivify
                    || grep( /^$attribute$/,
                        keys %{ $self->xml_data->{$node} } )
                  )
                {
                    $self->xml_data->{$node}->{$attribute} =
                      { 'value' => $content->{$attribute} };
                }
                else {
                    die qq|$attribute is not an attribute of $node|;
                }
            }
        }
        return $self;
    }

    multi method xml_subnode (Str $node, ArrayRef $content) {
        if ( $content->[0] =~ m/^[0-9]+$/ )
        {
            if ( $self->xml_autovivify ) {
                unless ( $self->xml_data->{$node} ) {
                    $self->xml_data->{$node} = [];
                }
                unless (
                    UNIVERSAL::isa(
                        $self->xml_data->{$node}->[ $content->[0] ], 'HASH'
                    )
                  )
                {
                    $self->xml_data->{$node}->[ $content->[0] ] = {};
                }
            }
            else {
                unless ( $self->xml_data->{$node} ) {
                    die qq|$node not in |
                      . Data::Dumper::Dumper( $self->xml_data );
                }
                unless (
                    UNIVERSAL::isa(
                        $self->xml_data->{$node}->[ $content->[0] ], 'HASH'
                    )
                  )
                {
                    die qq|Element $content->[0] not in |
                      . Data::Dumper::Dumper( $self->xml_data->{$node} );
                }
            }
            my $xs = XML::Simple::Sugar->new(
                {
                    xml_node => $node,
                    xml_data => $self->xml_data->{$node}->[ $content->[0] ],
                    xml_parent     => $self,
                    xml_autovivify => $self->xml_autovivify,
                    xml_index      => $content->[0]
                }
            );
            if ( defined( $content->[1] )
                && UNIVERSAL::isa( $content->[1], InstanceOf['XML::Simple::Sugar'] ) )
            {
                $xs->xml_nest( $content->[1] );
            }
            elsif ( defined( $content->[1] ) ) {
                $xs->xml_content( $content->[1] );
            }
            if ( defined( $content->[2] )
                && UNIVERSAL::isa( $content->[2], 'HASH' ) )
            {
                $xs->xml_attr( $content->[2] );
            }
            return $xs;
        }
        elsif ( $content->[0] =~ m/^all$/i )
        {
            if ( UNIVERSAL::isa( $self->xml_data->{$node}, 'ARRAY' ) ) {
                return map {
                    XML::Simple::Sugar->new(
                        {
                            xml_node   => $node,
                            xml_data   => $self->xml_data->{$node}->[$_],
                            xml_parent => $self,
                            xml_autovivify => $self->xml_autovivify,
                            xml_index      => $_
                        }
                    );
                } 0 .. scalar @{ $self->xml_data->{$node} } - 1;
            }
        }
    }
    
    multi method xml_subnode (Str $node, Str $content) {
        $self->xml_data->{$node}->[0]->{xml_content} = $content;
        return $self;
    }

    multi method xml_subnode (Str $node) {
        unless ( $self->xml_data->{$node} ) {
            if ( $self->xml_autovivify == 1 ) {
                $self->xml_data->{$node}->[0] = {};
            }
            else {
                die qq|$node not in |
                  . Data::Dumper::Dumper( $self->xml_data );
            }
        }

        if ( UNIVERSAL::isa( $self->xml_data->{$node}, 'ARRAY' ) ) {
            return XML::Simple::Sugar->new(
                {
                    xml_node       => $node,
                    xml_data       => $self->xml_data->{$node}->[0],
                    xml_parent     => $self,
                    xml_autovivify => $self->xml_autovivify,
                    xml_index      => $self->xml_index
                }
            );
        }
        else {
            return XML::Simple::Sugar->new(
                {
                    xml_node       => $node,
                    xml_data       => $self->xml_data->{$node},
                    xml_parent     => $self,
                    xml_autovivify => $self->xml_autovivify,
                    xml_index      => $self->xml_index
                }
            );
        }
    }

    method AUTOLOAD ($content?) {
        my ($node) = $AUTOLOAD =~ m/([^:]*)$/;
        $content ? $self->xml_subnode($node, $content) : $self->xml_subnode($node);
    }
}

1;

# ABSTRACT: Sugar sprinkled on XML::Simple
# PODNAME: XML::Simple::Sugar

=head1 SYNOPSIS

The basics...

    use Modern::Perl;
    use Data::Dumper;
    use XML::Simple::Sugar;
    
    my $xs = XML::Simple::Sugar->new();
    
    #Autovivify some elements nested within each other, and set the content of the salary element
    $xs->company->departments->department([0])->person([0])->salary(60000);
    
    my $departments = $xs->company->departments;
    $departments->department([0])->xml_attr({ name => 'IT Department', manager => 'John Smith' });

    say $xs->xml_write;

    # Or from a child element... (returns a string reflecting the root element's XML)
    say $departments->xml_write;
 
Working with existing XML

    my $xs = XML::Simple::Sugar->new({ xml => '<your_xml>here</your_xml>' });

Setting and retrieving content/attributes

    # Return all person elements in the first department element and say their first names
    map{ say $_->first_name->xml_content; } $xs->company->departments->department([0])->person(['all']);
    
    # Setting the content of elements
    my $person = $xs->company->departments->department([0])->person([0]);
    $person->first_name('John')->last_name('Smith')->email('jsmith@example.com');
    # Or, using xml_content...
    $person->first_name->xml_content('John');
    say $person->first_name->xml_content;

    # Setting attributes of an element
    $xs->company->departments->department([0])->person([0])->salary({ 'jobgrade' => 10, 'exempt' => 1 });
    # Or, using xml_attr...
    $person->xml_attr({ skill => 'Perl', skill_level => 'intermediate'  });
    say Data::Dumper::Dumper($person->xml_attr);
    
    # Or setting the string contents of an element and attribute values all at once...
    $person->first_name([0,'John',{'is_nice' => 'true'}]);
 
Composing larger documents from other XML::Simple::Sugar objects

    my $xs=XML::Simple::Sugar->new();
    my $xs2=XML::Simple::Sugar->new();
    $xs2->table->tr->th([0,'First Name',{ style => 'text-align:left' }]);
    $xs2->table->tr->th([1,'Last Name']);
    $xs->html->body->div->h1('Page Title')->xml_attr({ style => 'font-weight:bold' });
    $xs->html->body->div([1,$xs2]);

=head1 DESCRIPTION

This module is a wrapper around L<XML::Simple> to provide AUTOLOADed accessors to XML nodes.  

=head1 WHY ANOTHER XML MODULE?

I wanted to write/manipulate simple XML payloads with more DWIMmery than what I found in modules available on CPAN (admittedly I didn't look very hard).  If the above syntax doesn't accomplish that for you, you should probably use a different module.

Additionally, this package depends on L<XML::Simple>, which currently has a "do not use this module in new code" notice.  If you are cool with that, then so am I. :)

=head1 PLEASE BE ADVISED

Most of the automagic happens with AUTOLOAD.  Accessors/mutators and method names in this package cannot be used as element names in the XML document.  XML naming rules prohibit the use of elements starting with the string "xml", so I've used this string as a prefix to all accessors/mutators/methods to avoid potential conflicts with AUTOLOAD.  Sorry for the extra characters. :/ 

=head1 ATTRIBUTES

=head2 xml_autovivify (bool)

This attribute determines on a per element basis whether new attributes or elements may be introduced.  Child elements inherit this setting from their parent.  Setting autovivify to false is useful when working with templates with a strict predefined XML structure. This attribute is true by default.

=head2 xml_data (XML::Simple compliant Perl representation of an XML document)

This is the Perl representation of the XML.  This is ugly to work with directly (hence this module), but in lieu of methods yet unwritten there may be a use case for having direct access to this structure.

=head2 xml_index

The index number of an element in a collection 

=head2 xml_node

The name of the current node

=head2 xml_parent

The parent XML::Simple::Sugar object to the current element

=head2 xml

This readonly attribute is only useful during instantiation (XML::Simple::Sugar->new({ xml => $xml_string })).  This is primarily intended for working with XML templates, or XML service responses.

=head2 xml_xs

This is underlying XML::Simple object.  If you need to adjust the XML declaration, you can do that by passing an an XML::Simple object with your preferred options to the constructor.  Be wary of setting other XML::Simple options as this module will happily overwrite anything that conflicts with its assumptions.

=head2 xml_root

Returns the root element XML::Simple::Sugar object

=head2 xml_content (String)

Returns the content of the current element

=head1 METHODS

=head2 xml_read (XML String)

Parses an XML string and sets the data attribute

=head2 xml_write

Writes out an XML string

=head2 xml_attr (HashRef)

If passed a hash reference, this method will set the attributes of the current element. Otherwise, this method returns a hash reference representing the current element's attributes.

=head2 xml_rmattr (String)

This method removes the passed scalar argument from the element's list of attributes.

=head2 xml_nest (XML::Simple::Sugar)

Merges another XML::Simple::Sugar object as a child of the current node.

=head1 REPOSITORY

L<https://github.com/Camspi/XML-Simple-Sugar>

=head1 MINIMUM PERL VERSION SUPPORTED

Perl 5.18.2 or later is required by this module.  Lesser Perl versions struggle with deep recursion.  Patches welcome.

=head1 VERSIONING

Semantic versioning is adopted by this module. See L<http://semver.org/>.

=head1 SEE ALSO

=over 4

=item 
* L<XML::Simple>

=back

=head1 CREDITS

=over 4

=item 
* Jonathan Cast for excellent critique.

=item 
* Kyle Bolton for peeking over my shoulder and giving me pro tips.

=item 
* eMortgage Logic, LLC., for allowing me to publish this module to CPAN

=back

=cut

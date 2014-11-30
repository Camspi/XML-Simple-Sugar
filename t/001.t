use v5.18.2;
use Test::More;
use Test::Exception;
use strict;
use warnings;
use UNIVERSAL::isa;

BEGIN { use_ok('XML::Simple::Sugar'); }

xml_read_and_xml_write();
attr_rmattr();
autovivify();
content();
collections();
done_testing();

sub xml_read_and_xml_write {
    my $xs = XML::Simple::Sugar->new();
    $xs->xml_read('<foo><bar baz="biz">abc</bar></foo>');
    my %data   = %{ $xs->xml_data };
    my $xml    = $xs->xml_write;
    my $xs_2   = XML::Simple::Sugar->new()->xml_read($xml);
    my %data_2 = %{ $xs_2->xml_data };
    is_deeply( \%data, \%data_2,
        'Internal data structures consistent pre and post write' );
}

sub autovivify {
    my $xs = XML::Simple::Sugar->new();
    lives_ok( sub {
        $xs->company->departments( { 'name' => 'IT Department' } )
          ->department( [0] )->person( [0] )->salary(60000);
    }, 'Can autovivify' );

    my $xs_2 = XML::Simple::Sugar->new(
        { xml_autovivify => 0, xml => '<foo><bar baz="biz">abc</bar></foo>' } );
    eval { $xs_2->foo->def };
    ok( $@, 'Can use strict (elements)' );
    eval { $xs_2->foo->bar( { 'another' => 'attribute' } ); };
    ok( $@, 'Can use strict (attributes)' );
}

sub content {
    my $xs = XML::Simple::Sugar->new(
        { xml => '<foo><bar baz="biz">abc</bar></foo>' } );
    ok( $xs->foo->bar->xml_content eq 'abc', 'Can fetch content' );
    $xs->foo->bar('def');
    ok( $xs->foo->bar->xml_content eq 'def', 'Can change content' );

    my $xs2 = XML::Simple::Sugar->new();
    my $xs3 = XML::Simple::Sugar->new();
    $xs3->table->tr->th('title');
    $xs2->html->body->div($xs3);
    my $xml =
q|<html><body><div><table><tr><th>title</th></tr></table></div></body></html>|;
    my $xs4 = XML::Simple::Sugar->new( { xml => $xml } );

    is_deeply( $xs2->xml_data, $xs4->xml_data,
        'Can nest XML::Simple::Sugar objects' );

    my $xs5 = XML::Simple::Sugar->new();
    my $xs6 = XML::Simple::Sugar->new();
    $xs6->table->tr->th('title');
    $xs5->html->body->div->xml_nest($xs6);
    my $xs7 = XML::Simple::Sugar->new( { xml => $xml } );

    is_deeply( $xs5->xml_data, $xs7->xml_data,
        'Can nest XML::Simple::Sugar objects with xml_nest' );

    my $xs8 = XML::Simple::Sugar->new();
    my $xs9 = XML::Simple::Sugar->new();
    $xs9->table->tr->th('title');
    $xs8->html->body->div([ 0, $xs6 ]);
    my $xs10 = XML::Simple::Sugar->new( { xml => $xml } );

    is_deeply( $xs8->xml_data, $xs10->xml_data,
        'Can nest XML::Simple::Sugar objects with []' );
}

sub collections {
    my $xs          = XML::Simple::Sugar->new();
    my $departments = $xs->company->departments;
    my $person = $xs->company->departments->department( [0] )->person( [0] );
    $person->first_name('John')->last_name('Smith')
      ->email('jsmith@example.com');
    my $person_2 = $xs->company->departments->department( [0] )->person( [1] );
    $person_2->first_name('Kelly')->last_name('Smith')
      ->email('ksmith@example.com');
    ok(
        $xs->company->departments->department( [0] )->person( [1] )
          ->first_name->xml_content eq 'Kelly',
        'Can set/access elements by index'
    );
    my @xs = $xs->company->departments->department( [0] )->person( ['all'] );
    ok( scalar @xs == 2, 'Can fetch all elements in a collection' );
    ok(
        $xs->company->departments->department( [0] )->person( [1] )
          ->first_name( [ 1, 'John' ] )->xml_content eq 'John',
        'Can set/access elements by index array'
    );
    is_deeply(
        $xs->company->departments->department( [0] )
          ->person( [ 1, undef, { 'Is_Nice' => 'Yes' } ] )->xml_attr,
        { 'Is_Nice' => 'Yes' },
        'Can set/access attributes by index array'
    );
}

sub attr_rmattr {
    my $xs          = XML::Simple::Sugar->new();
    my $departments = $xs->company->departments;
    $xs->company->departments( { 'name' => 'IT Department' } );
    my $attr = $xs->company->departments->xml_attr;
    ok( $attr->{'name'} eq 'IT Department', 'Can set attributes' );
    $xs->company->departments->xml_rmattr('name');
    $attr = $xs->company->departments->xml_attr;
    ok( !defined( $attr->{'name'} ), 'Can remove attributes' );
}

# Test that our Moose implementation of PSGI::Application Class::ISA logic is correct;
# We skip test if Class::ISA is not installed.

package ClassGrandParent;
sub foo {};
1;

package ClassParent;
use base 'ClassGrandParent';

package ClassChild;
use base 'ClassParent';

####

package MooseGrandParent;
use Any::Moose;

package MooseParent;
use Any::Moose;
extends 'MooseGrandParent';

package MooseChild;
use Any::Moose;
extends 'MooseParent';

package main;
use Test::More;

eval { require Class::ISA };
plan skip_all => 'No Class::ISA' if $@;

my @class_isa = Class::ISA::self_and_super_path('ClassChild');
my @moose_isa = MooseChild->meta->linearized_isa;
pop @moose_isa; # don't count the '::Object' Class

for (@class_isa) { s/Class// }
for (@moose_isa) { s/Moose// }



is_deeply(\@moose_isa,\@class_isa
    , '->meta->linearized_isa returns classes in the same order as Class::ISA and also includes the current class');



done_testing();

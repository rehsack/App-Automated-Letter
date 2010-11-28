package App::Automated::Letter;

use warnings;
use strict;

=head1 NAME

App::Automated::Letter - App to create automated letters (e.g. circular)

=cut

our $VERSION = '0.001';

use App::Cmd::Setup -app;

=head1 SYNOPSIS

  # create a serial letter
  serial letter --addressdb address.csv --template template.tex --body body.tex
  # create only serial cover
  serial cover --addressdb address.csv --template template.tex

=head1 DESCRIPTION

App::Automated::Letter provides a command line tool to generate some
serial printings.

=head1 AUTHOR

Jens Rehsack, C<< <rehsack at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-app-serial-letter at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Automated-Letter>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::Automated::Letter

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Automated-Letter>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Automated-Letter>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-Automated-Letter>

=item * Search CPAN

L<http://search.cpan.org/dist/App-Automated-Letter/>

=back

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Jens Rehsack.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of App::Automated::Letter

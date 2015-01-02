#!/usr/bin/perl
use strict;
use warnings;
use Switch;
use WWW::Mechanize;
use HTTP::Cookies;
use HTTP::Status qw(:constants :is status_message);
use URI;
use URI::QueryParam;
use Carp qw( confess );
$SIG{__DIE__} = \&confess;
$SIG{__WARN__} = \&confess;

package KohaWebInstallAutomation;

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless $self, $class;
    $self->init(@args);
    return $self;
}

sub init {
    my ($self, @args) = @_;
    %{$self} = (
                uri => 'http://localhost:8081',
                path => '/',
                user => 'admin',
                pass => 'secret',
                previousStep => 0,
                mech => '',
                @args,
               );
    $self->test_response_code();
}

sub test_response_code {
    my $self = shift;
    my $mech = WWW::Mechanize->new(autocheck => 0);
    $mech->max_redirect(0);
    $mech->agent('User-Agent=Mozilla/5.0 Gecko/20091102 Firefox/3.5.5');
    $mech->cookie_jar(HTTP::Cookies->new);
    $mech->get($self->{uri});
    $mech->max_redirect(3);     # re-enable redirect
    # Test header for location redirect
    if (::is_redirect($mech->status()) ) {
        # Redirect to webinstaller by new GET request
        $self->{path} = $mech->response()->headers()->{location};
        $mech->get($self->{uri} . $self->{path});
        $self->{mech} = $mech;
        clickthrough_installer($self);
    } elsif (::is_success($mech->status()) ) {
        $mech->get($self->{uri});
        # If you are not redirected OR faced with a 200 Sorry! maintenance
        # page it is already installed
        if ( $self->{uri} eq $mech->{uri} && $mech->{content} !~ "maintenance" ) {
            print "{\"comment\":\"Instance is already installed\"}";
            # If you are not redirected AND faced with a 200 Sorry!
            # maintenance page you need to run webinstaller
        } elsif ( $self->{uri} eq $mech->{uri} && $mech->{content} =~ "maintenance" ) {
            $self->{path} = "/cgi-bin/koha/installer/install.pl";
            $mech->get($self->{uri} . $self->{path});
            $self->{mech} = $mech;
            clickthrough_installer($self);
        } else {
            die "{\"comment\":\"HTTPSuccess, but it is unclear how we got to "
              . $mech->{uri} . "\"}";
        }
    } else {
        die "{\"comment\":\"Request failed. URI: $mech->response()->headers()->{location}\"}";
    }
}

sub clickthrough_installer {
    my $self = shift;
    # Get step param
    my $uri = URI->new($self->{mech}->{uri});
    my $step = $uri->query_param("step");
    switch($step){
        case 1 { step_one($self) }
          case 2 { step_two($self) }
          case 3 { step_three($self) }
          else {
              step_one($self);
          }
    }
}

sub do_login {
    my $self = shift;
    $self->{mech}->submit_form( with_fields => {
                                                userid => $self->{user},
                                                password => $self->{pass},
                                               });
}

sub step_one {
    my $self = shift;
    if ( $self->{previousStep} != 0 ) {
        die "{\"comment\":\"Error step one: expected previous step to be 0, but got "
          . $self->{previousStep} . "\"}";
    }
    do_login($self);
    $self->{mech}->submit_form( form_name => "language" );
    $self->{mech}->submit_form( form_name => "checkmodules" );
    $self->{path} = '/cgi-bin/koha/installer/install.pl?step=2';
    $self->{previousStep} = 1;
    clickthrough_installer($self);
}

sub step_two {
    my $self = shift;
    if ( $self->{previousStep} != 1 ) {
        die "{\"comment\":\"Error step two: expected previous step to be 1, but got "
          . $self->{previousStep} ."\"}";
    }
    $self->{mech}->submit_form( form_name => "checkinformation" );
    $self->{mech}->submit_form( form_name => "checkdbparameters" );
    $self->{mech}->submit_form();
    $self->{mech}->submit_form();
    $self->{mech}->follow_link( url => "install.pl?step=3&op=choosemarc" );
    $self->{mech}->set_fields( marcflavour => "MARC21");
    $self->{mech}->submit_form( form_name => "frameworkselection");
    $self->{mech}->submit_form( form_name => "frameworkselection"); # yes, it occurs twice
    $self->{previousStep} = 2;
    step_three($self);
}

sub step_three {
    my $self = shift;
    if ( $self->{previousStep} == 0 ) {
        do_login($self);
        $self->{mech}->follow_link( url => "install.pl?step=3&op=updatestructure" );
    } elsif ( $self->{previousStep} == 2 ) {
        $self->{mech}->submit_form();
    } else {
        die "{\"comment\":\"Error in webinstaller step three: " . $_ . "\"}";
    }
    print "{\"comment\":\"Successfully completed the install process\"}";
}

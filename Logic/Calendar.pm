package Logic::Calendar;
use strict;
use warnings;
use utf8;
use base qw/Class::Accessor::Fast/;
use Carp qw/croak/;
use Date::Simple qw/date/;
use HTTP::Date qw/time2isoz/;
use Google::API::Client;
use OAuth2::Client;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/
client_id
client_secret
redirect_uri
/);

my $_service = undef;
my $_auth_driver = undef;

## -- instance method

sub get_service_instance {
  my $self = shift;
  return $_service if $_service;
  return $_service = Google::API::Client->new->build('calendar', 'v3');
}

sub get_auth_driver_instance {
  my $self = shift;
  return $_auth_driver if $_auth_driver;
  my @requires = qw/client_id client_secret redirect_uri/;
  for (@requires) {
    my $func = "get_$_";
    croak "$_ is required." unless $self->$func();
  }
  return $_auth_driver = OAuth2::Client->new({
    auth_uri => Google::API::Client->AUTH_URI,
    token_uri => Google::API::Client->TOKEN_URI,
    client_id => $self->get_client_id(),
    client_secret => $self->get_client_secret(),
    redirect_uri => $self->get_redirect_uri(),
    auth_doc => $self->get_service_instance()->{auth_doc},
  });
}

sub get_authorize_uri {
  my $self = shift;
  return $self->get_auth_driver_instance()->authorize_uri();
}

sub get_token_obj {
  my $self = shift;
  my ($code) = @_;
  return $self->get_auth_driver_instance()->exchange($code);
}

sub set_token_obj {
  my $self = shift;
  my ($token_obj) = @_;
  $self->get_auth_driver_instance()->{token_obj} = $token_obj;
}

sub get_calendar_list {
  my $self = shift;
  my @calendar_list = ();
  my $res = $self->get_service_instance()
    ->calendarList
    ->list
    ->execute({ auth_driver => $self->get_auth_driver_instance() });
  push @calendar_list, $_ for (@{$res->{items}});
  return \@calendar_list;
}

# TODO: support pageToken
sub get_event_list {
  my $self = shift;
  my ($id, $timeMin, $timeMax) = @_;
  my @event_list = ();
  my $res = $self->get_service_instance()
    ->events
    ->list( body => +{
      calendarId    => $id,
      timeMin       => $timeMin,
      timeMax       => $timeMax,
      orderBy       => 'startTime',
      singleEvents  => 'true',
    })
    ->execute({ auth_driver => $self->get_auth_driver_instance() });
  push @event_list, $_ for (@{$res->{items}});
  return \@event_list;
}

sub get_calendar_event_list {
    my $self = shift;
    my ($ids, $timeMin, $timeMax) = @_;
    my $event_list = +[];
    for my $id (@$ids) {
        push @$event_list, @{$self->get_event_list($id, $timeMin, $timeMax)};
    }
    return $event_list;
}

## -- functions

sub date2iso8601z {
    my ($date) = @_;
    my $str = time2isoz(date($date)->strftime('%s'));
    $str =~ s/ /T/g; # convert date-time delimiter from white-space to 'T'
    return $str;
}

1;
__END__


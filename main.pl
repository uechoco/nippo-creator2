use strict;
use warnings;
use utf8;
use Mojolicious::Lite;
use Date::Simple qw/today date/;
use Logic::Calendar;

plugin 'yaml_config' => +{
  class => 'YAML::Tiny',
};

my $calendar = Logic::Calendar->new(+{
  client_id     => app->config->{app->mode}->{oauth_client_id},
  client_secret => app->config->{app->mode}->{oauth_client_secret},
  redirect_uri  => app->config->{app->mode}->{oauth_redirect_url},
});

# =============================================================
# Pages
# =============================================================

# GET /
get '/' => sub {
  my $self = shift;
  $self->render('top');
} => 'top';

# GET /callback?code=param
get '/callback' => sub {
  my $self = shift;
  my $code = $self->param('code');
  my $token_obj = $calendar->get_token_obj($code);
  save_token_obj_to_session($self, $token_obj);
  $self->redirect_to('/step1');
} => 'callback';

# GET /logout
get '/logout' => sub {
  my $self = shift;
  delete_token_obj_from_session($self);
  $self->redirect_to('/');
} => 'logout';

# GET|POST /step1
any ['GET', 'POST'] => '/step1' => sub {
  my $self = shift;
  return unless login_or_redirect($self);

  if ($self->req->method eq 'POST') {
    # TODO validation
    my $params = get_step1_params($self);
    $self->session->{step1_params} = $params;
    $self->redirect_to('/step2');
  }

  my $calendar_list = $calendar->get_calendar_list();
  my ($used_list, $unused_list) = (+[], +[]);
  my $feeds = +[$self->param('feeds')];
  for my $cal (@$calendar_list) {
    scalar(grep {$cal->{id} eq $_} @$feeds)
      ? push(@$used_list, +[ $cal->{summary} => $cal->{id} ])
      : push(@$unused_list, +[ $cal->{summary} => $cal->{id} ]); 
  }
  my $today = today();
  $self->stash('used_list', $used_list);
  $self->stash('unused_list', $unused_list);
  $self->stash('today_str', $today->format("%Y-%m-%d"));
  $self->stash('tomorrow_str', $today->next->format("%Y-%m-%d"));
  $self->render('step1');
} => 'step1';

# GET /step2
get '/step2' => sub {
  my $self = shift;
  return unless login_or_redirect($self);
  return $self->redirect_to('/step1') unless defined $self->session->{step1_params};
  my $step1_params = $self->session->{step1_params};
  my $event_list = $calendar->get_calendar_event_list(
    $step1_params->{feeds},
    Logic::Calendar::date2iso8601z($step1_params->{begin_date}),
    Logic::Calendar::date2iso8601z($step1_params->{next_date})
  );
  $self->stash('begin_date', date($step1_params->{begin_date})->format('%Y/%m/%d'));
  $self->stash('name', $step1_params->{name});
  $self->stash('event_list', $event_list);
  $self->render('step2/original_ja');
} => 'step2';

# =============================================================
# Logics
# =============================================================

sub login_or_redirect {
  my ($c) = @_;
  my $token_obj = load_token_obj_from_session($c);
  defined $token_obj
    ? $calendar->set_token_obj($token_obj)
    : $c->redirect_to($calendar->get_authorize_uri());
  return defined $token_obj;
}

sub save_token_obj_to_session {
  my ($c, $token_obj) = @_;
  for (qw/expires_in access_token token_type/) {
    $c->session->{$_} = $token_obj->{$_};
  }
}

sub load_token_obj_from_session {
  my ($c) = @_;
  my %token_obj = ();
  my $is_valid = 1;
  for (qw/expires_in access_token token_type/) {
    $token_obj{$_} = $c->session($_);
    $is_valid = 0 unless $token_obj{$_};
  }
  return $is_valid ? \%token_obj : undef;
}

sub delete_token_obj_from_session {
  my ($c) = @_;
  for (qw/expires_in access_token token_type/) {
    delete $c->session->{$_};
  }
}

sub get_step1_params {
  my ($c) = @_;
  my $params = +{};
  for (qw/name begin_date next_date/) {
    $params->{$_} = $c->param($_);
  }
  for (qw/feeds/) {
    $params->{$_} = +[$c->param($_)];
  }
  return $params;
}

app->start();


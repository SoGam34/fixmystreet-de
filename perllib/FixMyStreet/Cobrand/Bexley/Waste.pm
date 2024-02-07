package FixMyStreet::Cobrand::Bexley::Waste;

use Moo::Role;

use Integrations::Whitespace;
use DateTime;
use DateTime::Format::W3CDTF;
use FixMyStreet;
use FixMyStreet::Template;
use Sort::Key::Natural qw(natkeysort_inplace);

has 'whitespace' => (
    is => 'lazy',
    default => sub { Integrations::Whitespace->new(%{shift->feature('whitespace')}) },
);

sub bin_addresses_for_postcode {
    my ($self, $postcode) = @_;

    my $addresses = $self->whitespace->GetAddresses($postcode);

    my $data = [ map {
        {
            value => $_->{AccountSiteId},
            label => FixMyStreet::Template::title($_->{SiteShortAddress}) =~ s/^, //r,
        }
    } @$addresses ];

    natkeysort_inplace { $_->{label} } @$data;

    return $data;
}

sub look_up_property {
    my ($self, $id) = @_;

    my $site = $self->whitespace->GetSiteInfo($id);

    return {
        id => $site->{AccountSiteID},
        uprn => $site->{AccountSiteUPRN},
        address => FixMyStreet::Template::title($site->{Site}->{SiteShortAddress}),
        latitude => $site->{Site}->{SiteLatitude},
        longitude => $site->{Site}->{SiteLongitude},
    };
}

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    $self->{c}->stash->{containers} = {
        # TODO
    };

    my $site_services = $self->whitespace->GetSiteCollections($property->{uprn});
    my @site_services_filtered;

    my $now_dt = DateTime->now->set_time_zone( FixMyStreet->local_time_zone );
    for my $service (@$site_services) {
        next if !$service->{NextCollectionDate};

        my $next_dt = eval {
            DateTime::Format::W3CDTF->parse_datetime(
                $service->{NextCollectionDate} );
        };
        if ($@) {
            warn $@;
            next;
        }

        my $from_dt = eval {
            DateTime::Format::W3CDTF->parse_datetime(
                $service->{SiteServiceValidFrom} );
        };
        if ($@) {
            warn $@;
            next;
        }
        next if $now_dt < $from_dt;

        # 0001-01-01T00:00:00 seems to represent an undefined date
        if ( $service->{SiteServiceValidTo} ne '0001-01-01T00:00:00' ) {
            my $to_dt = eval {
                DateTime::Format::W3CDTF->parse_datetime(
                    $service->{SiteServiceValidTo} );
            };
            if ($@) {
                warn $@;
                next;
            }
            next if $now_dt > $to_dt;
        }

        push @site_services_filtered, {
            id           => $service->{SiteServiceID},
            service_id   => $service->{ServiceItemName},
            service_name => $service->{ServiceItemDescription},
            next         => {
                date    => $service->{NextCollectionDate},
                ordinal => ordinal( $next_dt->day ),
                changed => 0,
            },
        };
    }

    @site_services_filtered = $self->service_sort(@site_services_filtered);

    return \@site_services_filtered;
}

# Bexley want services to be ordered by next collection date.
# Sub-order by service name for consistent display.
sub service_sort {
    my ( $self, @services ) = @_;

    return sort {
            $a->{next}{date} cmp $b->{next}{date}
        ||  $a->{service_name} cmp $b->{service_name}
    } @services;
}

sub image_for_unit {
    my ( $self, $unit ) = @_;

    my $images = {
        'FO-140'   => 'communal-food-wheeled-bin',     # Food 140 ltr Bin
        'FO-23'    => 'food-waste',                    # Food 23 ltr Caddy
        'GA-140'   => 'garden-waste-brown-bin',        # Garden 140 ltr Bin
        'GA-240'   => 'garden-waste-brown-bin',        # Garden 240 ltr Bin
        'GL-660'   => 'green-euro-bin',                # Glass 660 ltr Bin
        'GL-1100'  => 'green-euro-bin',                # Glass 1100 ltr Bin
        'GL-1280'  => 'green-euro-bin',                # Glass 1280 ltr Bin
        'GL-55'    => 'recycle-black-box',             # Glass 55 ltr Box
        'MDR-SACK' => 'recycle-bag',                   # Mixed Dry Recycling Sack
        'PC-180'   => 'recycling-bin-blue-lid',        # Paper & card 180 ltr wheeled bin
        'PC-55'    => 'blue-recycling-box',            # Paper & card 55 ltr box
        'PA-1100'  => 'communal-blue-euro',            # Paper & Cardboard & Cardbaord 1100 ltr Bin
        'PA-1280'  => 'communal-blue-euro',            # Paper & Cardboard 1280 ltr Bin
        'PA-140'   => 'communal-blue-euro',            # Paper & Cardboard 140 ltr Bin
        'PA-240'   => 'communal-blue-euro',            # Paper & Cardboard 240 ltr Bin
        'PA-55'    => 'recycle-green-box',             # Paper & Cardboard 55 ltr Box
        'PA-660'   => 'communal-blue-euro',            # Paper & Cardboard 660 ltr Bin
        'PA-940'   => 'communal-blue-euro',            # Paper & Cardboard 940 ltr Bin
        'PL-1100'  => 'plastics-wheeled-bin',          # Plastic 1100 ltr Bin
        'PL-1280'  => 'plastics-wheeled-bin',          # Plastic 1280 ltr Bin
        'PL-140'   => 'plastics-wheeled-bin',          # Plastic 140 ltr Bin
        'PL-55'    => 'recycle-maroon-box',            # Plastic 55 ltr Box
        'PL-660'   => 'plastics-wheeled-bin',          # Plastic 660 ltr Bin
        'PL-940'   => 'plastics-wheeled-bin',          # Plastic 940 ltr Bin
        'PG-1100'  => 'plastics-wheeled-bin',          # Plastics & glass 1100 ltr euro bin
        'PG-1280'  => 'plastics-wheeled-bin',          # Plastics & glass 1280 ltr euro bin
        'PG-240'   => 'recycling-bin-white-lid',       # Plastics & glass 240 ltr wheeled bin
        'PG-360'   => 'plastics-wheeled-bin',          # Plastics & glass 360 ltr wheeled bin
        'PG-55'    => 'white-recycling-box',           # Plastics & glass 55 ltr box
        'PG-660'   => 'plastics-wheeled-bin',          # Plastics & glass 660 ltr euro bin
        'PG-940'   => 'plastics-wheeled-bin',          # Plastics & glass 940 ltr chamberlain bin
        'RES-1100' => 'non-recyclable-wheeled-bin',    # Residual 1100 ltr bin
        'RES-1280' => 'non-recyclable-wheeled-bin',    # Residual 1280 ltr bin
        'RES-140'  => 'non-recyclable-wheeled-bin',    # Residual 140 ltr bin
        'RES-180'  => 'general-waste-green-bin',       # Residual 180 ltr bin
        'RES-240'  => 'general-waste-green-bin',       # Residual 240 ltr bin
        'RES-660'  => 'non-recyclable-wheeled-bin',    # Residual 660 ltr bin
        'RES-720'  => 'non-recyclable-wheeled-bin',    # Residual 720 ltr bin
        'RES-940'  => 'non-recyclable-wheeled-bin',    # Residual 940 ltr bin
        'RES-CHAM' => 'non-recyclable-wheeled-bin',    # Residual Chamberlain
        'RES-DBIN' => 'non-recyclable-wheeled-bin',    # Residual Dustbin
        'RES-SACK' => 'black-non-recyclable-bag',      # Residual Sack
    };

    # TODO
    # For PG-240 ('Plastics & glass 240 ltr wheeled bin')
    # when at parent shell/communal property
    # image should be plastics-wheeled-bin.png

    my $service_id = $unit->{service_id};

    return '/i/waste-containers/bexley/' . $images->{$service_id};
}

sub bin_day_format { '%A, %-d~~~ %B %Y' }

# TODO This logic is copypasted across multiple files; get it into one place
my %irregulars = ( 1 => 'st', 2 => 'nd', 3 => 'rd', 11 => 'th', 12 => 'th', 13 => 'th');
sub ordinal {
    my $n = shift;
    $irregulars{$n % 100} || $irregulars{$n % 10} || 'th';
}

1;
package App::grep::similar::text;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use AppBase::Grep;
use List::Util qw(min);
use Perinci::Sub::Util qw(gen_modified_sub);
use Text::Levenshtein::XS;

our %SPEC;

gen_modified_sub(
    output_name => 'grep_similar_text',
    base_name   => 'AppBase::Grep::grep',
    summary     => 'Print lines similar to the specified text',
    description => <<'MARKDOWN',

This is a grep-like utility that greps for text in input similar to the
specified text. Measure of similarity can be adjusted using these options:
`--max-edit-distance` (`-M`).

MARKDOWN
    remove_args => [
        'regexps',
        'pattern',
        'dash_prefix_inverts',
        'all',
    ],
    add_args    => {
        max_edit_distance => {
            schema => 'uint',
            tags => ['category:filtering'],
            description => <<'MARKDOWN',

If not specified, a sensible default will be calculated as follow:

    int( min(len(text), len(input_text)) / 1.3)

MARKDOWN
        },
        string => {
            summary => 'String to compare similarity of each line of input to',
            schema => 'str*',
            req => 1,
            pos => 0,
            tags => ['category:filtering'],
        },
        files => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'file',
            schema => ['array*', of=>'filename*'],
            pos => 1,
            slurpy => 1,
        },

        # XXX recursive (-r)
    },
    modify_meta => sub {
        my $meta = shift;
        $meta->{examples} = [
            {
                summary => 'Show lines that are similar to the text "foobar"',
                'src' => q([[prog]] foobar file.txt),
                'src_plang' => 'bash',
                'test' => 0,
                'x.doc.show_result' => 0,
            },
        ];

        $meta->{links} = [
        ];
    },
    output_code => sub {
        my %args = @_;
        my ($fh, $file);

        my @files = @{ delete($args{files}) // [] };

        my $show_label = 0;
        if (!@files) {
            $fh = \*STDIN;
        } elsif (@files > 1) {
            $show_label = 1;
        }

        $args{_source} = sub {
          READ_LINE:
            {
                if (!defined $fh) {
                    return unless @files;
                    $file = shift @files;
                    log_trace "Opening $file ...";
                    open $fh, "<", $file or do {
                        warn "grep-similar-text: Can't open '$file': $!, skipped\n";
                        undef $fh;
                    };
                    redo READ_LINE;
                }

                my $line = <$fh>;
                if (defined $line) {
                    return ($line, $show_label ? $file : undef);
                } else {
                    undef $fh;
                    redo READ_LINE;
                }
            }
        };

        $args{_filter_code} = sub {
            my ($line, $fargs) = @_;

            my $dist = Text::Levenshtein::XS::distance($fargs->{string}, $line);
            my $maxdist = $fargs->{max_edit_distance} //
                int(min(length($fargs->{string}), length($line))/1.3);
            $dist <= $maxdist;
        };

        AppBase::Grep::grep(%args);
    },
);

1;
# ABSTRACT:

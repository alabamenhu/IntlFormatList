=begin pod

=NAME    Intl::List
=AUTHOR  Matthew Stephen Stuckwisch
=VERSION 0.1

=head1 Localized list formatting

To format lists using this module, use the provided sub C<format-list>:

    format-list @list

There are three named options available:

=begin item
B<C<:language>> (may be abbreviated to B<C<:lang>>)

The language to use for formatting.
Should be a valid BCP-47 language code.
Defaults to whatever value C<Intl::UserLanguage>'s C<user-language> returns (which defaults to 'en' if undetectable).
=end item

=begin item
B<C<:type>>

There are three types possible: I<and>, I<or>, I<unit>.
The I<and> type indicates a list of collective values (e.g. 'apples, oranges, and peaches').
The I<or> type indicates a list of alternate values (e.g. 'apples, oranges, or peaches').
The I<unit> type indicates a list of values, without specifying any relation between them (e.g. 'apples, oranges, peaches').
Defaults to I<and>.
=end item

=begin item
B<C<:length>>

There are three lengths possible: I<standard>, I<short>, I<narrow>.
Many languages do not distinguish I<standard> and I<short>, perhaps only omitting spaces if they do.
Narrow is designed for minimal contexts, but may be ambiguous between the forms and should have additional context provided if used.
Defaults to I<standard>.
=end item

=end pod

unit module List;
use Intl::UserLanguage;

#| Formats a list in a manner that is appropriate for the given language
sub format-list (
    +@list,                #= The list of items to format (each will be stringified with .Str)
    :lang(:$language)      #= The locale to use for formatting (defaults to user-language)
        = user-language,
    :$length = 'standard', #= The length of the format (standard, short, or narrow); defaults to 'standard'.
    :$type = 'and'         #= The type of the list (and, unit, or); defaults to 'and'.
) is export {
    my $patterns = get-patterns($language, $type, $length);

    if @list > 2 {
        ~ @list.head
        ~   $patterns.start                      # first two joined by the start pattern
        ~ @list[  1..*-2].join($patterns.middle) # second to penultimate joined by the middle
        ~   $patterns.end                        # last two joined by the end pattern
        ~ @list.tail
    }
    elsif @list == 2 { @list.join: $patterns.two }
    elsif @list == 1 { @list.head                }
    else             { ''                        }
}

# Unicode uses a set of placeholder values.
# Although it is possible for some language to do things differently,
# as of December 2020, all languages conform with the following two principles:
#   (A) the order is always {0} followed by {1}
#   (B) the placeholders always flank the string (that is, they always match
#       the regex /^'{0}' .* '{1}'$/
# This allows us to efficiently process each one, and store it into cache for cleaner/faster code above
# as it's likely it will be used again
# Jan 2020: 'ff' may be a counter example

class CachedPattern {
    has Str $.two;
    has Str $.start;
    has Str $.middle;
    has Str $.end;
}

my CachedPattern %cache;

sub get-patterns($lang, $type, $length) {
    .return with %cache{$lang ~ $type ~ $length};
    use Intl::CLDR;
    my $pattern = cldr{$lang}.list-patterns{$type}{$length};

    %cache{$lang ~ $type ~ $length} := CachedPattern.new:
        two    => $pattern.two.substr(   3,*-3),
        start  => $pattern.start.substr( 3,*-3),
        middle => $pattern.middle.substr(3,*-3),
        end    => $pattern.end.substr(   3,*-3);
}
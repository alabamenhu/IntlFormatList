=begin pod

=NAME    Intl::Format::List
=AUTHOR  Matthew Stephen Stuckwisch
=VERSION 0.6

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
The I<unit> type is for listing multiple units together (e.g. '2lb 8oz')
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

my Callable %cache;

# Unicode uses a set of placeholder values.
# Although it is possible for some language to do things differently,
# as of December 2020, all languages conform with the following two principles:
#   (A) the order is always {0} followed by {1}
#   (B) the placeholders always flank the string (that is, they always match
#       the regex /^'{0}' .* '{1}'$/
# This allows us to efficiently process each one, and store it into cache for cleaner/faster code above
# as it's likely it will be used again
# Jan 2020: 'ff' may be a counter example

sub generate-list-formatter-vanilla($language, $type, $length, :$ast = False) {
    # Get CLDR information
    use Intl::CLDR;
    my $format = cldr{$language}.list-patterns{$type}{$length};
    my ($start, $middle, $end, $two) = $format<start middle end two>.map: *.substr(3,*-3).raku;

    # Generate code
    my $code = q:s:to/FORMATCODE/;
        sub format-list(+@items) {
            if    @items  > 2 { @items[0] ~ $start ~ @items[1..*-2].join($middle) ~ $end ~ @items[*-1] }
            elsif @items == 2 { @items[0] ~ $two ~ @items[1] }
            elsif @items == 1 { @items[0] }
            else              { '' }
        }
        FORMATCODE

    # compile and return
    use MONKEY-SEE-NO-EVAL;
    EVAL $code;
}


sub generate-list-formatter-rakuast(|c --> Callable) {
    use MONKEY-SEE-NO-EVAL;
    EVAL format-list-rakuast |c
}


sub format-list-rakuast($language, $type, $length) is export(:rakuast) {
    use experimental :rakuast;

    use Intl::CLDR;

    my $pattern = cldr{$language}.list-patterns{$type}{$length};
    my $two-infix = $pattern.two.substr: 3, *-3;
    my $more-first-infix = $pattern.start.substr: 3, *-3;
    my $more-middle-infix = $pattern.middle.substr: 3, *-3;
    my $more-final-infix = $pattern.end.substr: 3, *-3;


    my sub wrap-in-block($expression) {
        RakuAST::Block.new(
          body => RakuAST::Blockoid.new(
            RakuAST::StatementList.new(
              RakuAST::Statement::Expression.new(:$expression)
            )
          )
        )
    }

    # ''
    my $none = wrap-in-block RakuAST::StrLiteral.new('');

    # @list.head
    my $one = wrap-in-block RakuAST::ApplyPostfix.new(
        operand => RakuAST::Var::Lexical.new('@list'),
        postfix => RakuAST::Call::Method.new(
            name => RakuAST::Name.from-identifier('head')
        )
    );

    # @list.join($two-infix)
    my $two = wrap-in-block RakuAST::ApplyPostfix.new(
        operand => RakuAST::Var::Lexical.new('@list'),
        postfix => RakuAST::Call::Method.new(
            name => RakuAST::Name.from-identifier('join'),
            args => RakuAST::ArgList.new(
                RakuAST::StrLiteral.new($two-infix)
            )
        )
    );

    # @list.head
    my $more-first-item = RakuAST::ApplyPostfix.new(
      operand => RakuAST::Var::Lexical.new('@list'),
      postfix => RakuAST::Call::Method.new(
        name => RakuAST::Name.from-identifier('head')
      )
    );

    # @list[1, * - 2].join($more-middle-infix)
    my $more-mid-items = RakuAST::ApplyPostfix.new(
        # @list[1, @list - 2
        operand => RakuAST::ApplyPostfix.new(
            operand => RakuAST::Var::Lexical.new('@list'),
            postfix => RakuAST::Postcircumfix::ArrayIndex.new(
                # (1 .. @list - 2)
                RakuAST::SemiList.new(
                    RakuAST::ApplyInfix.new(
                        left => RakuAST::IntLiteral.new(1),
                        infix => RakuAST::Infix.new('..'),
                        # @list - 2
                        right => RakuAST::ApplyInfix.new(
                            left => RakuAST::Var::Lexical.new('@list'),
                            infix => RakuAST::Infix.new('-'),
                            right => RakuAST::IntLiteral.new(2)
                        )
                    )
                )
            )
        ),
        # .join($more-middle-infix)
        postfix => RakuAST::Call::Method.new(
            name => RakuAST::Name.from-identifier('join'),
            args => RakuAST::ArgList.new(
              RakuAST::StrLiteral.new($more-middle-infix)
            )
        )
    );

    # @list.tail
    my $more-final-item = RakuAST::ApplyPostfix.new(
        operand => RakuAST::Var::Lexical.new('@list'),
        postfix => RakuAST::Call::Method.new(
            name => RakuAST::Name.from-identifier('tail')
        )
    );

    # [~] ...
    my $more = wrap-in-block RakuAST::Term::Reduce.new(
        infix => RakuAST::Infix.new('~'),
        args => RakuAST::ArgList.new(
            $more-first-item,
            RakuAST::StrLiteral.new($more-first-infix),
            $more-mid-items,
            RakuAST::StrLiteral.new($more-final-infix),
            $more-final-item,
        )
    );

    # @list > 2
    my $more-than-two = RakuAST::Statement::Expression.new(
        expression => RakuAST::ApplyInfix.new(
            left => RakuAST::Var::Lexical.new('@list'),
            infix => RakuAST::Infix.new('>'),
            right => RakuAST::IntLiteral.new(2)
        )
    );

    # @list == 2
    my $exactly-two = RakuAST::Statement::Expression.new(
        expression => RakuAST::ApplyInfix.new(
            left => RakuAST::Var::Lexical.new('@list'),
            infix => RakuAST::Infix.new('=='),
            right => RakuAST::IntLiteral.new(2)
        )
    );

    # @list == 1
    my $exactly-one = RakuAST::Statement::Expression.new(
        expression => RakuAST::ApplyInfix.new(
            left => RakuAST::Var::Lexical.new('@list'),
            infix => RakuAST::Infix.new('=='),
            right => RakuAST::IntLiteral.new(1)
        )
    );

    my $if = RakuAST::Statement::If.new(
        condition => $more-than-two,
        then => $more,
        elsifs => [
            RakuAST::Statement::Elsif.new(
                condition => $exactly-two,
                then => $two
            ),
            RakuAST::Statement::Elsif.new(
                condition => $exactly-one,
                then => $one
            )
        ],
        else => $none
    );

    return RakuAST::PointyBlock.new(
        signature => RakuAST::Signature.new(
            parameters => (
                RakuAST::Parameter.new(
                    target => RakuAST::ParameterTarget::Var.new('@list'),
                    slurpy => RakuAST::Parameter::Slurpy::SingleArgument
                ),
            ),
        ),
        body => RakuAST::Blockoid.new(
            RakuAST::StatementList.new(
                RakuAST::Statement::Expression.new(
                    expression => $if
                )
            )
        )
    )
}



INIT my &generate-list-formatter =
    $*RAKU.compiler.name eq 'rakudo' && $*RAKU.compiler.version < v2022.12.813.g.02043.da.92
        ?? &generate-list-formatter-vanilla
        !! &generate-list-formatter-rakuast;
use User::Language;

#| Formats a list in a manner that is appropriate for the given language
sub format-list (
        +@items,                    #= The list of items to format (each will be stringified with .Str)
        :$language = user-language, #= The locale to use for formatting (defaults to user-language)
        :$type = 'and',             #= The type of the list (and, unit, or); defaults to 'and'.
        :$length = 'standard'       #= The length of the format (standard, short, or narrow); defaults to 'standard'.
) is export(:DEFAULT) {
    my $code = $language ~ $type ~ $length;
    # Get a formatter, generating it if it's not been requested before
    my &formatter  = %cache{$code}
                  // %cache{$code} = generate-list-formatter($language, $type, $length);

    formatter @items;
}